#!/bin/bash
#############################################################################
# tvprep - the one-go TV Show File Preparer
# (c) 2014 John Gerritse
#
# Create a fully transcoded MKV file of TV episodes in one script
#
# Directory Structure:
# 01_Preparation    - Raw files ready to be checked and prepared
# 02_Transcode      - Properly named files ready for transcoding
# 03_Subtitles      - Checked UTF-8 subtitle files
# 04_MKVready       - Transcoded files ready to become MKV's
# 05_toStaging      - Completed MKV files, ready for upload to Staging
# 99_RawMaterials   - Raw files ready for removal
#
# TV File syntax:   some.tv.show-s01e09-Name_of_the_Episode.ext
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
BLUE=$(tput setaf 4)
NORMAL=$(tput sgr0)
BRIGHT=$(tput bold)

# Where we copy finished results
fileserver="192.168.178.50"

# Start!
clear
printf "${BLUE}${BRIGHT}  #####  #    #  #####   #####   ######  #####\n"
printf "    #    #    #  #    #  #    #  #       #    #\n"
printf "    #    #    #  #    #  #    #  #####   #    #\n"
printf "    #    #    #  #####   #####   #       #####\n"
printf "    #     #  #   #       #   #   #       #\n"
printf "    #      ##    #       #    #  ######  #\n"
printf "\n   Create transcoded MKVs from raw video files\n${NORMAL}\n"

# first check for files lingering in the 05_toStaging folder and rsync those first to regain disk space
uploadfile=( $(find $staging/ -type f -name '*-s??e??-*.mkv' -exec basename {} \;) )
uploadfilecount="${#uploadfile[@]}"
if [[ "$uploadfilecount" -gt 0 ]]; then
    if [[ "$uploadfilecount" -eq 1 ]]; then
        printf "Detecting 1 file ready for upload.\n"
    else
        printf "Detecting $uploadfilecount files ready for upload.\n"
    fi
    printf " Server $fileserver reachable: "
    ping -c 1 $fileserver >/dev/null 2>&1
    if [[ "$?" -eq 0 ]]; then
        printf "[${GREEN}OK${NORMAL}]\n"
        for mkvfile in "${uploadfile[@]}"
        do
            printf " Moving file $mkvfile to Staging directory on server:\n"
        rsync --update --perms --times --progress --human-readable --compress --remove-source-files --partial $staging/$mkvfile $fileserver:~/Staging/
            if [[ "$?" -gt 0 ]]; then
                printf " Transfer completed: [${RED}ERR${NORMAL}]\n"
                # Break from the loop / do not continue with next steps for this file (I hope)
                continue
            else
                printf " Transfer completed: [${GREEN}OK${NORMAL}]\n"
            fi
        done
        printf "\n"
    else
        printf "[${RED}ERR${NORMAL}]\n\n"
    fi
fi

# Check for files ready for processing
printf "Number of files ready for processing... "
filestodo=( $(find $transcode/ -type f -name '*-s??e??-*.*' -exec basename {} \; | sort) )
filestodocount="${#filestodo[@]}"
printf "$filestodocount\n"
if [[ "$filestodocount" -eq 0 ]]; then
    printf "Nothing to do.\nStopping.\n"
    exit 0
else
    printf "\n" #print an empty line
fi

# Work on all files one by one
for showfile in "${filestodo[@]}"
do
    # First extract data from the filename
    suffix=$(echo "$showfile" | cut --delimiter=\- --fields=3 | cut --delimiter=\. --fields=2)
    tvshowfile=$(basename --suffix=".$suffix" $showfile)
    tvshowname=$(echo "$tvshowfile" | cut --delimiter=\- --fields=1)
    tvshowepisode=$(echo "$tvshowfile" | cut --delimiter=\- --fields=2)
    tvshowepname=$(echo "$tvshowfile" | cut --delimiter=\- --fields=3)
    showname="${tvshowname//./ }"
    season="$((10#${tvshowepisode:1:2}))"
    episode="$((10#${tvshowepisode:4:2}))"
    eptitle="${tvshowepname//_/ }"
    title="$showname - Season $season Episode $episode - $eptitle"
    printf "Found \"${BRIGHT}$title${NORMAL}\"\n"
    printf "Starting processing of file $tvshowfile.\n"
    ### STEP 1 ###
    printf "Step 1. Transcoding to x264.\n"
    hbinfile="$transcode/$showfile"
    hboutfile="$mkvready/$tvshowfile.mp4"
    HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize --x264-preset="veryfast" --encoder x264 --x264-tune film --quality 20 --rate 25 --cfr --audio 1 --aencoder faac --ab 160 --mixdown stereo --maxWidth 1024 --loose-anamorphic --deinterlace="fast" --deblock 2> /dev/null
    if [[ "$?" -eq 0 ]]; then
        printf " Transcoding result: [${GREEN}OK${NORMAL}]\n"
    else
        printf " Transcoding result: [${RED}ERR${NORMAL}]\n"
        if [[ -e "$hboutfile" ]]; then
            printf " Removing failed result file $(basename $hboutfile): "
            trap 'printf "[${RED}ERR${NORMAL}]\n"' 1
            rm -f $hboutfile && printf "[${GREEN}OK${NORMAL}]\n"
        fi
        # Break from the loop / do not continue with next steps for this file (I hope)
        continue
    fi
    videofile="$hboutfile" # Define for MKVmerge
    ### STEP 2 ###
    printf "Step 2. Checking the subtitle file.\n"
    subtype="unknown" # Needed to escape the loop if there is no file
    subfile="$subtitles/$tvshowfile"
    # Add code to catch Dutch TV shows (no subtitles!)
    if [[ -e "$subfile.srt" ]]; then
        printf " Subtitle file (SubRip) found: [${GREEN}OK${NORMAL}]\n"
        subtype="srt"
    fi
    if [[ -e "$subfile.ass" ]]; then
        printf " Subtitle file (Advanced Substation Alpha) found: [${GREEN}OK${NORMAL}]\n"
        subtype="ass"
    fi
    if [[ "$subtype" = "srt" ]] || [[ "$subtype" = "ass" ]]; then
        charcode=$(file $subfile.$subtype | awk '{ print $2 }')   
        if [[ "$charcode" = "assembler" ]]; then   # to catch "assembler source, UTF-8 Unicode (with BOM) text"
            charcode=$(file $subfile.$subtype | awk '{ print $4 }')
        fi
        if [[ "$charcode" = "Pascal" ]]; then   # to catch "Pascal source, UTF-8 Unicode (with BOM) text"
            charcode=$(file $subfile.$subtype | awk '{ print $4 }')
        fi
        if [[ "$charcode" = "UTF-8" ]]; then
            printf " Subtitle file encoding: $charcode [${GREEN}OK${NORMAL}]\n"
            subtitlefile="$subfile.$subtype"  # Define for MKVmerge
        else
            printf " Subtitle file encoding: $charcode [${RED}ERR${NORMAL}]\n"
            printf " Renaming file to $tvshowfile-$charcode.$subtype: "
            trap 'printf "[${RED}ERR${NORMAL}]\n"' 1
            mv $subfile.$subtype $subfile-$charcode.$subtype && printf "[${GREEN}OK${NORMAL}]\n"
        fi
    else
        printf " Subtitle file not found: [${RED}ERR${NORMAL}]\n"
        # Break from the loop / do not continue with next steps for this file (I hope)
        continue 
    fi
    ### Step 3 ###
    printf "Step 3. Creating the MKV file.\n"
    mkvfile="$staging/$tvshowfile.mkv"
    # Add code to catch Dutch TV shows (Different MKVmerge required and no subs)
    # Stick all Dutch shows in an array and loop through the array to see if there is a match
    printf " Merging $(basename $videofile) and $(basename $subtitlefile) into $(basename $mkvfile): "
    trap 'printf "[${RED}ERR${NORMAL}]\n"' 1
    mkvmerge --quiet --output $mkvfile --title "$title" \
        --language 0:eng --default-track 0 --language 1:eng --default-track 1 $videofile \
        --language 0:dut --default-track 0 --sub-charset 0:UTF-8 $subtitlefile && printf "[${GREEN}OK${NORMAL}]\n"
    ### Step 4 ###
    printf "Step 4. Copy the mkv file to fileserver.\n"
    printf " Server $fileserver reachable: "
    ping -c 1 $fileserver >/dev/null 2>&1
    if [[ "$?" -eq 0 ]]; then
        printf "[${GREEN}OK${NORMAL}]\n"
        printf " Moving file $(basename $mkvfile) to Staging directory on server:\n"
        rsync --perms --times --progress --human-readable --compress --remove-source-files --partial $mkvfile $fileserver:~/Staging/
        if [[ "$?" -gt 0 ]]; then
            printf " Transfer completed: [${RED}ERR${NORMAL}]\n"
            # Break from the loop / do not continue with next steps for this file (I hope)
            continue
        else
            printf " Transfer completed: [${GREEN}OK${NORMAL}]\n"
        fi
    else
        printf "[${RED}ERR${NORMAL}]\n"
    fi
    ### Step 5 ###
    printf "Step 5. Moving processed files to the raw materials folder.\n"
    printf " Moving raw video file $(basename $hbinfile) to $dumpster: "
    trap 'printf "[${RED}ERR${NORMAL}]\n"' 1
    mv $hbinfile $dumpster && printf "[${GREEN}OK${NORMAL}]\n"
    printf " Moving subtitle file $(basename $subtitlefile) to $dumpster: "
    trap 'printf "[${RED}ERR${NORMAL}]\n"' 1
    mv $subtitlefile $dumpster && printf "[${GREEN}OK${NORMAL}]\n"
    printf " Deleting transcoded file $(basename $hboutfile): "
    trap 'printf "[${RED}ERR${NORMAL}]\n"' 1
    rm -f $hboutfile && printf "[${GREEN}OK${NORMAL}]\n"
    printf "File $showfile completed [${GREEN}OK${NORMAL}]\n\n"
done
# end script
