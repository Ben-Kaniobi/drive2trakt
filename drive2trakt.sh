#!/bin/bash

# TODO: TMDb -> We currently rate limit requests to 30 requests every 10 seconds.

# Error- and argument handling -----------------------------------------

# Exit on error
set -o errexit
# Variables and function for readibility
ERROR=1
SUCCESS=0
USAGE="Usage: `basename $0` [OPTION]... [DIR]
Searches for movie files in DIR and add them to the collection of the trakt.tv user.

  -r, --recursive            search subdirectories recursively
  -s, --seen                 submit to seen too
  -w, --watchlist            submit to watchlist too
      --help                 display this info"
function echo-err { echo "$@" >&2; }

# Get options and set flags
OPT_R=false
OPT_S=false
OPT_W=false
I=0  # Count option arguments to be able check for correct number of arguments later
for ARG in "$@"
do
	case "$ARG" in
        -r|--recursive)                I=$((I+1)); OPT_R=true ;;
        -s|--seen)                     I=$((I+1)); OPT_S=true ;;
        -w|--watchlist)                I=$((I+1)); OPT_W=true ;;
		-rs|-sr)                       I=$((I+1)); OPT_R=true; OPT_S=true ;;
		-rw|-wr)                       I=$((I+1)); OPT_R=true; OPT_W=true ;;
		-sw|-ws)                       I=$((I+1)); OPT_S=true; OPT_W=true ;;
        -rsw|-rws|-srw|-swr|-wrs|-wsr) I=$((I+1)); OPT_R=true; OPT_S=true; OPT_W=true ;;
		--help) echo "$USAGE"; exit $SUCCESS;
    esac
done

# Check if max. one other argument was specified
if [ $(($#-I)) -eq 1 ]
then
	# The additional additional (last) argument is the directory
	DIR="${@: -1}"
elif [ $(($#-I)) -le 0 ]
then
	# No other argument specified, use the current directory
	DIR="."
else
	echo-err "$USAGE"
	exit $ERROR
fi

# Config file inport and global variables ------------------------------

# Import config file
source "./config.sh"

# Function definitions -------------------------------------------------

# Get the movies in current directory
# param 1: directory (optional)
# param 2: additional options for the 'ls' command (see 'ls --help', optional)
function getMovies {
	# Get all video files
	TEMP=$(ls -1 $2 $1 | grep --ignore-case -E "\.($VIDEOEXT)$")
	# Remove the extension
	TEMP=$(echo "$TEMP" | perl -pe "s/ *\.[^.\n]*$//g")
	# Make sure all space characters are the same
	TEMP=$(echo "$TEMP" | perl -pe "s/($SPACECHAR)/ /g")
	# Remove spaces at the end and the beginning
	TEMP=$(echo "$TEMP" | perl -pe "s/(^ *)|( *$)//g")
	# Remove tags at the end of the file name
	TEMP=$(echo "$TEMP" | perl -pe "s/( +$TAG)*$//g")
	# Sort lines
	TEMP=$(echo "$TEMP" | sort)
	# Remove double entries
	TEMP=$(echo "$TEMP" | uniq --ignore-case)
	echo "$TEMP"
}

# Get first value for key
# param 1: data
# param 2: key
function jsonval {
	TEMP=$(echo "$1" | perl -pe 's/^.*?"'"$2"'":"?([^,"]*)"?.*$/\1/')
	if [ "$TEMP" == "$1" ]
	then
		echo ""
	else
		echo "$TEMP"
	fi
} 

# Get TMDb ID from title (language doesn't matter)
# param: movie title
function getTMDbID {	
	# Extract year
	YEAR=$(echo "$1" | perl -pe "s/^.*($YEARTAG).*$/\1/g")
	if [ "$YEAR" == "$1" ]
	then
		YEAR=""
	else
		YEAR=$(echo "$YEAR" | perl -pe "s/\(|\)//g")
	fi
	# Remove year from title
	TEMP=$(echo "$1" | perl -pe "s/ *($YEARTAG) *//g")
	# Replace spaces with '+' for the url
	TEMP=$(echo "$TEMP" | perl -pe "s/ /+/g")
	# Get the data
	TEMP=$(curl --silent "http://api.themoviedb.org/3/search/movie?api_key=$TMDB_APIKEY&query=$TEMP&year=$YEAR")
	# Get the ID from the data
	TEMP=$(jsonval "$TEMP" "id")
	if [ "$TEMP" == "" ]; then TEMP="-"; fi
	echo "$TEMP"
}

# Start of main script part --------------------------------------------

# Generate password hash if not specified already
if [ "$PASSHASH" == "" ]
then
	PASSHASH=$(echo -n "$PASSWORD" | openssl dgst -sha1)
fi

# Check TMDb API key
TEMP=$(curl --silent "http://api.themoviedb.org/3/movie/11?api_key=$TMDB_APIKEY")
TEMP1=$(jsonval "$TEMP" "status_code")
if [ "$TEMP1" != "" ] && [ "$TEMP1" != "1" ]
then
	echo-err "TMDb Error $TEMP1 - "'"'$(jsonval "$TEMP" "status_message")'"'
	exit $ERROR
fi

# Get movie list
if [ "$OPT_R" = true ]
then
	MOVIES=$(getMovies "$DIR" "--recursive")
else
	MOVIES=$(getMovies "$DIR")
fi

# Count movies
N=$(echo -n "$MOVIES" | grep -c '^')
echo "$N movie files found"
echo -n "$MOVIES" > "_Movies.txt"

# Get TMDb ID for each movie
echo -n "Getting TMDb IDs: 0 %"
I=0
while read -r MOVIE
do
	I=$((I+1))
	
	ID=$(getTMDbID "$MOVIE")
	if [ "$IDS" == "" ]
	then
		IDS="$ID"
	else
		IDS=$(echo -e "$IDS\n$ID")
	fi
	
	echo -en "\e[0K\rGetting TMDb IDs: $((100 * I / N)) %"
done <<< "$MOVIES"
echo

# Write not found movies to file
rm -f "_Movies_not_found.txt"
I=0
while read -r ID
do
	I=$((I+1))
	if [ "$ID" == "-" ]
	then
		echo "$MOVIES" | sed -n ${I}p >> "_Movies_not_found.txt"
	fi
done <<< "$IDS"

# Remove ID 0 which was used for not found movies
IDS=$(echo "$IDS" | perl -pe "s/^0\n?$//g")