#!/bin/bash

# Only start if not running
if [[ $(ps -ef | grep 1080 | grep 'tyhawk@tyhawk.synology.me' | grep -v grep | wc -l) -ne 1 ]]; then
    printf "Starting SSH tunnel.\n"
    ssh -N -g -D 1080 tyhawk@tyhawk.synology.me -L 6112/*/6112 -L 3724/*/3724 &
fi
printf "Starting World of Warcraft.\n"
tsocks /Applications/World\ of\ Warcraft/World\ of\ Warcraft.app/Contents/MacOS/World\ of\ Warcraft &
