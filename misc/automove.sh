#!/bin/bash
#
# automove - Automatic media file distributor based on filename
############################################################################
# © 2014 - John Gerritse
############################################################################

# Colours... oooh pretty!
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
normal=$(tput sgr0)
bright=$(tput bold)

####
# Functions
####
exit_int() {
  # Function to do a clean exit when an interrupt is trapped
  printf "${red}Process aborted by user${normal}\n"
  exit 0
}

exit_term() {
  # Function to do a clean exit when a termination is trapped
  echo "${red}Process terminated${normal}"
  exit 1
}

do_error() {
  printf "[${red}ERR${normal}]\n"
}

do_ok() {
  printf "[${green}OK${normal}]\n"
}

# Define the staging directory
staging="$HOME/Staging"

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
printf "${blue}${bright}   ##    #    #   #####   ####   #    #   ####   #    #  ######\n"
printf "  #  #   #    #     #    #    #  ##  ##  #    #  #    #  #\n"
printf " #    #  #    #     #    #    #  # ## #  #    #  #    #  #####\n"
printf " ######  #    #     #    #    #  #    #  #    #  #    #  #\n"
printf " #    #  #    #     #    #    #  #    #  #    #   #  #   #\n"
printf " #    #   ####      #     ####   #    #   ####     ##    ######\n"
printf "\n     Move movie and tv-show files to the proper directory${normal}\n\n"

# Dependency check - more code then before, but much nicer
my_needed_commands="rsync"

missing_counter=0
for needed_command in $my_needed_commands; do
  if ! hash "$needed_command" >/dev/null 2>&1; then
  printf "Command not found in PATH: %s\n" "$needed_command" >&2
  ((missing_counter++))
  fi
done

if ((missing_counter > 0)); then
  printf "Minimum %d commands are missing in PATH, aborting\n" "$missing_counter" >&2
  exit 1
fi

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
if [[ $(find $staging/*mkv | wc -l) -eq 0 ]]; then
  printf "No MKV files found. Exiting.\n"
  exit 0
fi

# Now we split them up into movies and tv shows
tvshows=( $(find $staging/ -type f -name '*-s??e??-*.mkv' -exec basename {} \;) ) # Add code to catch no matching files
movies=( $(find $staging/ -type f -name '*-\(????\).mkv' -exec basename {} \;) ) # Add code to catch no matching files

# We copy the TV-Show to its proper directory one by one and automatically.
for tvshowfile in "${tvshows[@]}"
do
  # Extract the show's proper name from the variable
  showname=$(echo "$tvshowfile" | cut --delimiter=\- --fields=1)
  # Extract season as well
  showepnum=$(echo "$tvshowfile" | cut --delimiter=\- --fields=2)
  season="${showepnum:1:2}"
  # Check if the location exists and if not, create it
  showlocation="$tvshowroot/$showname/Season$season"
  if [[ ! -d "$showlocation" ]]; then
    mkdir -p $showlocation
  fi
  # We move the file to its proper location
  printf "Moving file $tvshow to $showlocation:\n"
  rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $staging/$tvshowfile $showlocation
  if [[ "$?" -gt 0 ]]; then
    printf "  Transfer completed: "; do_error
  else
    printf "  Transfer completed: "; do_ok
  fi
  printf "\n${blue}#${yellow}--------------------------------------------------------------${blue}#${normal}\n\n"
done

# Movies are easier, they all go into one directory
for moviefile in "${movies[@]}"
do
    # We move the file to its proper location
  printf "Moving file $moviefile to $movieroot:\n"
  rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $staging/$moviefile $movieroot
  if [[ "$?" -gt 0 ]]; then
    printf "  Transfer completed: "; do_error
  else
    printf "  Transfer completed: "; do_ok
  fi
  printf "\n${blue}#${yellow}--------------------------------------------------------------${blue}#${normal}\n\n"
done

printf "${blue}${bright}ALL FILES MOVED. EXITING.${normal}\n"
## END SCRIPT
