#!/bin/bash
#############################################################################
# mediaprep - the One-Stop TV Show & Movie File Preparer & Uploader
#             (not named OSTVSMFPU because mediaprep is easier to remember)
# (c) 2014 John Gerritse
#
# Create a fully transcoded MKV file of TV episodes & Movies in one script
#
# Directory Structure:
# 01_Preparation    - Raw files ready to be checked and prepared
# 02_Transcode      - Properly named files ready for transcoding
# 03_Subtitles      - Checked UTF-8 subtitle files
# 04_MKVready       - Transcoded files ready to become MKV's
# 05_toStaging      - Completed MKV files, ready for upload to Staging
# 99_RawMaterials   - Raw files ready for removal
#
# TV file syntax:       some.tv.show-s01e09-Name_of_the_Episode.ext
# Movie file syntax:    some.movie.name-2014.ext
#############################################################################

# Variables
rootdir="$HOME/Videos/XBMC"
transcode="$rootdir/02_Transcode"
subtitles="$rootdir/03_Subtitles"
mkvready="$rootdir/04_MKVready"
staging="$rootdir/05_toStaging"
dumpster="$rootdir/99_RawMaterials"

# Colours... oooh pretty!
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NORMAL=$(tput sgr0)
BRIGHT=$(tput bold)

# Where we copy finished results
fileserver="192.168.178.50"

# TV shows that have no subs
tvnosubs=( "Moordvrouw" "Smeris" "Toren.C" "Divorce" "de.Man.met.de.Hamer" "Celblok.H" )
# Animation TV shows (hand-drawn content)
tvanimation=( "Tom.and.Jerry" "Looney.Tunes" )

####
# Functions
####
exit_int() {
    # Function to do a clean exit when an interrupt is trapped
    printf "${RED}Process aborted by user${NORMAL}\n"
    cleanup
    exit 0
}

exit_term() {
    # Function to do a clean exit when a termination is trapped
    echo "${RED}Process terminated${NORMAL}"
    cleanup
    exit 1
}

do_error() {
    printf "[${RED}ERR${NORMAL}]\n"
    breakloop="YES"
}

do_ok() {
    printf "[${GREEN}OK${NORMAL}]\n"
}

transcode_result() {
    if [[ "$?" -eq 0 ]]; then
        printf "  Transcoding result: "; do_ok
    else
        printf "  Transcoding result: "; do_error
        printf "  Removing transcoded file: "
        trap do_error 1
        rm -f $hboutfile && do_ok
    fi
}

clean_subs() {
    ressubs=( $(find $subtitles/ -type f -exec basename {} \;) )
    printf " Checking for files in $subtitles: "
    if [[ "${#ressubs[@]}" -gt 0 ]]; then
        printf "[${RED}FOUND${NORMAL}]\n"
        for resfile in "${ressubs[@]}"
        do
            printf " Removing file $resfile: "
            trap do_error 1
            rm -f "$subtitles/$resfile" && do_ok
        done
    else
        printf "[${GREEN}CLEAN${NORMAL}]\n"
    fi
}

clean_transcode() {
    restrans=( $(find $mkvready/ -type f -exec basename {} \;) )
    printf " Checking for files in $mkvready... "
    if [[ "${#restrans[@]}" -gt 0 ]]; then
        printf "[${YELLOW}FOUND${NORMAL}]\n"
        for resfile in "${restrans[@]}"
        do
            printf " Removing file $resfile: "
            trap do_error 1
            rm -f "$subtitles/$resfile" && do_ok
        done
    else
        printf "[${GREEN}CLEAN${NORMAL}]\n"
    fi
}

cleanup() {
    printf " Cleaning up temporary files.\n"
    clean_subs
    clean_transcode
}

cleanup_quick() {
    # Quick, dirty & efficient cleanup
    printf "  Removing obsolete video file: "
    trap do_error 1
    rm -f $videofile && do_ok
    printf "  Removing obsolete subtitle file: "
    trap do_error 1
    rm -f $subtitlefile && do_ok
    breakloop="NO" # if this fails, no need to discontinue
}

breaktheloop() {
    if [[ "$breakloop" = "YES" ]]; then
        # We move onto the next entry in the loop
        printf "Processing of \"${BRIGHT}$title${NORMAL}\" [${RED}FAILED${NORMAL}]\n"
        printf "Step $step [${RED}FAILED${NORMAL}]\n"
        continue
    fi
}

####
# The script itself
####

# Trap TERM, HUP, and INT signals and properly exit
trap exit_term TERM HUP
trap exit_int INT

# Dependency check
hash HandBrakeCLI 2>/dev/null || { printf "Could not find handbrake-cli.\nPlease make sure it is installed.\nAborting ..." >&2; exit 1; }
hash mkvmerge 2>/dev/null || { printf "Could not find mkvmerge.\nPlease make sure it is installed.\nAborting ..." >&2; exit 1; }
hash rsync 2>/dev/null || { printf "Could not find rsync.\nPlease make sure it is installed.\nAborting ..." >&2; exit 1; }

# Clear screen en print 'logo'
clear
printf "${BLUE}${BRIGHT}#     #                                 ######\n"
printf "##   ##  ######  #####      #      ##   #     #  #####   ######  #####\n"
printf "# # # #  #       #    #     #     #  #  #     #  #    #  #       #    #\n"
printf "#  #  #  #####   #    #     #    #    # ######   #    #  #####   #    #\n"
printf "#     #  #       #    #     #    ###### #        #####   #       #####\n"
printf "#     #  #       #    #     #    #    # #        #   #   #       #\n"
printf "#     #  ######  #####      #    #    # #        #    #  ######  #\n"
printf "\n   Create transcoded MKVs from raw video files${NORMAL}\n"

# Next, clean out any files from directories that should be empty
printf "\n${YELLOW}Residual file check.${NORMAL}\n"
clean_subs
clean_transcode

# check for files lingering in the 05_toStaging folder and rsync those first to regain disk space
printf "\n${YELLOW}Staging directory check.${NORMAL}\n"
uploadfile=( $(find $staging/ -type f -name '*.mkv' -exec basename {} \;) )
uploadfilecount="${#uploadfile[@]}"
if [[ "$uploadfilecount" -gt 0 ]]; then
    if [[ "$uploadfilecount" -eq 1 ]]; then
        printf " Detecting 1 file ready for upload.\n"
    else
        printf " Detecting $uploadfilecount files ready for upload.\n"
    fi
    printf " Server $fileserver reachable: "
    ping -c 1 $fileserver >/dev/null 2>&1
    if [[ "$?" -eq 0 ]]; then
        do_ok
        for mkvfile in "${uploadfile[@]}"
        do
            printf " Moving file $mkvfile to Staging directory on server:\n"
            rsync --update --perms --times --progress --human-readable --compress --remove-source-files --partial $staging/$mkvfile $fileserver:~/Staging/
            if [[ "$?" -gt 0 ]]; then
                printf " Transfer completed: "; do_error
                # Break from the loop / do not continue with next steps for this file (I hope)
                continue
            else
                printf " Transfer completed: "; do_ok
            fi
        done
    else
        do_error
    fi
else
    printf " No files found. "; do_ok
fi

# Check for files ready for processing
printf "\n${YELLOW}Processable files check.${NORMAL}\n"
printf " Number of files ready for processing: "
filestodo=( $(find $transcode/ -type f -exec basename {} \; | sed 's/\.[^.]*$//' | sort -u) )
filestodocount="${#filestodo[@]}"
printf "$filestodocount\n"
if [[ "$filestodocount" -eq 0 ]]; then
    printf " Nothing to do.\nStopping.\n"
    exit 0
fi

# We have a list of files. Let's start processing them
for mediafile in "${filestodo[@]}"
do
    mediatype="" # to make sure we start with an empty mediatype
    subsneeded="YES" # We always need subs, unless exceptions are found
    animation="NO" # We always transcode film, unless exceptions are found
    breakloop="NO" # We use this to break from the loop after a step if we need to
    # Determine movie or tv show
    step="0. Title"
    if [[ -n $(find $transcode/ -name '*-s??e??-*' | grep "$mediafile") ]]; then
        mediatype="TV"
        # Extract info from filename
        showname_raw=$(echo "$mediafile" | cut --delimiter=\- --fields=1)
        showepnum=$(echo "$mediafile" | cut --delimiter=\- --fields=2)
        showepname=$(echo "$mediafile" | cut --delimiter=\- --fields=3-)
        # Prettify text for nicer output
        showname="${showname_raw//./ }"
        season="$((10#${showepnum:1:2}))"
        episode="$((10#${showepnum:4:2}))"
        eptitle="${showepname//_/ }"
        # Setting the title
        title="$showname - Season $season Episode $episode - $eptitle"
    elif [[ -n $(find $transcode/ -name "*-????.*" | grep "$mediafile") ]]; then
        mediatype="Movie"
        # Extract info from filename
        moviename_raw=$(echo "$mediafile" | cut --delimiter=\- --fields=1)
        movieyear=$(echo "$mediafile" | cut --delimiter=\- --fields=2)
        # Prettify text for nicer output
        moviename="${moviename_raw//./ }"
        # Setting the title
        title="$moviename ($movieyear)"
    fi
    # If mediatype is still empty, we cannot process the file.
    if [[ -z "$mediatype" ]]; then
        # Moving onto the next file
        printf "Skipping fileset ${RED}$mediafile${NORMAL}\n"
        breakloop="YES"
    else
        # Announcing processing
        printf "\n\nStarting processing of \"${BRIGHT}$title${NORMAL}\"\n"
    fi
    #################################
    #### STEP 1 - Check subtitle ####
    #################################
    step="1. Subtitle"
    # First check if we need a subtitle (not for Dutch shows)
    if [[ "$mediatype" = "TV" ]]; then
        for dutchshow in "${tvnosubs[@]}"; do [[ "$dutchshow" = "$showname_raw" ]] && subsneeded="NO"; done
    fi
    # Announce step 1
    printf " ${YELLOW}Step 1${NORMAL} - Processing subtitle.\n"
    # If we do need subs, we will check them
    if [[ "$subsneeded" = "YES" ]]; then
        # Determine if this is an Advanced Substation Alpha subtitle or SRT
        if [[ -e $transcode/$mediafile.ass ]]; then
            subext="ssa"
            subformat="Advanced Substation Alpha"
        elif [[ -e $transcode/$mediafile.srt ]]; then
            subext="srt"
            subformat="SubRip"
        else
            printf "  Subtitle file not found: " ; do_error
        fi
        # Check if it is UTF-8 encoded. Extra check in case there was no subtitle file
        subtitle_raw="$transcode/$mediafile.$subext"
        if [[ -e "$subtitle_raw" ]]; then
            printf "  Subtitle type ($subformat): "; do_ok
            subcharset=$(file -ib $subtitle_raw | awk '{ print $2 }' | cut --delimiter=\= --fields=2)
        fi
        if [[ "$subcharset" = "utf-8" ]]; then
            printf "  Subtitle charset (UTF-8): "; do_ok
            subtitlefile="$subtitles/$mediafile.$subext"
            printf "  Placing approved subtitle file: "
            trap do_error 1
            cp $subtitle_raw $subtitlefile && do_ok
        else
            printf "  Subtitle charset ($subcharset): "; do_error
        fi
    else
        printf "  No subtitles required for $mediafile: " ; do_ok
    fi
    breaktheloop
    #################################
    #### STEP 2 - Transcode file ####
    #################################
    step="2. Transcode"
    # Announce step 2
    printf " ${YELLOW}Step 2${NORMAL} - Transcoding video.\n"
    # Set input file & output file
    hbinfile=$(find $transcode/ -name "$mediafile.*" -type f | grep -Ev "ass|srt")
    hboutfile="$mkvready/$mediafile.mp4"
    # Transcode depending on certain file properties
    if [[ "$mediatype" = "Movie" ]]; then
        # It's a movie! Let's transcode it!
        HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
            --x264-preset="veryfast" --encoder x264 --x264-tune film \
            --quality 20 --rate 25 --cfr \
            --audio 1 --aencoder faac --ab 160 --mixdown stereo \
            --maxWidth 1280 --maxHeight 720 --loose-anamorphic \
            --deinterlace="fast" 2> /dev/null
        transcode_result
    elif [[ "$mediatype" = "TV" ]]; then
        # First we check if this is a known animation TV show
        for cartoon in "${tvanimation[@]}"; do [[ "$cartoon" = "$showname_raw" ]] && animation="YES"; done
        if [[ "$animation" = "YES" ]]; then
            # Its an animated TV show! Let's transcode it!
            HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
                --x264-preset="veryfast" --encoder x264 --x264-tune animation \
                --quality 20 --rate 25 --cfr \
                --audio 1 --aencoder faac --ab 160 --mixdown stereo \
                --maxWidth 1024 --loose-anamorphic \
                --deinterlace="fast" --deblock 2> /dev/null
        transcode_result
            transcode_result
        elif [[ "$animation" = "NO" ]]; then
            # It's a regular TV Show! Let's transcode it!
            HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
                --x264-preset="veryfast" --encoder x264 --x264-tune film \
                --quality 20 --rate 25 --cfr \
                --audio 1 --aencoder faac --ab 160 --mixdown stereo \
                --maxWidth 1024 --loose-anamorphic \
                --deinterlace="fast" --deblock 2> /dev/null
            transcode_result
        else
            # Not Movie and TV Show and not animated. This *should* never happen.
            printf "  Transcoding failed (never started): "; do_error
        fi
    fi
    videofile="$hboutfile"
    breaktheloop
    #############################
    #### STEP 3 - Merge file ####
    #############################
    step="3. Merging"
    # Announce step 3
    printf " ${YELLOW}Step 3${NORMAL} - Merging video and subtitle.\n"
    mkvfile="$staging/$mediafile.mkv"
    # Make sure all files required are present
    if [[ "$subsneeded" = "YES" ]]; then
        printf "  Subtitle file present: "
        if [[ -e "$subtitlefile" ]]; then
            do_ok
        else
            do_error
        fi
    fi
    printf "  Video file present: "
    if [[ -e "$videofile" ]]; then
        do_ok
    else
        do_error
    fi
    breaktheloop
    # All files here, we are good to go!
    if [[ "$subsneeded" = "NO" ]]; then
        printf "  Merging video: "
        trap do_error 1
        mkvmerge --quiet --output $mkvfile --title "$title" \
            --language 0:dut --default-track 0 --language 1:dut --default-track 1 $videofile
        cleanup_quick
    else
        printf "  Merging video and subtitles: "
        trap do_error 1
        mkvmerge --quiet --output $mkvfile --title "$title" \
            --language 0:eng --default-track 0 --language 1:eng --default-track 1 $videofile \
            --language 0:dut --default-track 0 --sub-charset 0:UTF-8 $subtitlefile && do_ok
        cleanup_quick
    fi
    breaktheloop
    ##############################
    #### STEP 4 - Upload file ####
    ##############################
    step="4. Uploading"
    # Announce step 4
    printf " ${YELLOW}Step 4${NORMAL} - Uploading the Matroska file.\n"
    printf "  Server $fileserver reachable: "
    ping -c 1 $fileserver >/dev/null 2>&1
    if [[ "$?" -eq 0 ]]; then
        do_ok
        printf "  Moving file $(basename $mkvfile) to staging directory on server:\n"
        rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $mkvfile $fileserver:~/Staging/
        if [[ "$?" -gt 0 ]]; then
            printf "  Transfer completed: "; do_error
        else
            printf "  Transfer completed: "; do_ok
        fi
    else
        do_error
    fi
    breakloop="NO" # No reason to break the loop if uploading fails
    breaktheloop
    #######################################
    #### STEP 5 - Move processed files ####
    #######################################
    step="5. Finishing"
    # Announce step 4
    printf " ${YELLOW}Step 5${NORMAL} - Moving processed files to finished folder.\n"
    printf "  Moving raw video file $(basename $hbinfile) to $dumpster: "
    trap do_error 1
    mv $hbinfile $dumpster && do_ok
    if [[ "$subsneeded" = "YES" ]]; then
        printf "  Moving subtitle file $(basename $subtitle_raw) to $dumpster: "
        trap do_error 1
        mv $subtitle_raw $dumpster && do_ok
    fi
    breaktheloop
done
#
# End Script
