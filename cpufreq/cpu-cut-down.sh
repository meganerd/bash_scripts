#!/usr/bin/env bash
set -euo pipefail

SYS=/sys/devices/system/cpu

usage() {
    cat <<'EOF'
Usage: cpu-cut-down.sh [-p N] [-e N] [-t 1|2]

Control CPU core configuration (P-cores, E-cores, SMT). Default: enable all.

Options:
  -p N   Number of performance (P) cores to enable (default: all)
  -e N   Number of efficiency (E) cores to enable (default: all)
  -t N   Threads per core: 1 (disable SMT) or 2 (enable SMT, default)
  -h     Show this help

Examples:
  cpu-cut-down.sh              # enable all cores and threads
  cpu-cut-down.sh -p 4 -e 4    # 4 P-cores + 4 E-cores, SMT on
  cpu-cut-down.sh -p 6 -t 1    # 6 P-cores, no SMT
EOF
    exit 0
}

P_TGT=""; E_TGT=""; T_TGT=""
while getopts "p:e:t:h" opt; do
    case $opt in
        p) P_TGT=$OPTARG ;;
        e) E_TGT=$OPTARG ;;
        t) T_TGT=$OPTARG ;;
        h) usage ;;
        *) exit 1 ;;
    esac
done

# Default: enable everything
if [ -z "$P_TGT" ] && [ -z "$E_TGT" ] && [ -z "$T_TGT" ]; then
    echo "Enabling all CPUs and SMT..."
    for f in "$SYS"/cpu[0-9]*/online; do
        echo 1 | sudo tee "$f" >/dev/null 2>&1 || true
    done
    echo on | sudo tee "$SYS/smt/control" >/dev/null 2>&1 || true
    echo "Done."
    exit 0
fi

[ -n "$T_TGT" ] && [ "$T_TGT" != "1" ] && [ "$T_TGT" != "2" ] && {
    echo "Error: -t must be 1 or 2"; exit 1
}

# --- Topology discovery ---
cpu_nums=()
for d in "$SYS"/cpu[0-9]*; do
    n=${d##*/cpu}
    [[ $n =~ ^[0-9]+$ ]] && cpu_nums+=("$n")
done

declare -A core_list core_type

# Classify each core as P ("p") or E ("e"). Detection fallback chain:
#   1. Per-CPU core-type attribute, when the kernel exposes it (built with
#      CONFIG_X86_HYBRID_CPU, e.g. /sys/devices/system/cpu/cpuN/cpu_core_type).
#   2. SMT heuristic: on Intel hybrid CPUs E-cores are single-threaded while
#      P-cores have SMT, so a core with one CPU in its core_cpus_list is an
#      E-core. Works on Alder/Raptor/Meteor/Arrow Lake kernels that report no
#      hybrid info at all (e.g. CONFIG_X86_HYBRID_CPU unset).
#   3. Frequency heuristic: if no core has SMT (e.g. Lunar Lake), split by
#      per-core max frequency - P-cores run at the top frequency, E-cores below.
# A warning is printed if zero E-cores are detected (silent-failure guard).

for cpu in "${cpu_nums[@]}"; do
    cid=$(cat "$SYS/cpu$cpu/topology/core_id" 2>/dev/null) || continue
    core_list[$cid]="${core_list[$cid]:-} $cpu"
done

per_cpu_type=0
for cpu in "${cpu_nums[@]}"; do
    if [ -f "$SYS/cpu$cpu/cpu_core_type" ]; then per_cpu_type=1; break; fi
done

if [ "$per_cpu_type" -eq 1 ]; then
    for cid in "${!core_list[@]}"; do
        cpu=${core_list[$cid]##* }
        ct=$(cat "$SYS/cpu$cpu/cpu_core_type" 2>/dev/null)
        [ "$ct" = "2" ] && core_type[$cid]=e || core_type[$cid]=p
    done
else
    smt_seen=0
    for cid in "${!core_list[@]}"; do
        n_threads=$(echo "${core_list[$cid]}" | wc -w)
        [ "$n_threads" -ge 2 ] && smt_seen=1
    done

    if [ "$smt_seen" -eq 1 ]; then
        # E-cores are the single-threaded ones.
        for cid in "${!core_list[@]}"; do
            n_threads=$(echo "${core_list[$cid]}" | wc -w)
            core_type[$cid]=p
            [ "$n_threads" -eq 1 ] && core_type[$cid]=e
        done
    else
        # No SMT anywhere: split by max frequency instead.
        declare -A core_freq
        maxf=0
        for cid in "${!core_list[@]}"; do
            for cpu in ${core_list[$cid]}; do
                f=$(cat "$SYS/cpu$cpu/cpufreq/cpuinfo_max_freq" 2>/dev/null) || continue
                [ "${core_freq[$cid]:-0}" -lt "$f" ] && core_freq[$cid]=$f
                [ "$f" -gt "$maxf" ] && maxf=$f
            done
        done
        for cid in "${!core_list[@]}"; do
            f=${core_freq[$cid]:-0}
            if [ "$f" -eq 0 ] || [ "$f" -ge $(( maxf * 9 / 10 )) ]; then
                core_type[$cid]=p
            else
                core_type[$cid]=e
            fi
        done
    fi
fi

p_cores=(); e_cores=()
for cid in $(printf '%s\n' "${!core_type[@]}" | sort -n); do
    [ "${core_type[$cid]}" = "p" ] && p_cores+=("$cid") || e_cores+=("$cid")
done

echo "Found ${#p_cores[@]} P-core(s), ${#e_cores[@]} E-core(s)"

if [ "${#e_cores[@]}" -eq 0 ]; then
    echo "Warning: no E-cores detected; core-type classification may be wrong" >&2
fi

P_TGT=${P_TGT:-${#p_cores[@]}}
E_TGT=${E_TGT:-${#e_cores[@]}}
T_TGT=${T_TGT:-2}

# --- Build keep/offline sets ---
keep_str=""
offline_str=""

apply_core() {
    local cid=$1 keep=$2
    local cpus
    cpus=$(echo "${core_list[$cid]}" | tr ' ' '\n' | sort -n | tr '\n' ' ')
    cpus="${cpus% }"

    if [ "$keep" = "1" ]; then
        if [ "$T_TGT" -eq 1 ]; then
            local primary="${cpus%% *}"
            keep_str="$keep_str $primary"
            for c in $cpus; do
                [ "$c" != "$primary" ] && offline_str="$offline_str $c"
            done
        else
            keep_str="$keep_str $cpus"
        fi
    else
        offline_str="$offline_str $cpus"
    fi
}

for ((i=0; i<${#p_cores[@]}; i++)); do
    apply_core "${p_cores[$i]}" $(( i < P_TGT ? 1 : 0 ))
done
for ((i=0; i<${#e_cores[@]}; i++)); do
    apply_core "${e_cores[$i]}" $(( i < E_TGT ? 1 : 0 ))
done

# Ensure CPU 0 is always kept
keep_str="0 $keep_str"
keep_str=$(echo "$keep_str" | tr ' ' '\n' | grep -v '^$' | sort -un | tr '\n' ' ')
offline_str=$(echo "$offline_str" | tr ' ' '\n' | grep -v '^$' | sort -un | tr '\n' ' ')

# Remove any kept CPUs from offline set
for c in $keep_str; do
    offline_str=$(echo "$offline_str" | tr ' ' '\n' | grep -v "^$c$" | tr '\n' ' ')
done

# --- Apply configuration ---
echo "Enabling CPUs: $keep_str"
for cpu in $keep_str; do
    echo 1 | sudo tee "$SYS/cpu$cpu/online" >/dev/null 2>&1 || true
done

if [ -n "$offline_str" ]; then
    echo "Disabling CPUs: $offline_str"
    for cpu in $offline_str; do
        [ "$cpu" = "0" ] && continue
        echo 0 | sudo tee "$SYS/cpu$cpu/online" >/dev/null 2>&1 || true
    done
fi

if [ "$T_TGT" -eq 1 ]; then
    echo off | sudo tee "$SYS/smt/control" >/dev/null 2>&1 || true
else
    echo on | sudo tee "$SYS/smt/control" >/dev/null 2>&1 || true
fi

echo "Applied: ${P_TGT} P-core(s), ${E_TGT} E-core(s), SMT ${T_TGT}"
