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

# Dependency check
hash rsync 2>/dev/null || { printf "Could not find rsync.\nPlease make sure it is installed.\nAborting ..." >&2; exit 1; }

# Check if root dirs exist
if [[ ! -d "$tvshowroot" ]]; then
    printf "Directory $tvshowroot not found: "; do_error
    exit 1
fi
if [[ ! -d "$movieroot" ]]; then
    printf "Directory $movieroot not found: "; do_error
    exit 1
fi

   ##    #    #   #####   ####   #    #   ####   #    #  ######
  #  #   #    #     #    #    #  ##  ##  #    #  #    #  #
 #    #  #    #     #    #    #  # ## #  #    #  #    #  #####
 ######  #    #     #    #    #  #    #  #    #  #    #  #
 #    #  #    #     #    #    #  #    #  #    #   #  #   #
 #    #   ####      #     ####   #    #   ####     ##    ######


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
for tvshowfile in "${tvshows[@]}"
do
    # Extract the show's proper name from the variable
    showname=$(echo "$tvshowfile" | cut --delimiter=\- --fields=1)
    # Extract season as well
    showepnum=$(echo "$tvshowfile" | cut --delimiter=\- --fields=2)
    season="$((10#${showepnum:1:2}))"
    # Check if the location exists and if not, create it
    showlocation="$tvshowroot/$showname/Season$season"
    if [[ ! -d "$showlocation" ]]; then
        mkdir -p $showlocation
    fi
    # We move the file to its proper location
    printf "Moving file $tvshow to $showlocation:\n"
    rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $STAGING/$tvshowfile $showlocation
    if [[ "$?" -gt 0 ]]; then
        printf "  Transfer completed: "; do_error
    else
        printf "  Transfer completed: "; do_ok
    fi
done

# Movies are easier, they all go into one directory
for moviefile in "${movies[@]}"
do
        # We move the file to its proper location
    printf "Moving file $moviefile to $movieroot:\n"
    rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $STAGING/$moviefile $movieroot
    if [[ "$?" -gt 0 ]]; then
        printf "  Transfer completed: "; do_error
    else
        printf "  Transfer completed: "; do_ok
    fi
done

## END SCRIPT
