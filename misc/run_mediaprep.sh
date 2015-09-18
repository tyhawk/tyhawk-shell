#!/bin/bash
workdir="/home/tyhawk/TransFusion/01_Queue"
prequeue="/home/tyhawk/TransFusion/90_Prequeue"

while :
do
	# First check to see if there is a file named "stop" in the workdir.
	# This wil help us stop the script dead in its tracks
	if [[ -e "$workdir/stop" ]]
	then
		exit 0
	fi
	# Start MediaPrep
	$HOME/bin/mediaprep
	# Check if there are any new files in the workdir
	if [[ $(ls $workdir/ | wc -l) -eq 0 ]]
	then
		# Check if there are files in the pre-queue
		if [[ $(ls $prequeue/ | wc -l) -eq 0 ]]
		then
			exit 0
		else
			# There are still files. Move the top file to the workdir
			filename=$(find /home/tyhawk/TransFusion/90_Prequeue -type f -name '*avi' -o -name '*mp4' -o -name '*mkv' -exec basename {} \; | sort -u | head -n 1) 
			# Remove suffix so we don't miss any subtitles
			filename="${filename%.*}"
			# Move the file (and subs if there are any) to the workdir
			mv $prequeue/${filename}.* $workdir/
		fi
	fi
done
