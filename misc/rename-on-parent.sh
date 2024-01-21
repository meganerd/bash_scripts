#!/usr/bin/env bash
# from https://superuser.com/questions/1602705/recursively-renaming-files-under-subdirectories-with-the-directory-name-with-lin
find . -path '*/*/*' -type f -iname \*.html -print -exec sh -c '
   f="$1"
   d="${f%/*}"
   cd "$d" || exit 1
   d="${d##*/}"
   f="${f##*/}"
   e="${f##*.}"
   if [ "$e" = "$f" ]; then
      e=""
   else
      e=".$e"
   fi
   mv -i -- "$f" "_$d$e"
  ' find-sh {} \;
