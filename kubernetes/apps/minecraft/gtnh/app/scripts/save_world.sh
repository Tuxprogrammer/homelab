#!/bin/sh
VOLATILE="/data/World_ramdisk"
PERMANENT="/data/World"

while true
do
    rsync -r -t -v "$VOLATILE" "$PERMANENT"
    sleep 300
done
