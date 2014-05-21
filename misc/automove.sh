#!/bin/bash
#
# automove - Automatic file distributor based on filename
############################################################################
# (c) 2014 - John Gerritse
############################################################################

# Colours... oooh pretty!
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

# Define the staging directory
STAGING="$HOME/Staging"

printf "Starting automove.\n"

# First check if there are MKV files in the Staging dir
if [[ $(find $STAGING/*mkv | wc -l) -eq 0 ]]; then
    printf "No MKV files found. Exiting.\n"
    exit 0
fi

# Now we check if any files are for TV Shows we know
tvshows=( $(basename "$(ls $STAGING/*-s..e..-*mkv)" ) )

# We copy the TV-Show to its proper directory one by one and automatically.
for tvshow in "${tvshows[@]}"
do
    # Extract the show's proper name from the variable
    showname=$(echo "$tvshow" | cut --delimiter=\- --fields=1)
    # We locate the proper dir for the tv show
    showlocation=$(find /export/* -name $showname -type d)
    # We move the file to its proper location
    printf "Moving file $tvshow to $showlocation... "
    trap 'printf "${RED}ERR{NORMAL}\n"' 1
    mv $tvshow $showlocation && printf "${GREEN}OK${NORMAL}\n"
    # Sync the hard drive
    printf "Sync changes to hard drive... "
    trap 'printf "${RED}ERR{NORMAL}\n"' 1
    sync && printf "${GREEN}OK${NORMAL}\n"
    # Pause to not hammer the EHD
    printf "Sleeping for 30 seconds... "
    sleep 30 && printf "DONE!\n"
done

# Create a mechanism for Movie files.
# Idea: file syntax differences. title-YYYY.mkv for normal movies, title-YYYY-NL.mkv for kids movies.
