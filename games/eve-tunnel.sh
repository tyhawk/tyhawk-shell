#!/bin/bash
# Start an SSH tunnel for EVE Online.
# Make sure to start your client with the argument "/server:127.0.0.1" in the EVE Launcher.

remotehost="macaw.birdsnest.lan"
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

# Start EMDU for localhost cache
printf "\nStarting EMDU for the proxied EVE Client:\n"
#emdu_console --enable-deletion --add-eve "/Users/jgerritse/Library/Application\ Support/EVE\ Online/p_drive/Local\ Settings/Application\ Data/CCP/EVE/c_program_files_ccp_eve_127.0.0.1/cache/MachoNet/127.0.0.1/415"
emdu_console --enable-deletion 
