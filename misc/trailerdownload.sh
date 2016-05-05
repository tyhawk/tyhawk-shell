# Download trailers and put them in the correct moviedir

# The file to read
listfile="$HOME/Downloads/trailerdownload.lst"
cp "$listfile" "$listfile.bkp"

# Set the root directory
rootdir="/mnt/Speelfilm"
#Default trailer name
trailername="Official Trailer-trailer.mp4"

deleteline ()
{
  sed --in-place -e "/$1/d" $listfile
}

# Read the input file
cat $listfile | while read line
do
  movie=$(echo $line | awk '{ print $1 }')
  trailerlink=$(echo $line | awk '{ print $2 }')
  moviename=$(echo $movie | cut --delimiter=\- --fields=1)
  movieyear=$(echo $movie | cut --delimiter=\- --fields=2 | cut -c 2-5 )
  #trailerdir="$rootdir/$moviename-($movieyear)"
  trailerdir="$rootdir/$movie"
  printf "Downloading trailer $moviename ($movieyear) to $trailerdir."
  if [[ -d "$trailerdir" ]]
  then
    printf "."
    # Check if we can download the 720p version
    if youtube-dl -f 22 --simulate --quiet $trailerlink
    then
      printf "."
      # Download the 720p version
      if youtube-dl -f 22 --merge-output-format mp4 --quiet $trailerlink --output "$trailerdir/$trailername"
      printf "."
      then
        deleteline $moviename && printf ". OK\n"
      else
        printf ". FAILED!\n"
      fi
    else
      printf "."
      # Download the trailer at its current best quality
      if youtube-dl --merge-output-format mp4 --quiet $trailerlink --output "$trailerdir/$trailername"
      printf "."
      then
        deleteline $moviename && printf ". OK\n"
      else
        printf ". FAILED!\n"
      fi
    fi
  else
    printf ". ABORTED!\nMovie not in collection (yet).\n"
  fi
  sleep 2m # Give Plex time to index the new trailer
done
