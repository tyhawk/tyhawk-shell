#!/bin/bash
# Start an SSH tunnel for EVE Online.
# Make sure to start your client with the argument "/server:127.0.0.1" in the EVE Launcher.

remotehost="tyhawk@84.104.234.218"
remoteport="22"

# Only start if not running
if [[ $(ps -ef | grep 26000 | grep "$remotehost" | grep -v grep | wc -l) -ne 1 ]]; then
    printf "Starting SSH tunnel for EVE Online "
    ssh -f -p $remoteport -L 26000:87.237.38.200:26000 $remotehost -N
	if [[ "$?" -eq 0 ]]; then
		printf "[ OK ]\n"
	else
		printf "[FAIL]\n"
	fi
else
	printf "SSH tunnel for EVE Online already running."
fi
