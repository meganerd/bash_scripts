#!/bin/bash
# flac2mp3: Transcode FLAC audio files to MP3 audio files
#
# Version 1.2 (2010-01-10) by Korbinian Pauli http://www.muxcom.net
# * extract cover art from flac file and insert it into mp3
#
# Script based on a script by:
# James A. Hillyerd
# $Revision: 24 $, $Date: 2006-10-04 19:10:00 -0700 (Wed, 04 Oct 2006) $
# Release: 1.1
# http://bytemonkey.org/flac2mp3
#
# Usage: flac2mp3 --in <input-dir> --out <output-dir> [--cbr <bitrate>|--vbr <quality>]
# 
# Options:
#   --in <dir>       Input directory containing FLAC files
#   --out <dir>      Output directory for MP3 files
#   --cbr <bitrate>  Use constant bitrate encoding with specified bitrate (e.g., 320)
#   --vbr <quality>  Use variable bitrate encoding with specified quality (0-9, 0=best)
#                    Default is --vbr 0 if no encoding options are specified
### Begin Configuration
# The values below will be overridden by those in ~/.flac2mp3.conf if it
# exists
# Copy artwork (*.jpg) files? Set to "true" or "false"
COPY_ARTWORK="true"
# Detect number of physical CPU cores (excluding hyperthreading)
# Try different methods to detect physical cores
if [ -f /proc/cpuinfo ]; then
  # Linux with /proc/cpuinfo
  PHYSICAL_CORES=$(grep "^core id" /proc/cpuinfo | sort -u | wc -l)
  if [ -z "$PHYSICAL_CORES" ] || [ "$PHYSICAL_CORES" -eq 0 ]; then
    # Alternative method using lscpu
    if command -v lscpu >/dev/null 2>&1; then
      CORES_PER_SOCKET=$(lscpu | grep "Core(s) per socket" | awk '{print $4}')
      SOCKETS=$(lscpu | grep "Socket(s)" | awk '{print $2}')
      if [ -n "$CORES_PER_SOCKET" ] && [ -n "$SOCKETS" ]; then
        PHYSICAL_CORES=$((CORES_PER_SOCKET * SOCKETS))
      fi
    fi
  fi
fi

# If we still don't have a valid core count, fall back to nproc
if [ -z "$PHYSICAL_CORES" ] || [ "$PHYSICAL_CORES" -eq 0 ]; then
  if command -v nproc >/dev/null 2>&1; then
    PHYSICAL_CORES=$(nproc)
  else
    # Default to 4 if we can't detect
    PHYSICAL_CORES=4
  fi
fi

# Calculate MAX_PARALLEL as cores-2 with minimum of 2
MAX_PARALLEL=$((PHYSICAL_CORES - 2))
if [ "$MAX_PARALLEL" -lt 2 ]; then
  MAX_PARALLEL=2
fi

# Where we store working data (including the decoded wav file)
TMPDIR="/tmp"
# Path to flac binary
FLAC="$(which flac)"
# Path to metaflac binary (part of flac distribution)
METAFLAC="$(which metaflac)"
# Path to lame binary
LAME="$(which lame)"
# Options to pass to lame during encoding
LAME_OPTS="--vbr-new -V 0 -h --nohist --resample 44100"
# Multiple instances of this running on the same output-dir will be more
# reliable with locking available.
DOTLOCKFILE="$(which dotlockfile)"
# Note that INND's shlock isn't reliable, but we don't have a good way
# to tell whether this is that shlock or Erik Fair's shlock(1) which
# comes with several BSDs because both use the same command args.
SHLOCK="$(which shlock)"
# Maximum number of times we allow flac decode to fail per file
# before aborting
MAXFAILS=5
### End Configuration
### Read User Configuration
[[ -f ~/.flac2mp3.conf ]] && source ~/.flac2mp3.conf
# Check that we have all the required binaries
if [ ! -x "$FLAC" ]; then
echo "ERROR: flac not installed" >&2
exit 1
fi
if [ ! -x "$METAFLAC" ]; then
echo "ERROR: metaflac not installed" >&2
exit 1
fi
if [ ! -x "$LAME" ]; then
echo "ERROR: lame not installed" >&2
exit 1
fi
# Default encoding settings
ENCODING_MODE="vbr"
VBR_QUALITY=0
CBR_BITRATE=320

# Parse command line arguments
INPUTDIR=""
OUTPUTDIR=""

# Parse all parameters
while [ $# -gt 0 ]; do
  case "$1" in
    --in)
      if [ -z "$2" ]; then
        echo "ERROR: --in requires a directory path" >&2
        exit 1
      fi
      INPUTDIR="$2"
      shift 2
      ;;
    --out)
      if [ -z "$2" ]; then
        echo "ERROR: --out requires a directory path" >&2
        exit 1
      fi
      OUTPUTDIR="$2"
      shift 2
      ;;
    --cbr)
      if [ -z "$2" ]; then
        echo "ERROR: --cbr requires a bitrate value" >&2
        exit 1
      fi
      ENCODING_MODE="cbr"
      CBR_BITRATE="$2"
      shift 2
      ;;
    --vbr)
      if [ -z "$2" ]; then
        echo "ERROR: --vbr requires a quality value (0-9)" >&2
        exit 1
      fi
      ENCODING_MODE="vbr"
      VBR_QUALITY="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      echo "Usage: flac2mp3 --in <input-dir> --out <output-dir> [--cbr <bitrate>|--vbr <quality>]" >&2
      exit 1
      ;;
  esac
done

# Check that required parameters are provided
if [ -z "$INPUTDIR" ] || [ -z "$OUTPUTDIR" ]; then
  echo "ERROR: Both --in and --out parameters are required" >&2
  echo "Usage: flac2mp3 --in <input-dir> --out <output-dir> [--cbr <bitrate>|--vbr <quality>]" >&2
  exit 1
fi

# Set LAME options based on encoding mode
if [ "$ENCODING_MODE" = "cbr" ]; then
  LAME_OPTS="-b $CBR_BITRATE -h --nohist --resample 44100"
  echo "Using constant bitrate encoding: $CBR_BITRATE kbps"
else
  LAME_OPTS="--vbr-new -V $VBR_QUALITY -h --nohist --resample 44100"
  echo "Using variable bitrate encoding: quality $VBR_QUALITY (0=highest, 9=lowest)"
fi
WORK="$TMPDIR/flac2mp3.$$"
ERR="$WORK/stderr.txt"
WAV="$WORK/track.wav"
TAGS="$WORK/track.tags"
COVER="$WORK/track.jpg"
# Get absolute directory paths
cd "$INPUTDIR" || exit
INPUTDIR="$PWD"
cd "$OLDPWD" || exit
# Create output directory if it doesn't exist
if [ ! -d "$OUTPUTDIR" ]; then
  mkdir -p "$OUTPUTDIR"
  if [ ! -d "$OUTPUTDIR" ]; then
    echo "ERROR: Could not create output directory $OUTPUTDIR" >&2
    exit 1
  fi
fi

cd "$OUTPUTDIR" || exit
OUTPUTDIR="$PWD"
# Setup work directory
rm -rf "$WORK"
if [ -e "$WORK" ]; then
echo "Couldn't delete $WORK"
exit 1
fi
mkdir "$WORK"
if [ ! -d "$WORK" ]; then
echo "Couldn't create $WORK"
exit 1
fi
# Function to process a single FLAC file
process_file() {
  local filepath="$1"
  local WORK="$TMPDIR/flac2mp3.$$.$filepath"
  local ERR="$WORK/stderr.txt"
  local WAV="$WORK/track.wav"
  local TAGS="$WORK/track.tags"
  local COVER="$WORK/track.jpg"
  
  local filedir
  local filename
  filedir="$(dirname "$filepath")"
  filename="$(basename "$filepath")"
  
  # Setup work directory for this file
  rm -rf "$WORK"
  mkdir -p "$WORK"
  if [ ! -d "$WORK" ]; then
    echo "Couldn't create $WORK"
    return 1
  fi
  
  if [ ! -d "$OUTPUTDIR/$filedir" ]; then
    mkdir -p "$OUTPUTDIR/$filedir"
  fi
  
  if [ ! -f "$OUTPUTDIR/$filepath.mp3" ]; then
    # Lock the working file
    if [ -x "$DOTLOCKFILE" ]; then
      if ! "$DOTLOCKFILE" -p -r 0 -l "$OUTPUTDIR/$filepath".lock; then
        # Could not get a lock, so skip to next file
        return 0
      fi
    elif [ -x "$SHLOCK" ]; then
      if ! "$SHLOCK" -f "$OUTPUTDIR/$filepath".lock -p $$; then
        # Could not get a lock, so skip to next file
        return 0
      fi
    fi
    
    # Clear tags
    rm -f "$TAGS"
    local ARTIST=
    local ALBUM=
    local TITLE=
    local DATE=
    local GENRE=
    local TRACKNUMBER=
    
    # Get tags
    $METAFLAC --export-tags-to="$TAGS" "$INPUTDIR/$filepath.flac"
    sed -i -e 'h
    s/^[^=]*=//
    s/"/\\"/g
    s/\$/\\$/g
    s/^.*$/"&"/
    x
    s/=.*$//
    y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/
    G
    s/\n/=/' "$TAGS"
    source "$TAGS"
    echo "$ARTIST / $ALBUM ($DATE) / $TRACKNUMBER - $TITLE"
    
    #Get cover
    $METAFLAC --export-picture-to="$COVER" "$INPUTDIR/$filepath.flac"
    
    # Decode FLAC (loop until success or MAXFAILS reached)
    local attempt=0
    local success=0
    while (( ! success )) && (( attempt < MAXFAILS )); do
      (( attempt++ ))
      rm -f "$ERR" "$WAV"
      echo -n "Decoding attempt $attempt: "
      if $FLAC -sd -o "$WAV" "$INPUTDIR/$filepath.flac" 2> "$ERR" && [ ! -s "$ERR" ]; then
        success=1
        echo "OK"
      else
        echo "FAILED"
        # Waiting seems to help
        sleep 2
      fi
    done
    
    if (( attempt > MAXFAILS )); then
      echo "$MAXFAILS decode attempts failed, aborting"
      cat "$ERR"
      return 1
    fi
    
    # Encode MP3
    if ! $LAME "$LAME_OPTS" --tt "$TITLE" --ta "$ARTIST" --tl "$ALBUM" \
    --tn "$TRACKNUMBER" --tg "$GENRE" --ty "$DATE" \
    --ti "$COVER" \
    "$WAV" "$OUTPUTDIR/$filepath.mp3"; then
      echo ""
      echo "Encode failed, retrying sans genre"
      if ! $LAME "$LAME_OPTS" --tt "$TITLE" --ta "$ARTIST" --tl "$ALBUM" \
      --tn "$TRACKNUMBER" --ty "$DATE" \
      "$WAV" "$OUTPUTDIR/$filepath.mp3"; then
        echo ""
        echo "Encode failed, aborting"
        return 1
      fi
    fi
    
    echo ""
    echo ""
    
    # Remove cover file
    if [ -x "$COVER" ]; then
      rm -f "$COVER"
    fi
    
    # Remove the lock file
    if [ -x "$DOTLOCKFILE" ]; then
      "$DOTLOCKFILE" -u "$OUTPUTDIR/$filepath".lock
    elif [ -x "$SHLOCK" ]; then
      rm -f "$OUTPUTDIR/$filepath".lock
    fi
  fi
  
  # Clean up
  rm -rf "$WORK"
  return 0
}

# Get input file list
cd "$INPUTDIR" || exit
OLDIFS="$IFS"
IFS=$'\n'
mapfile -t FLAC_FILES < <(find . -type f -name '*.flac' -print | sort | sed -e 's/^\.\///' -e 's/\.flac$//')
IFS="$OLDIFS"

# Process files in parallel
echo "Processing ${#FLAC_FILES[@]} FLAC files with up to $MAX_PARALLEL parallel processes (detected $PHYSICAL_CORES physical cores)"
RUNNING=0
for filepath in "${FLAC_FILES[@]}"; do
  # Limit the number of parallel processes
  if [ $RUNNING -ge $MAX_PARALLEL ]; then
    wait -n  # Wait for any child process to exit
    RUNNING=$((RUNNING - 1))
  fi
  
  # Process the file in the background
  process_file "$filepath" &
  RUNNING=$((RUNNING + 1))
done

# Wait for all remaining background processes to complete
wait

# Function to process artwork
process_artwork() {
  local filepath="$1"
  local filedir
  local filename
  filedir="$(dirname "$filepath")"
  filename="$(basename "$filepath")"
  
  if [ ! -d "$OUTPUTDIR/$filedir" ]; then
    mkdir -p "$OUTPUTDIR/$filedir"
  fi
  
  # If the input is newer than the output, or the output does not exist
  if [ "$filepath" -nt "$OUTPUTDIR/$filepath" ] || [ ! -f "$OUTPUTDIR/$filepath" ]; then
    # Lock the working file
    if [ -x "$DOTLOCKFILE" ]; then
      if ! "$DOTLOCKFILE" -p -r 0 -l "$OUTPUTDIR/$filepath".lock; then
        # Could not get a lock, so skip to next file
        return 0
      fi
    elif [ -x "$SHLOCK" ]; then
      if ! "$SHLOCK" -f "$OUTPUTDIR/$filepath".lock -p $$; then
        # Could not get a lock, so skip to next file
        return 0
      fi
    fi
    
    cp -f "$INPUTDIR/$filepath" "$OUTPUTDIR/$filepath"
    echo -n "."
    
    # Remove the lock file
    if [ -x "$DOTLOCKFILE" ]; then
      "$DOTLOCKFILE" -u "$OUTPUTDIR/$filepath".lock
    elif [ -x "$SHLOCK" ]; then
      rm -f "$OUTPUTDIR/$filepath".lock
    fi
  fi
  
  return 0
}

# Copy artwork
if [ "$COPY_ARTWORK" == "true" ]; then
  echo -n "Copying artwork: "
  
  # Get artwork file list
  cd "$INPUTDIR" || exit
  OLDIFS="$IFS"
  IFS=$'\n'
  mapfile -t ARTWORK_FILES < <(find . -type f -name '*.jpg' -print | sort | sed -e 's/^\.\///')
  IFS="$OLDIFS"
  
  # Process artwork in parallel
  RUNNING=0
  for filepath in "${ARTWORK_FILES[@]}"; do
    # Limit the number of parallel processes
    if [ $RUNNING -ge $MAX_PARALLEL ]; then
      wait -n  # Wait for any child process to exit
      RUNNING=$((RUNNING - 1))
    fi
    
    # Process the artwork in the background
    process_artwork "$filepath" &
    RUNNING=$((RUNNING + 1))
  done
  
  # Wait for all remaining background processes to complete
  wait
  
  echo " Done!"
fi
exit 0
