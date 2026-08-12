echo "Loading ~/.bash_aliases"

# ── Dependency check for md2pdf / html2pdf pipeline ──────────────────
_md2pdf_deps=()
command -v unbuffer  >/dev/null 2>&1 || _md2pdf_deps+=("unbuffer  (apt install expect)")
command -v glow      >/dev/null 2>&1 || _md2pdf_deps+=("glow      (apt install glow  or  snap install glow)")
command -v aha       >/dev/null 2>&1 || _md2pdf_deps+=("aha       (apt install aha)")
command -v google-chrome >/dev/null 2>&1 || \
command -v chromium      >/dev/null 2>&1 || _md2pdf_deps+=("google-chrome or chromium")
if [ ${#_md2pdf_deps[@]} -gt 0 ]; then
    echo "⚠ md2pdf/html2pdf missing dependencies:"
    for _dep in "${_md2pdf_deps[@]}"; do
        echo "   - $_dep"
    done
    unset _dep
fi
unset _md2pdf_deps
# ─────────────────────────────────────────────────────────────────────


# bindfs mount: only runs if $HOME/tmp exists (opt-in gate)
if [ -d "${HOME}/tmp" ]; then
    # Lazily kill any stale FUSE mount first
    fusermount -uz "${HOME}/tmp" 2>/dev/null || true

    # Ensure source directory exists, then mount if destination is empty
    if ! command -v bindfs >/dev/null 2>&1; then
        echo "bindfs not found — install it (apt install bindfs)"
    else
        mkdir -p "/tmp/${USER}/Downloads"
        if [ -z "$(ls -A "${HOME}/tmp" 2>/dev/null)" ]; then
            bindfs "/tmp/${USER}" "${HOME}/tmp"
        fi
    fi
fi


if [ ! -d "$HOME/airflow" ]; then
    mkdir "$HOME/airflow"
    export AIRFLOW_HOME="$HOME/airflow"
else
    export AIRFLOW_HOME="$HOME/airflow"
fi

if [ -d ~/bin ]; then
        export PATH="$PATH:~/bin"
fi

if [ -d ~/.cargo/bin ]; then
    export PATH="$PATH:~/.cargo/bin"
fi

if [ -d ~/go/bin ]; then
    export PATH="$PATH:~/go/bin"
    export GOPATH="$HOME/go"
fi

if [ -d /usr/local/go/bin ]; then
    export PATH="$PATH:/usr/local/go/bin"
fi

if [ -f $(which xclip) ]; then
    alias pbcopy_linux='tee >(xclip -selection clipboard)'
    alias pbpaste_linux='xclip -selection clipboard -o'
else
    echo "xclip not installed, not setting pbcopy alias."
fi

#eval "(ssh-agent -s)"
#ssh-add ~/.ssh/hostkey

# Ansible vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=$HOME/.ssh/vault.txt
#source $HOME/.cargo/env

export EDITOR=$(which vim)
alias apt_reinstall='for each in $(sudo apt list --upgradable |grep -v Listing |cut -f 1 -d "/") ; do sudo apt reinstall -y $each ; done'
alias buttons-to-right="gconftool -s /apps/metacity/general/button_layout -t string menu:minimize,maximize,close"
alias ltcp="sudo lsof -i -sTCP:LISTEN -P +c 0"
export  PATH=~/bin/android-studio/bin:${PATH}
alias warpspeed='eval "$(starship init bash)"'
alias physicaldisks="sudo fsarchiver probe |& grep -v loop | grep -v ram"
alias tss="sudo tailscale status"

# system enhancements
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ls='ls --color=auto'
alias out="cat /etc/motd;logout"
alias lw="ls -CGa --color=auto"
alias l='ls $LS_OPTIONS -lA'
alias stop="/sbin/shutdown -c"
alias getweather="curl wttr.in"
alias ip='ip -color=auto'
alias tshark='tshark --color'
alias tss='sudo tailscale status'

# Disabled as the the geektools proxy seems unresponsive
#alias whois="whois -h whois.geektools.com"
alias dus="du -Pachx --max-depth=1 . | sort -h"
alias sdus="sudo du -Pachx --max-depth=1 . | sort -h"
alias apt-upgrade="sudo aptitude update ; sudo aptitude dist-upgrade"
alias h="history | grep "
alias rdp="rdesktop -g 1920x1080 -P -z -r sound:local -r clipboard:PRIMARYCLIPBOARD"
# directory tree - http://www.shell-fu.org/lister.php?id=209
alias dirf='find . -type d | sed -e "s/[^-][^\/]*\//  |/g" -e "s/|\([^ ]\)/|-\1/"'
# count files by type - http://www.shell-fu.org/lister.php?id=173
alias ftype="find ${*-.} -type f | xargs file | awk -F, '\''{print $1}'\'' | awk '\''{$1=NULL;print $0}'\'' | sort | uniq -c | sort -nr"
alias logwatch="tail -f /var/log/messages"
alias wget-recursive="wget -r --level=5 -nH -N -np"
alias ggl="git log --all --decorate --oneline --graph"
alias snyktest="snyk container test --severity-threshold=high"
alias trimws="sed -i 's/[[:space:]]*$//'"

# media inspection
alias mediainspect='ffprobe -hide_banner -v error -show_entries format=filename,format_long_name,duration,size,bit_rate:stream=index,codec_name,codec_long_name,codec_type,profile,width,height,bit_rate,sample_rate,channels,channel_layout,pix_fmt,avg_frame_rate,r_frame_rate -of default=noprint_wrappers=1'

# youtube audio only -> wav (usage: yt-dlp_audio <url>)
alias yt-dlp_audio='yt-dlp -f "bestaudio" -x --audio-format wav --audio-quality 0 -o "yt-%(title)s.%(ext)s"'

manopt() {
local cmd=$1 opt=$2
[[ $opt == -* ]] || { (( ${#opt} == 1 )) && opt="-$opt" || opt="--$opt"; }
man "$cmd" | col -b | awk -v opt="$opt" -v RS= '$0 ~ "(^|,)[[:blank:]]+" opt "([[:punct:][:space:]]|$)"'
}

# Fast bulk transfer using tar + pv + netcat (bypasses CIFS/NFS overhead)
# Usage:
#   receiver$ tarrecv /destination/path/
#   sender$   tarsend /source/path/ receiverhost
#
# Optional port as 3rd arg: tarsend /src/ host 5555
#                           tarrecv /dst/ 5555
tarrecv() {
    local dst="${1:?Usage: tarrecv <dest_dir> [port]}"
    local port="${2:-9999}"
    mkdir -p "$dst"
    echo "Listening on port $port, extracting to $dst ..."
    nc -l "$port" | tar xpf - -C "$dst"
    echo "Transfer complete."
}

tarsend() {
    local src="${1:?Usage: tarsend <src_dir> <host> [port]}"
    local host="${2:?Usage: tarsend <src_dir> <host> [port]}"
    local port="${3:-9999}"
    local size
    echo "Calculating size of $src ..."
    size=$(du -sb "$src" 2>/dev/null | awk '{print $1}')
    echo "Sending $src ($(numfmt --to=iec "$size")) to $host:$port ..."
    tar cf - -C "$src" . | pv -s "$size" | nc "$host" "$port"
    echo "Transfer complete."
}

# Put all local system specific aliases into a ~/.bash_aliases_local file
if [ -f ~/.bash_aliases_local ]
then . ~/.bash_aliases_local;
fi

parse_git_branch() {
git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export PS1="\e[90;1m\u\033[0m\e[32;1m@\e[34;1m\h\e[0m \e[32;1m<\t> \e[34;1m\w\e[0m\e[\033[33m\]\$(parse_git_branch)\[\033[00m\]\n\$ "
export PS2=""
export PS3=""
export PS4=""

sha256_find() {
find "$1" -type f -exec sha256sum -b {} + |  grep -F "$2"
}

waitforit_wrapper() {
 if [ -z "$2" ]
 then SSH_USER="$USER"
 else SSH_USER="$2"
 fi
    wait-for-it.sh -p 22 -t 180 -h "$1" -- ssh "$1" -l "$SSH_USER"
}

# html2pdf-chrome <input.html> [portrait|landscape] -- print local HTML to PDF via headless chrome.
# Output is written next to the input as <input.html>.pdf.
# Orientation defaults to portrait. Landscape is achieved by injecting an
# @page CSS rule into a temp copy of the source (chrome has no CLI flag for it).
html2pdf-chrome() {
    local input="${1:?Usage: html2pdf-chrome <input.html> [portrait|landscape]}"
    local orientation="${2:-portrait}"
    [ -f "$input" ] || { echo "html2pdf: file not found: $input" >&2; return 1; }
    case "$orientation" in
        portrait|landscape) ;;
        *) echo "html2pdf: orientation must be portrait or landscape, got: $orientation" >&2; return 1 ;;
    esac
    local browser
    if command -v google-chrome >/dev/null 2>&1; then
        browser=google-chrome
    elif command -v chromium >/dev/null 2>&1; then
        browser=chromium  # snap chromium is AppArmor-confined to $HOME
    else
        echo "html2pdf: neither google-chrome nor chromium found" >&2; return 1
    fi
    local source="$input" tmp=""
    if [ "$orientation" = "landscape" ]; then
        # Temp file lives next to the source so relative-path assets (CSS, images) still resolve.
        tmp=$(mktemp --suffix=.html --tmpdir="$(dirname "$(readlink -f "$input")")") || {
            echo "html2pdf: mktemp failed" >&2; return 1
        }
        if grep -qi '<head' "$input"; then
            sed -E 's|(<head[^>]*>)|\1<style>@page{size:landscape}</style>|' "$input" > "$tmp"
        else
            { printf '<style>@page{size:landscape}</style>'; cat "$input"; } > "$tmp"
        fi
        source="$tmp"
    fi
    "$browser" --headless=new --disable-gpu \
        --no-pdf-header-footer \
        --print-to-pdf="${input}.pdf" \
        "$source" >/dev/null 2>&1
    local rc=$?
    [ -n "$tmp" ] && rm -f "$tmp"
    if [ $rc -eq 0 ]; then
        echo "wrote ${input}.pdf"
    else
        echo "html2pdf: $browser failed" >&2
        return 1
    fi
}

# html2pdf-pipe -- print piped HTML to PDF via headless chrome.
# Usage: echo "<h1>Hello</h1>" | html2pdf-pipe output.pdf [portrait|landscape]
# Reads HTML from stdin, writes PDF to the specified output file.
# Orientation defaults to portrait.
html2pdf-pipe() {
    local output="${1:?Usage: html2pdf-pipe <output.pdf> [portrait|landscape]}"
    local orientation="${2:-portrait}"
    case "$orientation" in
        portrait|landscape) ;;
        *) echo "html2pdf-pipe: orientation must be portrait or landscape, got: $orientation" >&2; return 1 ;;
    esac
    local browser
    if command -v google-chrome >/dev/null 2>&1; then
        browser=google-chrome
    elif command -v chromium >/dev/null 2>&1; then
        browser=chromium
    else
        echo "html2pdf-pipe: neither google-chrome nor chromium found" >&2; return 1
    fi
    local tmpdir
    tmpdir=$(mktemp -d) || { echo "html2pdf-pipe: mktemp failed" >&2; return 1; }
    local source="$tmpdir/input.html"
    cat > "$source" || { echo "html2pdf-pipe: failed to read stdin" >&2; rm -rf "$tmpdir"; return 1; }
    if [ "$orientation" = "landscape" ]; then
        if grep -qi '<head' "$source"; then
            sed -i -E 's|(<head[^>]*>)|\1<style>@page{size:landscape}</style>|' "$source"
        else
            { printf '<style>@page{size:landscape}</style>'; cat "$source"; } > "$tmpdir/landscape.html" && mv "$tmpdir/landscape.html" "$source"
        fi
    fi
    "$browser" --headless=new --disable-gpu \
        --no-pdf-header-footer \
        --print-to-pdf="$output" \
        "file://$source" >/dev/null 2>&1
    local rc=$?
    rm -rf "$tmpdir"
    if [ $rc -eq 0 ]; then
        echo "wrote $output"
    else
        echo "html2pdf-pipe: $browser failed" >&2
        return 1
    fi
}

# html2pdf-style -- inject CSS into aha HTML before pdf conversion.
# Usage: ... | aha | html2pdf-style "body{font-size:16px}" "2cm 1.5cm" | html2pdf-pipe out.pdf
html2pdf-style() {
    local body_css="${1:-body{font-size:14px}}"
    local page_css="${2:-margin:2cm 1.5cm}"
    sed "s|</head>|<style>${body_css}@page{${page_css}}</style></head>|"
}

# md2pdf -- render a Markdown file to PDF via glow + aha + headless Chrome.
# Usage: md2pdf [--dark] [--style STYLE] input.md [font-size] [margin]
#   --dark:    Use dark background (passes -b to aha)
#   --style:   Glow rendering style (default: auto)
#              Available: dark, light, dracula, tokyo-night, pink, ascii, notty, auto
#   font-size: CSS font-size value (default: 14px)
#   margin:    CSS @page margin value (default: 2cm 1.5cm)
# Output is written next to the input as <input.md>.pdf.
md2pdf() {
    local dark=""
    local glow_style="auto"
    # Parse optional flags
    while [[ "${1:-}" == -* ]]; do
        case "$1" in
            --dark|-d)
                dark="-b"
                shift
                ;;
            --style|-s)
                glow_style="${2:?md2pdf: --style requires a value (dark|light|dracula|tokyo-night|pink|ascii|notty|auto)}"
                shift 2
                ;;
            *)
                echo "md2pdf: unknown option: $1" >&2; return 1
                ;;
        esac
    done
    local input="${1:?Usage: md2pdf [--dark] [--style STYLE] <input.md> [font-size] [margin]}"
    local font_size="${2:-14px}"
    local margin="${3:-2cm 1.5cm}"
    [ -f "$input" ] || { echo "md2pdf: file not found: $input" >&2; return 1; }
    local output="${input}.pdf"

    # Check for unbuffer (preserves glow's ANSI colors through the pipe)
    if ! command -v unbuffer >/dev/null 2>&1; then
        echo "md2pdf: unbuffer not found (install 'expect' package)" >&2; return 1
    fi
    # Check for glow
    if ! command -v glow >/dev/null 2>&1; then
        echo "md2pdf: glow not found" >&2; return 1
    fi
    # Check for aha
    if ! command -v aha >/dev/null 2>&1; then
        echo "md2pdf: aha not found" >&2; return 1
    fi

    unbuffer glow -s "$glow_style" "$input" \
        | aha $dark \
        | html2pdf-style "body{font-size:${font_size}}" "margin:${margin}" \
        | html2pdf-pipe "$output"
}

# md2pdf-bgdark -- md2pdf with dark background (glow colors on black).
# Usage: md2pdf-bgdark input.md [font-size] [margin]
md2pdf-bgdark() {
    md2pdf --dark "$@"
}

# ── bonus-room-cam: RTSP viewer with SSH tunnel relay ─────────────────
# SSH relay prevents video freezing over flaky wifi. Connects to Thingino
# firmware camera via prudynt on port 554, tunneled through SSH for a
# stable TCP transport. Cleans up the tunnel when mpv exits.
bonus_room_cam() {
    # Kill stale tunnel on port 8554 from any previous run
    fuser -k 8554/tcp 2>/dev/null
    if ! ssh -f -N -L 8554:localhost:554 -o ExitOnForwardFailure=yes bonus-room-cam 2>/dev/null; then
        echo "bonus-room-cam: tunnel relay failed — camera unreachable?" >&2
        return 1
    fi
    # shellcheck disable=SC2064
    trap "fuser -k 8554/tcp 2>/dev/null" EXIT
    mpv --rtsp-transport=tcp --no-audio "rtsp://thingino:thingino@127.0.0.1:8554/ch0"
}
alias bonus-room-cam=bonus_room_cam

# Silence oh-my-openagent PostHog telemetry (kills PostHogFetchNetworkError stack traces in opencode)
export OMO_DISABLE_POSTHOG=1
