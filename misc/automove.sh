#!/bin/bash
#
# automove - Automatic media file distributor based on filename
############################################################################
# © 2014 - John Gerritse - version 1.2
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
  cleanup
  exit 0
}

exit_term() {
  # Function to do a clean exit when a termination is trapped
  echo "${red}Process terminated${normal}"
  cleanup
  exit 1
}

cleanup () {
  rm $lf
}

move_movie () {
    # Movies are easier, they all go into one directory
    for moviefile in "${movies[@]}"
    do
        # We move the file to its proper location
        printf "$(date +"%b %d %H:%M:%S") moving file $moviefile to $movieroot\n"  >> $logfile
        rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $staging/$moviefile $movieroot
        if [[ "$?" -gt 0 ]]; then
            printf "$(date +"%b %d %H:%M:%S") transfer of $moviefile failed\n" >> $logfile
        else
            printf "$(date +"%b %d %H:%M:%S") transfer of $moviefile completed\n" >> $logfile
        fi
    done
}

move_tvshow () {
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
        printf "$(date +"%b %d %H:%M:%S") moving file $tvshow to $showlocation\n" >> $logfile
        rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $staging/$tvshowfile $showlocation
        if [[ "$?" -gt 0 ]]; then
            printf "$(date +"%b %d %H:%M:%S") transfer of $tvshow failed\n" >> $logfile
        else
            printf "$(date +"%b %d %H:%M:%S") transfer of $tvshow completed\n" >> $logfile
        fi
    done
}

#Staging directory
staging="$HOME/PLEX/03_Finished/"

# Define root dirs for TV shows & movies
tvshowroot="/mnt/TV"
movieroot="/mnt/Movies"

# Logfile
logfile="$HOME/automove.log"

####
# The script itself
####

# Trap TERM, HUP, and INT signals and properly exit
trap exit_term TERM HUP
trap exit_int INT

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
  printf "Directory $tvshowroot not found: [ERROR]"
  exit 1
fi
if [[ ! -d "$movieroot" ]]; then
  printf "Directory $movieroot not found: [ERROR]"
  exit 1
fi

# Check the lockfile
lf=/tmp/pidLockFile
# create empty lock file if none exists
if [[ ! -e $lf ]]; then
    cat /dev/null >> $lf
fi
# It exists, so we read the PID in the file into lastPID
read lastPID < $lf

# if lastPID is not null and a process with that pid exists , exit
if [[ ! -z "$lastPID" ]] && [[ -d "/proc/$lastPID" ]]; then
    printf "$(date +"%b %d %H:%M:%S") Automove already running ($lastPID).\n" >> $logfile
    printf "$(date +"%b %d %H:%M:%S") Exiting this instance ($$).\n" >> $logfile
    exit 0
else
    # save my pid in the lock file
    echo $$ > $lf
    # sleep just to make testing easier
    sleep 5
    # Time to start our loop
    while true
    do
        # Time to start checking for files
        # First check if there are MKV files in the Staging dir
        if [[ $(find $staging/*mkv | wc -l) -eq 0 ]]; then
            printf "$(date +"%b %d %H:%M:%S") No MKV files found. Sleeping for 60 seconds.\n" >> $logfile
            sleep 60
        else
            # Move the movie files first
            movies=( $(find $staging/ -type f -name '*-\(????\).mkv' -exec basename {} \;) )
            if [[ -n "$movies" ]]; then
                move_movie
            fi
            # Next, tv shows
            tvshows=( $(find $staging/ -type f -name '*-s??e??-*.mkv' -exec basename {} \;) )
            if [[ -n "$tvshow" ]]; then
                move_tvshow
            fi
            # Now, we sleep for one minute
            sleep 60
        fi
    done
fi
cleanup
## END SCRIPT
