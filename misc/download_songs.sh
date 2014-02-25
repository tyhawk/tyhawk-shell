#!/bin/bash

PLAYLIST="http://www.youtube.com/playlist?list=PL0BD69368AB943C89"

# Load the video's into an array
printf "Fetching all YouTube video's in the playlist.\n"
printf "This may take a while, depending on the size of the playlist.\n" 
IDARRAY=( $(youtube-dl --get-id $PLAYLIST) )

printf "Processing ${#IDARRAY[@]} YouTube video's\n"

# In a loop, check if the YouTube ID has already been downloaded into the dir, if not, fetch the file
for YTID in "${IDARRAY[@]}"
do
	CHECKID=$(find . -name *"$YTID"*ogg|wc -l)
	if [[ "$CHECKID" -eq 0 ]]; then
			YOUTUBEVIDEO="http://www.youtube.com/watch?v=$YTID"
			printf "New Video discovered. Downloading $YOUTUBEVIDEO.\n"
			youtube-dl --extract-audio --audio-format vorbis --audio-quality 4 --continue --quiet --output '%(uploader)s-%(id)s-%(title)s.%(ext)s' $YOUTUBEVIDEO
	else
			printf "Video ID $YTID already downloaded. Skipping.\n"
	fi
done

printf "Finished processing.\n"

# End
###