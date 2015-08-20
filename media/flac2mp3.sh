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
# Usage: flac2mp3 <input-dir> <output-dir>
### Begin Configuration
# The values below will be overridden by those in ~/.flac2mp3.conf if it
# exists
# Copy artwork (*.jpg) files? Set to "true" or "false"
COPY_ARTWORK="true"
# Where we store working data (including the decoded wav file)
TMPDIR="/tmp"
# Path to flac binary
FLAC="$(which flac)"
# Path to metaflac binary (part of flac distribution)
METAFLAC="$(which metaflac)"
# Path to lame binary
LAME="$(which lame)"
# Options to pass to lame during encoding
LAME_OPTS="--vbr-new -V 4 -h --nohist --resample 44100"
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
# Were we called correctly?
if [ -z "$1" -o -z "$2" ]; then
echo "Usage: flac2mp3 <input-dir> <output-dir>" >&2
exit 1
fi
WORK="$TMPDIR/flac2mp3.$$"
ERR="$WORK/stderr.txt"
WAV="$WORK/track.wav"
TAGS="$WORK/track.tags"
COVER="$WORK/track.jpg"
# Get absolute directory paths
INPUTDIR="$1"
OUTPUTDIR="$2"
cd "$INPUTDIR"
INPUTDIR="$PWD"
cd "$OLDPWD"
cd "$OUTPUTDIR"
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
# Get input file list
cd "$INPUTDIR"
OLDIFS="$IFS"
IFS=$'\n'
for filepath in $(find . -type f -name '*.flac' -print \
| sort | sed -e 's/^\.\///' -e 's/\.flac$//'); do
IFS="$OLDIFS"
filedir="$(dirname "$filepath")"
filename="$(basename "$filepath")"
if [ ! -d "$OUTPUTDIR/$filedir" ]; then
mkdir -p "$OUTPUTDIR/$filedir"
fi
if [ ! -f "$OUTPUTDIR/$filepath.mp3" ]; then
# Lock the working file
if [ -x "$DOTLOCKFILE" ]; then
if ! "$DOTLOCKFILE" -p -r 0 -l "$OUTPUTDIR/$filepath".lock; then
# Could not get a lock, so skip to next file
continue
fi
elif [ -x "$SHLOCK" ]; then
if ! "$SHLOCK" -f "$OUTPUTDIR/$filepath".lock -p $$; then
# Could not get a lock, so skip to next file
continue
fi
fi
# Clear tags
rm -f "$TAGS"
ARTIST=
ALBUM=
TITLE=
DATE=
GENRE=
TRACKNUMBER=
# Get tags
$METAFLAC --export-tags-to="$TAGS" "$filepath.flac"
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
$METAFLAC --export-picture-to="$COVER" "$filepath.flac"
# Decode FLAC (loop until success or MAXFAILS reached)
attempt=0
success=0
while (( ! $success )) && (( $attempt < $MAXFAILS )); do
let attempt++
rm -f "$ERR" "$WAV"
echo -n "Decoding attempt $attempt: "
$FLAC -sd -o "$WAV" "$filepath.flac" 2> "$ERR"
if (( ! $? )) && [ ! -s "$ERR" ]; then
success=1
echo "OK"
else
echo "FAILED"
# Waiting seems to help
sleep 2
fi
done
if (( $attempt > $MAXFAILS )); then
echo "$MAXFAILS decode attempts failed, aborting"
cat "$ERR"
exit 1
fi
# Encode MP3
$LAME $LAME_OPTS  --tt "$TITLE" --ta "$ARTIST" --tl "$ALBUM" \
--tn "$TRACKNUMBER" --tg "$GENRE" --ty "$DATE" \
--ti "$COVER" \
"$WAV" "$OUTPUTDIR/$filepath.mp3"
if (( $? )); then
echo ""
echo "Encode failed, retrying sans genre"
$LAME $LAME_OPTS --tt "$TITLE" --ta "$ARTIST" --tl "$ALBUM" \
--tn "$TRACKNUMBER" --ty "$DATE" \
"$WAV" "$OUTPUTDIR/$filepath.mp3"
if (( $? )); then
echo ""
echo "Encode failed, aborting"
exit 1
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
done
# Copy artwork
if [ "$COPY_ARTWORK" == "true" ]; then
echo -n "Copying artwork: "
OLDIFS="$IFS"
IFS=$'\n'
for filepath in $(find . -type f -name '*.jpg' -print \
| sort | sed -e 's/^\.\///'); do
IFS="$OLDIFS"
filedir="$(dirname "$filepath")"
filename="$(basename "$filepath")"
if [ ! -d "$OUTPUTDIR/$filedir" ]; then
mkdir -p "$OUTPUTDIR/$filedir"
fi
# If the input is newer than the output, or the output does not exist
if [ "$filepath" -nt "$OUTPUTDIR/$filepath" ]; then
# Lock the working file
if [ -x "$DOTLOCKFILE" ]; then
if ! "$DOTLOCKFILE" -p -r 0 -l "$OUTPUTDIR/$filepath".lock; then
# Could not get a lock, so skip to next file
continue
fi
elif [ -x "$SHLOCK" ]; then
if ! "$SHLOCK" -f "$OUTPUTDIR/$filepath".lock -p $$; then
# Could not get a lock, so skip to next file
continue
fi
fi
cp -f "$filepath" "$OUTPUTDIR/$filepath"
echo -n "."
# Remove the lock file
if [ -x "$DOTLOCKFILE" ]; then
"$DOTLOCKFILE" -u "$OUTPUTDIR/$filepath".lock
elif [ -x "$SHLOCK" ]; then
rm -f "$OUTPUTDIR/$filepath".lock
fi
fi
done
echo " Done!"
fi
# Clean up
rm -rf "$WORK"
exit
