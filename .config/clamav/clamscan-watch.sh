#!/bin/bash
WATCH_DIR="$1"

inotifywait -m -r -e close_write -e moved_to "$WATCH_DIR" |
while read dir event file; do
    clamdscan --fdpass "$dir$file"
done
