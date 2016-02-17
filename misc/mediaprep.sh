#!/bin/bash
#############################################################################
# mediaprep - the One-Stop TV Show & Movie File Preparer & Uploader
#             (not named OSTVSMFPU because mediaprep is easier to remember)
# © 2014 John Gerritse
#
# Create a fully transcoded MKV file of TV episodes & Movies in one script
#
# Directory Structure:
# 01_Queue        - Properly named files ready for transcoding
# 02_TempFiles    - Temporary files for transcoding
# 03_Finished     - Completed MKV files, ready for upload to server
# 99_Dumpster     - Processed queue files ready for removal
#
# TV file syntax:     some.tv.show-s01e09-Name_of_the_Episode.ext
# Movie file syntax:  some.movie.name-2014.ext (input syntax))
#############################################################################
# Install on your system - TODO not implemented yet!!!
# You can place it anywhere, even in /usr/local/bin.
# If you do, make sure the config file is in /usr/local/etc.
#############################################################################
# TODO
# Add flags:  -f  Full processing (the default)
#             -t  Transcode only. Do not mkvmerge
#             -m  Mkvmerge only. Do not transcode
#             -a  Set foreign audio language (override default)
#             -s  Set subtitle language (override default)
#
# Add option:   mediaprep.sh [FLAG] [FILENAME]
#               Process single file only
#
# Move certain stuff into a conf file
# Multiple subtitles (check which language they are by filename)
# Use of functions to reduce code
# Overall code improvements
#
# Rewrite to Python 3 (if I ever have time to actually learn Python)

# Variables
rootdir="$HOME/TransFusion"
queue="$rootdir/01_Queue"
tmpfiles="$rootdir/02_TempFiles"
finished="$rootdir/03_Finished"
dumpster="$rootdir/99_Dumpster"
#scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#etcdir="$()" # same as scriptdir, but ../etc

# Colours... oooh pretty!
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
normal=$(tput sgr0)
bright=$(tput bold)

# TV shows that have no subs
tvnosubs=( "Home.Videos" "Moordvrouw" "Smeris" "Toren.C" "Divorce" "de.Man.met.de.Hamer" "Celblok.H" "Komt.Een.Man.Bij.De.Dokter" "My.Cat.From.Hell" "Witchblade" "Tom.and.Jerry" "Looney.Tunes" "Nieuwe.Buren" "Het.Zandkasteel" "Bluf" "Gooische.Vrouwen" "S1ngle" "Dokter.Tinus" "Penoza" "Baantjer" "Vrienden.Voor.Het.Leven" "Wie.Is.De.Mol" "Swiebertje" "Missie.Aarde" "Danni.Lowinski.NL" "Familie.Kruys" "Zwarte.Tulp" "Voetbalvrouwen" "Draadstaal" "Zie.Ze.Vliegen" "the.Joy.of.Painting"
"MythBusters" "NOVA" "Het.Zonnetje.in.Huis" "Mr.Deity" "Overspel" "Raveleijn" "Tessa" "Vechtershart" "50.Jaar.van.Duin" "de.Fractie" "Flikken.Rotterdam" "Mindf.ck" )
# Animation TV shows (hand-drawn content)
tvanimation=( "Tom.and.Jerry" "Looney.Tunes" "Avatar.the.Legend.of.Korra" "Avatar.the.Last.Airbender" )
# TV Shows with English subs
tvengsubs=( "Farscape" "Andromeda" "Babylon.5" )
# Animated movies
animatedmovie=( "The.Rescuers" "The.Rescuers.Down.Under" "Peter.Pan" "The.Little.Mermaid" "The.Lion.King" "Tarzan.and.Jane" "Dumbo" "Aladdin" "Snow.White.And.The.Seven.Dwarfs" "Bambi" "Beauty.and.the.Beast" "Titan.A.E" "Brother.Bear" "Pinocchio" "Bambi.II" "Brother.Bear.2" "Atlantis.The.Lost.Empire" "Hercules" "Mulan" "Piglets.Big.Movie" "Lilo.and.Stitch" "Pocahontas" "Poohs.Heffalump.Movie" "The.Princess.and.the.Frog" "Winnie.the.Pooh" "Akira" "the.Jungle.Book" "The.Chronicles.of.Riddick.Dark.Fury" )
####
# Functions
####
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

do_ok() {
  printf "[${green}OK${normal}]\n"
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

clean_tmpfiles() {
  stalefiles=( $(find $tmpfiles/ -type f -exec basename {} \;) )
  printf " Checking for files in $tmpfiles: "
  if [[ "${#stalefiles[@]}" -gt 0 ]]; then
    printf "[${red}FOUND${normal}]\n"
    for resfile in "${stalefiles[@]}"
    do
      printf " Removing file $resfile: "
      trap do_error 1
      rm -f "$tmpfiles/$resfile" && do_ok
    done
  else
    printf "[${green}CLEAN${normal}]\n"
  fi
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
    printf "Processing of \"${bright}$title${normal}\" [${red}FAILED${normal}]\n"
    printf "Step $step [${red}FAILED${normal}]\n\n"
    continue
  fi
}

# File system check function
checkdir() {
  if [[ ! -d "$1" ]]; then
    printf "Directory $1 not found: "; do_error
    exit 1
  fi
}

####
# The script itself
####

# Trap TERM, HUP, and INT signals and properly exit
trap exit_term TERM HUP
trap exit_int INT

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

# Dependency check - more code then before, but much nicer
my_needed_commands="HandBrakeCLI mkvmerge mkclean fromdos"

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

# File system check
checkdir $rootdir
checkdir $queue
checkdir $tmpfiles
checkdir $finished
checkdir $dumpster

# Next, clean out any files from directories that should be empty
printf "\n${yellow}Residual file check.${normal}\n"
clean_tmpfiles

# Check for files ready for processing
printf "\n${yellow}Processable files check.${normal}\n"
printf " Number of files ready for processing: "
filestodo=( $(find $queue/ -type f -exec basename {} \; | sed 's/\.[^.]*$//' | sort -u) )
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
  title="$mediafile" # We set title to mediafile if process fails before setting the title
  subsneeded="YES" # We always need subs, unless exceptions are found
  animation="NO" # We always transcode film, unless exceptions are found
  breakloop="NO" # We use this to break from the loop after a step if we need to
  # Determine movie or tv show
  step="0. Title"
  if [[ -n $(find $queue/ -name '*-s??e??-*' | grep "$mediafile") ]]; then
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
  elif [[ -n $(find $queue/ -name '*-s????e??-*' | grep "$mediafile") ]]; then
    mediatype="TV"
    # Extract info from filename
    showname_raw=$(echo "$mediafile" | cut --delimiter=\- --fields=1)
    showepnum=$(echo "$mediafile" | cut --delimiter=\- --fields=2)
    showepname=$(echo "$mediafile" | cut --delimiter=\- --fields=3-)
    # Prettify text for nicer output
    showname="${showname_raw//./ }"
    season="$((10#${showepnum:1:4}))"
    episode="$((10#${showepnum:6:2}))"
    eptitle="${showepname//_/ }"
    # Setting the title
    title="$showname - Year $season Episode $episode - $eptitle"
  elif [[ -n $(find $queue/ -name "*-????.*" | grep "$mediafile") ]]; then
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
    printf "Skipping fileset ${red}$mediafile${normal}\n\n"
    breakloop="YES"
  else
    # Announcing processing
    printf "\n\n${yellow}Starting processing of${normal} \"${bright}$title${normal}\"\n"
  fi
  #################################
  #### STEP 1 - Check subtitle ####
  #################################
  step="1. Subtitle"
  # First check if we need a subtitle (mostly Dutch shows)
  if [[ "$mediatype" = "TV" ]]; then
    for dutchshow in "${tvnosubs[@]}"; do [[ "$dutchshow" = "$showname_raw" ]] && subsneeded="NO"; done
  fi
  # Announce step 1
  printf " ${yellow}Step 1${normal} - Processing subtitle.\n"
  # If we do need subs, we will check them
  if [[ "$subsneeded" = "YES" ]]; then
    # Determine if this is an Advanced Substation Alpha subtitle or SRT
    if [[ -e $queue/$mediafile.ass ]]; then
      subext="ass"
      subformat="Advanced Substation Alpha"
    elif [[ -e $queue/$mediafile.srt ]]; then
      subext="srt"
      subformat="SubRip"
    else
      # If media is a movie and there are no subs, its probably a Dutch movie
      if [[ "$mediatype" = "Movie" ]]; then
        printf "  Movie without subtitle file found: assuming this is a Dutch film.\n"
        subsneeded="NO"
      else
        # Not a movie & no subs found & not a show that requires no subs: ERROR!
        printf "  Subtitle file not found: " ; do_error
      fi
    fi
    breaktheloop
    # Will look into a better solution than an extra test on subsneeded
    if [[ "$subsneeded" = "YES" ]]; then
      # Check if it is UTF-8 encoded
      subtitle_raw="$queue/$mediafile.$subext"
      if [[ -e "$subtitle_raw" ]]; then
        printf "  Subtitle type ($subformat): "; do_ok
        subcharset=$(file -ib $subtitle_raw | awk '{ print $2 }' | cut --delimiter=\= --fields=2)
      fi
      # Get rid of Windows line terminators
      if [[ $(file $subtitle_raw | grep CRLF | wc -l) -gt 0 ]]; then
        printf "  Converting Windows line terminators to UNIX: "
        trap do_error 1
        fromdos $subtitle_raw && do_ok
      fi
      # Place the approved subtitle
      if [[ "$subcharset" = "utf-8" ]]; then
        printf "  Subtitle charset (UTF-8): "; do_ok
        subtitlefile="$tmpfiles/$mediafile.$subext"
        printf "  Placing approved subtitle file: "
        trap do_error 1
        cp $subtitle_raw $subtitlefile && do_ok
      else
        printf "  Subtitle charset ($subcharset): "; do_error
      fi
    else
      printf "  No subtitles required for $mediafile: " ; do_ok
    fi
  fi
  breaktheloop
  #################################
  #### STEP 2 - Transcode file ####
  #################################
  step="2. Transcode"
  # Announce step 2
  printf " ${yellow}Step 2${normal} - Transcoding video.\n"
  # Set input file & output file
  hbinfile=$(find $queue/ -name "$mediafile.*" -type f ! -name "*.$subext")
  hboutfile="$tmpfiles/$mediafile.mp4"
  # Transcode depending on certain file properties
  if [[ "$mediatype" = "Movie" ]]; then
    # It's a movie! Let's transcode it!
    # But first, let's check for animated movies
    for animatedmovie in "${movieanimation[@]}"; do [[ "$animatedmovie" = "$moviename_raw" ]] && animation="YES"; done
    if [[ "$animation" = "YES" ]]; then
        HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
        --x264-preset="faster" --encoder x264 --x264-tune animation \
        --quality 23 --rate 25 --cfr \
        --audio 1 --aencoder av_aac --ab 160 --mixdown stereo \
        --maxWidth 1280 --maxHeight 720 --loose-anamorphic \
        --decomb="default" 2> /dev/null
      transcode_result
    elif [[ "$animation" = "NO" ]]; then
      HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
        --x264-preset="faster" --encoder x264 --x264-tune film \
        --quality 23 --rate 25 --cfr \
        --audio 1 --aencoder av_aac --ab 160 --mixdown stereo \
        --maxWidth 1280 --maxHeight 720 --loose-anamorphic \
        --decomb="default" 2> /dev/null
      transcode_result
    fi
  elif [[ "$mediatype" = "TV" ]]; then
    hboutfile="$tmpfiles/$showname_raw-$showepnum.mp4"
    # First we check if this is a known animation TV show
    for cartoon in "${tvanimation[@]}"; do [[ "$cartoon" = "$showname_raw" ]] && animation="YES"; done
    if [[ "$animation" = "YES" ]]; then
      # Its an animated TV show! Let's transcode it!
      HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
        --x264-preset="faster" --encoder x264 --x264-tune animation \
        --quality 20 --rate 25 --cfr \
        --audio 1 --aencoder av_aac --ab 160 --mixdown stereo \
        --maxWidth 1024 --loose-anamorphic \
        --decomb="default" --deblock 2> /dev/null
      transcode_result
    elif [[ "$showname_raw" = "Cosmos.A.Space.Time.Odyssey" ]] || [[ "$showname_raw" = "Home.Videos" ]] || [[ "$showname_raw" = "Game.Trailers" ]]; then
      # I want to encode certain files at 720p
      HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
        --x264-preset="faster" --encoder x264 --x264-tune film \
        --quality 20 --rate 25 --cfr \
        --audio 1 --aencoder av_aac --ab 160 --mixdown stereo \
        --maxWidth 1280 --maxHeight 720 --loose-anamorphic \
        --decomb="default" --deblock 2> /dev/null
      transcode_result
    elif [[ "$animation" = "NO" ]]; then
      # It's a regular TV Show! Let's transcode it!
      HandBrakeCLI --input $hbinfile --output $hboutfile --verbose="0" --optimize \
        --x264-preset="faster" --encoder x264 --x264-tune film \
        --quality 20 --rate 25 --cfr \
        --audio 1 --aencoder av_aac --ab 160 --mixdown stereo \
        --maxWidth 1024 --loose-anamorphic \
        --decomb="default" --deblock 2> /dev/null
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
  printf " ${yellow}Step 3${normal} - Merging video and subtitle.\n"
  # If media is a movie, I need to modify the ouput file a bit for Plex.
  # Their library wants movies to look like this: some.movie(yyyy).mkv
  # I prefer some.movie-(yyyy).mkv which also works fine.
  if [[ "$mediatype" = "Movie" ]]; then
    mkvfile="$finished/$moviename_raw-($movieyear).mkv"
  else
    mkvfile="$finished/$mediafile.mkv"
  fi
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
	if [[ "$showname_raw" = "My.Cat.From.Hell" ]] || [[ "$showname_raw" = "MythBusters" ]] || [[ "$showname_raw" = "NOVA" ]] || [[ "$showname_raw" = "the.Joy.of.Painting" ]] || [[ "$showname_raw" = "Mr.Deity" ]] || [[ "$showname_raw" = "Witchblade" ]] || [[ "$showname_raw" = "Looney.Tunes" ]] || [[ "$showname_raw" = "Tom.and.Jerry" ]]; then
      	# English shows with no subs
      	printf "  Merging video: "
      	trap do_error 1 2
      	mkvmerge --quiet --output $mkvfile \
       	 --language 0:eng --default-track 0 --language 1:eng --default-track 1 $videofile && do_ok
      	cleanup_quick
	else
      # Not English, but Dutch
	  printf "  Merging video: "
      trap do_error 1 2
      mkvmerge --quiet --output $mkvfile \
        --language 0:dut --default-track 0 --language 1:dut --default-track 1 $videofile && do_ok
      cleanup_quick
    fi
  else
    printf "  Merging video and subtitles: "
    for tvshowengsubs in "${tvengsubs[@]}"; do [[ "$tvshowengsubs" = "$showname_raw" ]] && engsubs="YES" ; done
    # Create the MKV
    trap do_error 1 2
    if [[ "$engsubs" = "YES" ]]; then
        mkvmerge --quiet --output $mkvfile \
            --language 0:eng --default-track 0 --language 1:eng --default-track 1 $videofile \
            --language 0:eng --default-track 0 --sub-charset 0:UTF-8 $subtitlefile && do_ok
        cleanup_quick
    else
        mkvmerge --quiet --output $mkvfile \
            --language 0:eng --default-track 0 --language 1:eng --default-track 1 $videofile \
            --language 0:dut --default-track 0 --sub-charset 0:UTF-8 $subtitlefile && do_ok
    	cleanup_quick
    fi
  fi
  engsubs="NO" # reset value
  breaktheloop
  ##################################
  #### STEP 4 - Optimizing file ####
  ##################################
  step="4. Optimizing"
  # Announce step 4
  printf " ${yellow}Step 4${normal} - Optimizing the Matroska file.\n"
  mkclean --optimize --keep-cues "$mkvfile" "${mkvfile}-clean" && mv -f "${mkvfile}-clean" "$mkvfile"
  #######################################
  #### STEP 5 - Move processed files ####
  #######################################
  step="5. Finishing"
  # Announce step 4
  printf " ${yellow}Step 5${normal} - Moving processed files to finished folder.\n"
  printf "  Moving raw video file $(basename $hbinfile) to $dumpster: "
  trap do_error 1
  mv $hbinfile $dumpster && do_ok
  if [[ "$subsneeded" = "YES" ]]; then
    printf "  Moving subtitle file $(basename $subtitle_raw) to $dumpster: "
    trap do_error 1
    mv ${subtitle_raw} ${dumpster} && do_ok
  fi
  breaktheloop
done
# End Script
