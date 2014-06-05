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

# Functions
do_error() {
    printf "[${RED}ERR${NORMAL}]\n"
}

do_ok() {
    printf "[${GREEN}OK${NORMAL}]\n"
}

# Define the staging directory
STAGING="$HOME/Staging"

# Define root dirs for TV shows & movies
tvshowroot="/media/EHD01/Plex/TV-Shows"
movieroot="/media/EHD02/Plex/Movies"

printf "Starting automove.\n"

# First check if there are MKV files in the Staging dir
if [[ $(find $STAGING/*mkv | wc -l) -eq 0 ]]; then
    printf "No MKV files found. Exiting.\n"
    exit 0
fi

# Now we split them up into movies and tv shows
tvshows=( $(basename "$(ls $STAGING/*-s..e..-*mkv)" ) )
movies=( $(basename "$(ls $STAGING/*-\(....\).mkv)" ) )

# We copy the TV-Show to its proper directory one by one and automatically.
for tvshow in "${tvshows[@]}"
do
    # Extract the show's proper name from the variable
    showname=$(echo "$tvshow" | cut --delimiter=\- --fields=1)
    # We locate the proper dir for the tv show
    showlocation=$(find /$tvshowroot/* -name $showname -type d)
    # We move the file to its proper location
    printf "Moving file $tvshow to $showlocation:\n"
    rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $STAGING/$tvshow $showlocation
    if [[ "$?" -gt 0 ]]; then
        printf "  Transfer completed: "; do_error
    else
        printf "  Transfer completed: "; do_ok
    fi
done

# Movies are easier, they all go into one directory
for movie in "${movies[@]}"
do
        # We move the file to its proper location
    printf "Moving file $movie to $movieroot:\n"
    rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $STAGING/$movie $movieroot
    if [[ "$?" -gt 0 ]]; then
        printf "  Transfer completed: "; do_error
    else
        printf "  Transfer completed: "; do_ok
    fi
done

## END SCRIPT
