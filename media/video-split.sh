#!/bin/bash

# Original version by Alexis Bezverkhyy.  Short term TODO, parameterize 
# the inputs instead of relying on parameter position.

# Written by Alexis Bezverkhyy <alexis@grapsus.net> in 2011
# This is free and unencumbered software released into the public domain.
# For more information, please refer to <http://unlicense.org/>
 
function usage {
        echo "Usage : ffsplit.sh input.file chunk-duration [output-filename-format]"
        echo -e "\t - input file may be any kind of file reconginzed by ffmpeg"
        echo -e "\t - chunk duration must be in seconds"
        echo -e "\t - output filename format must be printf-like, for example myvideo-part-%04d.avi"
        echo -e "\t - if no output filename format is given, it will be computed\
 automatically from input filename"
}
 
IN_FILE="$1"
OUT_FILE_FORMAT="$3"
typeset -i CHUNK_LEN
CHUNK_LEN="$2"
 
DURATION_HMS=$(ffmpeg -i "$IN_FILE" 2>&1 | grep Duration | cut -f 4 -d ' ')
DURATION_H=$(echo "$DURATION_HMS" | cut -d ':' -f 1)
DURATION_M=$(echo "$DURATION_HMS" | cut -d ':' -f 2)
DURATION_S=$(echo "$DURATION_HMS" | cut -d ':' -f 3 | cut -d '.' -f 1)
(( DURATION = ( DURATION_H * 60 + DURATION_M ) * 60 + DURATION_S ))
 
if [ "$DURATION" = '0' ] ; then
        echo "Invalid input video"
        usage
        exit 1
fi
 
if [ "$CHUNK_LEN" = "0" ] ; then
        echo "Invalid chunk size"
        usage
        exit 2
fi
 
if [ -z "$OUT_FILE_FORMAT" ] ; then
        FILE_EXT="${IN_FILE##*.}"
        FILE_NAME="${IN_FILE%.*}"
        OUT_FILE_FORMAT="${FILE_NAME}-%03d.${FILE_EXT}"
        echo "Using default output file format : $OUT_FILE_FORMAT"
fi
 
N='1'
OFFSET='0'
(( N_FILES = DURATION / CHUNK_LEN + 1 ))
 
while [ "$OFFSET" -lt "$DURATION" ] ; do
        printf -v OUT_FILE "$OUT_FILE_FORMAT" "$N"
        echo "writing $OUT_FILE ($N/$N_FILES)..."
        ffmpeg -i "$IN_FILE" -vcodec copy -acodec copy -ss "$OFFSET" -t "$CHUNK_LEN" "$OUT_FILE"
        (( N = N + 1 ))
        (( OFFSET = OFFSET + CHUNK_LEN ))
done
