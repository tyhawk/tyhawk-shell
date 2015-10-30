#!/bin/bash
##############################################################################
# Convert Trailers - convert trailers to Matroska and move them into position
##############################################################################

# Variables
rootdir="$HOME/TransFusion"
trailerdir="$rootdir/GameTrailers"
tmpdir="/tmp"
finisheddir="/mnt/HomeVideos/GameTrailers"
dumpsterdir="$rootdir/99_Dumpster"
logfile="$HOME/trailerconvert.log"

# Functions
msgtolog() {
	printf "$(date +"%b %d %H:%M:%S") ${1}\n"  >> $logfile
}

cleanup_one() {
	if [[ -f "$hboutput" ]]; then
		msgtolog "Cleanup step: converted mp4 file"
		rm -f $hboutput
	fi
}

cleanup_two() {
        if [[ -f "$mkvfile" ]]; then
		msgtolog "Cleanup step: dirty mkv file"
                rm -f $mkvfile
        fi
}

cleanup_three() {
        if [[ -f "$mkvfileclean" ]]; then
                msgtolog "Cleanup step: clean mkv file"
                rm -f $mkvfileclean
        fi
}

cleanup_four() {
	msgtolog "Moving file $trailer to $dumpsterdir"
	mv "$trailerfile" "$dumpsterdir"
	if [[ "$?" -eq 0 ]]; then
		msgtolog "Moving OK"
	else
		msgtolog "Moving FAILED"
		exit 1
	fi
}

extract_info() {
	trailer=$( basename "$trailerfile" | sed 's/\.[^.]*$//' )
	# Extract info from filename
	msgtolog "Start processing of $trailer"
        trailername=$(echo "$trailer" | cut --delimiter=\- --fields=1)
        traileryear=$(echo "$trailer" | cut --delimiter=\- --fields=2)
	# And the name of the fully processed file
	trailerdone="$trailername-($traileryear).mkv"
}

transcode_file() {
	# Set input and output
	hbinput="$trailerfile"
	hboutput="$tmpdir/gametrailer_tmp.mp4"
	# Transcode the trailer
	msgtolog "Start conversion"
	HandBrakeCLI --input $hbinput --output $hboutput --verbose="0" --optimize \
		--x264-preset="faster" --encoder x264 --x264-tune film --quality 20 --rate 25 --cfr \
		--audio 1 --aencoder av_aac --ab 160 --mixdown stereo \
		--maxWidth 1920 --maxHeight 1080 --loose-anamorphic --decomb="default" --deblock 2&1> /dev/null
	if [[ "$?" -eq 0 ]]; then
		msgtolog "Conversion OK"
	else
		msgtolog "Conversion FAILED"
		exit 1
	fi
}

merge_file() {
	# Convert to Matroska
	mkvfile="$tmpdir/gametrailer_tmp.mkv"
	msgtolog "Start merging"
	mkvmerge --quiet --output $mkvfile --language 0:eng --default-track 0 --language 1:eng --default-track 1 $hboutput
	if [[ "$?" -eq 0 ]]; then
		msgtolog "Merging OK"
		# Delete the converted file
		cleanup_one
	else
		msgtolog "Merging FAILED"
		cleanup_one
		exit 1
	fi
}

optimize_file() {
	# Optimize & clean the file
	mkvfileclean="$tmpdir/$trailerdone"
	msgtolog "Start optimize and clean"
	mkclean --optimize --keep-cues "$mkvfile" "$mkvfileclean"
	if [[ "$?" -eq 0 ]]; then
		msgtolog "Optimize and clean OK"
		# Delete the mkv file
		cleanup_two
	else
		msgtolog "Optimize and clean FAILED"
		cleanup_two
		exit 1
	fi
}

transfer_file() {
	# Rsync the file to the fileserver
	msgtolog "Start transfer of file $trailerdone"
	rsync --perms --times --quiet --remove-source-files --partial "$mkvfileclean" "$finisheddir"
	if [[ "$?" -gt 0 ]]; then
		msgtolog "Transfer OK"
		cleanup_three
	else
		msgtolog "Transfer FAILED"
		cleanup_three
		exit 1
	fi
	cleanup_four
}

# Colours... oooh pretty!
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
normal=$(tput sgr0)
bright=$(tput bold)

# Dependency check
my_needed_commands="HandBrakeCLI mkvmerge mkclean rsync"

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

# Start my job
clear
filestodo=( $(find $trailerdir/ -type f | sort -u) )
filestodocount="${#filestodo[@]}"
if [[ "$filestodocount" -eq 0 ]]; then
  printf " none\n"
  exit 0
fi

# Process the queue one by one
for trailerfile in "${filestodo[@]}"
do
	msgtolog "==== Starting file ===="
	extract_info
	transcode_file
	merge_file
	optimize_file
	transfer_file
	msgtolog "==== Finished file ===="
done

# DONE!
exit 0
