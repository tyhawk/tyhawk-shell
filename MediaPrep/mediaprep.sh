#!/bin/bash
#############################################################################
# mediaprep - the One-Stop TV Show & Movie File Preparer & Uploader
#             (not named OSTVSMFPU because mediaprep is easier to remember)
# © 2014 John Gerritse
#
# Create a fully transcoded MKV file of TV episodes & Movies in one script
#############################################################################
# Ideas (remove this later)
# - Script creates job files through user interaction
# - Script processes job files without user interaction
#
# TODO LOCKFILE mechanism to prevent 2 instances from running jobs.
#               Creating jobs is allowed when an instance is already running.
#############################################################################

# Know thyself
PROGNAME=$(basename $0)
# Check in which directory I am installed
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Not sure what would be a nice place to stick the conf file yet
# For now, I will leave it in the same dir as the script
mediaprepconf="$mydir/mediaprep.conf"
# Same for the logfile. Let's stick that into the same directory for now.
mediapreplog="$mydir/mediaprep.log"

# Colours... oooh pretty!
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
normal=$(tput sgr0)
bright=$(tput bold)

#####
# General functions
#####
exit_int() {
  # Function to do a clean exit when an interrupt is trapped
  printf "${red}Process aborted by user${normal}\n"
  clean_tmpfiles
  break # break out of the loop
  exit 0
}

exit_term() {
  # Function to do a clean exit when a termination is trapped
  echo "${red}Process terminated${normal}"
  clean_tmpfiles
  break # break out of the loop
  exit 1
}

do_error() {
  printf "[${red}ERR${normal}]\n"
  breakloop="YES"
}

#####
# Menu functions
#####
menulogo() {
	# Clear screen en print 'logo'
	clear
	printf "${blue}${bright}#     #                                 ######\n"
	printf "##   ##  ######  #####      #      ##   #     #  #####   ######  #####\n"
	printf "# # # #  #       #    #     #     #  #  #     #  #    #  #       #    #\n"
	printf "#  #  #  #####   #    #     #    #    # ######   #    #  #####   #    #\n"
	printf "#     #  #       #    #     #    ###### #        #####   #       #####\n"
	printf "#     #  #       #    #     #    #    # #        #   #   #       #\n"
	printf "#     #  ######  #####      #    #    # #        #    #  ######  #\n"
	printf "\n         Create transcoded MKVs from raw video files${normal}\n\n"
}

#####
# Job file functions
#####
create_jobs() {
	# All functions needed to create jobs go here
}


#####
# Processing functions
#####
process_jobs() {
	# All functions to process jobs go here
	count_jobs
}
count_jobs() {
	jobcount=$(ls $queuedir/*.job)
	if [[ "$jobcount" -eq 0 ]]; then
		message="No jobs in the queue found."; type="err"; stop="yes"
		return_output
	fi
}


#####
# Misc functions
#####
sourceconfig() {
	# Source the config file
	source $mediaprepconf
}
usage() {
	printf "Usage: $PROGNAME [options]\n\n"
	printf "Options:\n"
	printf " -b \t\t Batch operation. Process all job files.\n"
	printf " -j \t\t Create job files.\n"
	printf "If no options are given, $PROGNAME is always run interactively.\n"
}
return_output() {
	# This function can send a message to screen & logging or logging only
	if [[ "$output" = "yes" ]]; then
		if [[ "$type" = "err" ]]; then
			printf "[${red}ERR${normal}]\t"
		else
			printf "[${green}OK${normal}]\t"
		fi
		printf "$message\n"
	fi
	# We always log, so logging goes next
	## TODO look at some logging to come up with a nice format
	# Check if we need to stop the script now
	if [[ "$stop" = "yes" ]]; then
		exit 1
	fi
}

#####
# The script itself
#####

# Trap TERM, HUP, and INT signals and properly exit
trap exit_term TERM HUP
trap exit_int INT

# Dependency check
my_needed_commands="HandBrakeCLI mkvmerge mkvmerge fromdos"
missing_counter=0
for needed_command in $my_needed_commands
do
  if ! hash "$needed_command" >/dev/null 2>&1; then
  printf "Command not found in PATH: %s\n" "$needed_command" >&2
  ((missing_counter++))
  fi
done
if ((missing_counter > 0)); then
  printf "Minimum %d commands are missing in PATH, aborting\n" "$missing_counter" >&2
  exit 1
fi

# Required directory check
my_needed_dirs="$queuedir $tempdir $readydir $trashdir"
for needed_dir in $my_needed_dirs
do
	if [[ ! -d "$needed_dir" ]]; then
		# Dir not found, creating it!
		mkdir -p $needed_dir
		if [[ "$?" -gt 0 ]]; then
			printf "Directory not found and unable to create it: $needed_dir\n"
			printf "Aborting."
			exit 1
		fi
	fi
done

# Process depending on options
while getopts "bjh" opt; do
    case $opt in
        b  )  output="no"; process_jobs; exit 0 ;;
        j  )  output="yes"; create_jobs; exit 0 ;;
        h  )  usage; exit 0 ;;
        *  )  printf "Unimplimented option: -$OPTARG" >&2; exit 1;;
    esac
done

# Start of interactive section of the script
output="yes"
menulogo


#####
# END
#####