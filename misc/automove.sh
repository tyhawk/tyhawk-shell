#!/bin/bash
#
# automove - Automatic media file distributor based on filename
############################################################################
# (c) 2014 - John Gerritse
############################################################################

# Colours... oooh pretty!
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NORMAL=$(tput sgr0)
BRIGHT=$(tput bold)

####
# Functions
####
exit_int() {
    # Function to do a clean exit when an interrupt is trapped
    printf "${RED}Process aborted by user${NORMAL}\n"
    exit 0
}

exit_term() {
    # Function to do a clean exit when a termination is trapped
    echo "${RED}Process terminated${NORMAL}"
    exit 1
}

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

####
# The script itself
####

# Trap TERM, HUP, and INT signals and properly exit
trap exit_term TERM HUP
trap exit_int INT

# Clear screen en print 'logo'
clear
printf "${BLUE}${BRIGHT}   ##    #    #   #####   ####   #    #   ####   #    #  ######\n"
printf "  #  #   #    #     #    #    #  ##  ##  #    #  #    #  #\n"
printf " #    #  #    #     #    #    #  # ## #  #    #  #    #  #####\n"
printf " ######  #    #     #    #    #  #    #  #    #  #    #  #\n"
printf " #    #  #    #     #    #    #  #    #  #    #   #  #   #\n"
printf " #    #   ####      #     ####   #    #   ####     ##    ######\n"
printf "\n     Move movie and tv-show files to the proper directory${NORMAL}\n\n"

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

# First check if there are MKV files in the Staging dir
if [[ $(find $STAGING/*mkv | wc -l) -eq 0 ]]; then
    printf "No MKV files found. Exiting.\n"
    exit 0
fi

# Now we split them up into movies and tv shows
tvshows=( $(basename "$(find $STAGING/ -type f -name '*-s??e??-*.mkv' -exec basename {} \;)" ) ) # Add code to catch no matching files
movies=( $(basename "$(find $STAGING/ -type f -name '*-\(....\).mkv' -exec basename {} \;)" ) ) # Add code to catch no matching files

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
    printf "\n#--------------------------------------------------------------#\n\n"
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
    printf "\n${BLUE}#${YELLOW}--------------------------------------------------------------${BLUE}#${NORMAL}\n\n"
done

printf "${BLUE}${BRIGHT}ALL FILES MOVED. EXITING.${NORMAL}\n"
## END SCRIPT
