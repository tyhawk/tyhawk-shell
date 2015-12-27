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
  # Check if there are any new files in the workdir
  if [[ $(ls $workdir/ | wc -l) -eq 0 ]]
  then
    # Check if there are files in the pre-queue
    if [[ $(ls $prequeue/ | wc -l) -eq 0 ]]
    then
      exit 0
    else
      # There are still files. Move the top file to the workdir
      oldestfile=$(ls -rt "$prequeue" | head -n 1 | awk -F "-" '{ print $1 }')
      filetomove=$(ls $prequeue/${oldestfile}* | sort -u | head -n 1)
      basefile=$(basename $filetomove)
      # Remove suffix so we don't miss any subtitles
      filename="${basefile%.*}"
      # Move the file (and subs if there are any) to the workdir
      mv $prequeue/${filename}.* $workdir/
    fi
  fi
  # Start MediaPrep
  $HOME/bin/mediaprep
done
