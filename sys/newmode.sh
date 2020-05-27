#!/bin/bash
# Forked from original at https://www.elstel.org/software/xorg.conf/newmode
# Makes sense to use in combination with: https://arachnoid.com/modelines/
#
# newmode ... written by Elmar Stellnberger, usbale under S-FSL v1.3.8 as obtainable under https://www.elstel.org/license
#

createmode() { {
  local opts ModeLine ModeName mode modename pfx;
  freq=${1#r}; if [[ "$freq" != "$1" ]]; then opts="--reduced"; pfx="r"; fi
  { read ModeLine ModeName mode < <( $CRTPROG $opts $x $y $freq 2>&3 | egrep -v "^[ ]*#.*$|^$"; ); 
    if [[ "$ModeLine" = "Modeline" ]]; then
      echo "mode $ModeName: $mode"
      modename="${x}x${y}@${pfx}${freq}";
      xrandr --delmode $o $modename 2>&9
      xrandr --rmmode $modename 2>&9
      if ! $DEL; then
        xrandr --newmode $modename $mode
        xrandr --addmode $o $modename
      fi
    else
      echo "error invoking $CRTPROG for mode $1." >&2
    fi
} 9>/dev/null 3>&1 1>&8 | grep "ERROR"; } 8>&1; }

if [[ "$1" == "--help" || $# -eq 0 ]]; then
  cat <<EOQ
newmode [--gtf/--del] VGA1 1920 1200 r60 60 r70 r75

EOQ
  
else 

  CRTPROG=cvt; DEL=false;
  [[ "$1" = "--gtf" ]] && { CRTPROG=gtf; shift; }
  [[ "$1" = "--del" ]] && { DEL=true; shift; }
  [[ "${1:0:1}" = "-" ]] && { echo "unknown option $1"; exit 1; }
  
  o="$1";
  let x=$2 y=$3;
  shift 3;

  echo "--output $o: ${x}x${y}"
  while [[ $# -ge  1 ]]; do
      if $DEL; then
        xrandr --delmode $o ${x}x${y}@$1
        xrandr --rmmode ${x}x${y}@$1
      else createmode "$1";
      fi
      shift;
  done
  
  if ! $DEL; then
    echo "xrandr --output $o --mode ${x}x${y}@$freq"
    echo
  fi

fi

