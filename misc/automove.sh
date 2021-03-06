#!/bin/bash
#
# automove - Automatic media file distributor based on filename
############################################################################
# © 2014 - John Gerritse - version 1.2
############################################################################

####
# Functions
####
exit_int() {
  # Function to do a clean exit when an interrupt is trapped
  printf "$(date +"%b %d %H:%M:%S") Process aborted by user.\n"  >> $logfile
  cleanup
  exit 0
}

exit_term() {
  # Function to do a clean exit when a termination is trapped
  printf "$(date +"%b %d %H:%M:%S") Process terminated.\n"  >> $logfile
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
        # Extract the name we need to create the correct directory
        moviedirname="${moviefile%.*}"
        moviedir="$movieroot/$moviedirname"
        # Create a subdirectory for the movie
        if [[ ! -d "$moviedir" ]]
        then
          mkdir -p $moviedir
          chmod 755 $moviedir
        fi
        # We move the file to its proper location
        printf "$(date +"%b %d %H:%M:%S") Moving file $moviefile to $movieroot\n"  >> $logfile
        rsync --perms --times --progress --human-readable --compress --remove-source-files --partial "$staging/$moviefile" "$moviedir"
        if [[ "$?" -gt 0 ]]; then
            printf "$(date +"%b %d %H:%M:%S") Transfer of $moviefile failed\n" >> $logfile
        else
            printf "$(date +"%b %d %H:%M:%S") Transfer of $moviefile completed\n" >> $logfile
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
            chmod 755 "$tvshowroot/$showname"
            chmod 755 $showlocation
        fi
        # We move the file to its proper location
        printf "$(date +"%b %d %H:%M:%S") Moving file $tvshowfile to $showlocation\n" >> $logfile
        rsync --perms --times --progress --human-readable --compress --remove-source-files --partial "$staging/$tvshowfile" "$showlocation"
        if [[ "$?" -gt 0 ]]; then
            printf "$(date +"%b %d %H:%M:%S") Transfer of $tvshowfile failed\n" >> $logfile
        else
            printf "$(date +"%b %d %H:%M:%S") Transfer of $tvshowfile completed\n" >> $logfile
        fi
    done
}

#Staging directory
staging="$HOME/TransFusion/03_Finished"

# Define root dirs for TV shows & movies
tvshowroot="/mnt/TVSeries"
movieroot="/mnt/Speelfilm"
dumpster="$HOME/TransFusion/99_Dumpster/"

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
    printf "$(date +"%b %d %H:%M:%S") Starting automove ($$).\n" >> $logfile
    # save my pid in the lock file
    echo $$ > $lf
    # sleep just to make testing easier
    sleep 5s
    # Time to start
    # Move the movie files first
    printf "$(date +"%b %d %H:%M:%S") Processing movies.\n" >> $logfile
    movies=( $(find $staging/ -type f -name '*-\(????\).mkv' -exec basename {} \;) )
    if [[ ! -z "$movies" ]]; then
        move_movie
    else
      printf "$(date +"%b %d %H:%M:%S") No movies found.\n" >> $logfile
    fi
    # Next, tv shows
    printf "$(date +"%b %d %H:%M:%S") Processing tv shows (if any are there).\n" >> $logfile
    tvshows=( $(find $staging/ -type f -name "*-s??e??-*.mkv" -exec basename {} \;) )
    if [[ ! -z "$tvshows" ]]; then
        move_tvshow
    else
      printf "$(date +"%b %d %H:%M:%S") No tv shows found.\n" >> $logfile
    fi
    # And delete old files from the trash folder to regain space (anything older then 4 hours)
    printf "$(date +"%b %d %H:%M:%S") Purging old files from $dumpster.\n" >> $logfile
    find $dumpster -cmin +800 -type f -delete
fi
cleanup

# Kick off trailerdownload
printf "$(date +"%b %d %H:%M:%S") Starting trailer download\n" >> $logfile
$HOME/bin/trailerdownload.sh
printf "$(date +"%b %d %H:%M:%S") Trailer download finished\n" >> $logfile
printf "$(date +"%b %d %H:%M:%S") Automove completed. Exiting.\n" >> $logfile
## END SCRIPT
