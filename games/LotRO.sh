#!/bin/bash

# Only start if not running
if [[ $(ps -ef | grep 1080 | grep 'tyhawk@tyhawk.synology.me' | grep -v grep | wc -l) -ne 1 ]]; then
    printf "Starting SSH tunnel.\n"
    ssh -C2qTnN -D 1080 tyhawk@tyhawk.synology.me &
fi
