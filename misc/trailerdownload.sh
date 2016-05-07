# Download trailers and put them in the correct moviedir

# The file to read
listfile="$HOME/Downloads/trailerdownload.lst"
cp "$listfile" "$listfile.bkp"

#Default trailer name
trailername="Official Trailer-trailer.mp4"

deleteline ()
{
  sed --in-place -e "/$1/d" $listfile
}

downloadthetrailer()
{
  printf "Downloading trailer $moviename ($movieyear) to $trailerdir."
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
      printf "."
      # Download the trailer at its current best quality
      if youtube-dl --merge-output-format mp4 --quiet $trailerlink --output "$trailerdir/$trailername"
        printf "."
      then
        deleteline $moviename && printf ". OK\n"
      else
        printf ". FAILED!"
      fi
    fi
  fi
  sleep 2m # Give Plex time to scan the new content
}

# Read the input file
cat $listfile | while read line
do
  movie=$(echo $line | awk '{ print $1 }')
  trailerlink=$(echo $line | awk '{ print $2 }')
  moviename=$(echo $movie | cut --delimiter=\- --fields=1)
  movieyear=$(echo $movie | cut --delimiter=\- --fields=2 | cut -c 2-5 )
  trailerdir="/mnt/Speelfilm/$movie"
  if [[ -d "/mnt/Speelfilm/$movie" ]]
  then
    trailerdir="/mnt/Speelfilm/$movie"
    downloadthetrailer
  elif [[ -d "/mnt/SpeelfilmKids/$movie" ]]
    trailerdir="/mnt/SpeelfilmKids/$movie"
    downloadthetrailer
  elif [[ -d "/mnt/Documentaire/$movie" ]]
    trailerdir="/mnt/Documentaire/$movie"
    downloadthetrailer
  else
    printf "Directory for $moviename ($movieyear) not found. SKIPPING\n"
done
