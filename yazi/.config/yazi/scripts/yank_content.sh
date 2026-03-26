#!/bin/bash
if [ "$#" -ne 1 ]; then
  echo "yank.sh: only single file supported" >&2
  exit 1
fi

file="$1"
ext="${file##*.}"
ext="${ext,,}" # lowercase

case "$ext" in
png)
  osascript -e "set the clipboard to (read (POSIX file \"$file\") as «class PNGf»)"
  ;;
jpg | jpeg)
  osascript -e "set the clipboard to (read (POSIX file \"$file\") as JPEG picture)"
  ;;
gif)
  osascript -e "set the clipboard to (read (POSIX file \"$file\") as GIF picture)"
  ;;
*)
  # fallback: copy content as plain text/data
  pbcopy <"$file"
  ;;
esac
