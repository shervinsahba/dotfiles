#!/bin/bash
WATCH_DIR="$1"

inotifywait -m -r -q -e close_write -e moved_to --format '%w%f' "$WATCH_DIR" |
while IFS= read -r path; do
    clamdscan --fdpass --no-summary "$path"
done
