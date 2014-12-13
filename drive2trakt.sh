#!/bin/bash

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

# Variables
FILE_MOVIES="_Movie_list.txt"
FILE_MOVIES_NOTFOUND="_Movies_not_found.txt"
FILE_MOVIES_FOUND="_Movies_found.txt"
FILE_RESULT="_Result.txt"

CHAR_NOTFOUND="-"
CHAR_IDSEPARATOR=", "

BATCH_SIZE=1000

# Import config file
source "./config.sh"

# Function definitions -------------------------------------------------

# Get the movies in current directory
# param 1: directory (optional)
# param 2: additional options for the 'ls' command (see 'ls --help', optional)
# retval:  list of found movies
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
# retval:  value
function getJSONValue {
	TEMP=$(echo "$1" | perl -pe 's/^.*?"'"$2"'":"?([^,"]*)"?.*$/\1/')
	if [ "$TEMP" == "$1" ]
	then
		echo ""
	else
		echo "$TEMP"
	fi
}

# Get TMDb ID from title (language doesn't matter)
# param:  movie title
# retval: TMDb ID
function getTMDbInfo {	
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
	ID=$(getJSONValue "$TEMP" "id")
	if [ "$ID" == "" ]
	then
		# Movie not found, return defined 'not found' character and exit function
		echo "$CHAR_NOTFOUND"
		return $SUCCESS
	fi
	# Get the title from the data
	TITLE=$(getJSONValue "$TEMP" "title")
	echo "$ID$CHAR_IDSEPARATOR$TITLE"
}

# Scan directory for movie files, get TMDb info for each and create a file with the list.
# param:  directory to scan
# retval: none (echoes info)
function createScanFile {
	# Test TMDb API key
	TEMP=$(curl --silent "http://api.themoviedb.org/3/movie/11?api_key=$TMDB_APIKEY")
	TEMP1=$(getJSONValue "$TEMP" "status_code")
	if [ "$TEMP1" != "" ] && [ "$TEMP1" != "1" ]
	then
		echo-err "TMDb error $TEMP1 - "'"'$(getJSONValue "$TEMP" "status_message")'"'
		return $ERROR
	fi

	# Get movie list
	if [ "$OPT_R" = true ]
	then
		MOVIES=$(getMovies "$1" "--recursive")
	else
		MOVIES=$(getMovies "$1")
	fi

	# Count movies
	if [ "$MOVIES" == "" ]
	then
		N=0
	else
		N=$(echo -n "$MOVIES" | grep -c '^')
	fi
	echo "$N movie files found"

	# Return if no file found
	if [ "$N" -le 0 ]; then return $SUCCESS; fi

	# Save movie list to file
	echo -e "List of the scanned movies:\n" > "$FILE_MOVIES"
	echo -n "$MOVIES" >> "$FILE_MOVIES"

	# Get TMDb info for each movie
	echo -n "Getting TMDb info: 0 %"
	I=0
	while read -r MOVIE
	do
		I=$((I+1))
		
		TMDB_INFO=$(getTMDbInfo "$MOVIE")
		if [ "$TMDB_INFOLIST" == "" ]
		then
			TMDB_INFOLIST="$TMDB_INFO"
		else
			TMDB_INFOLIST=$(echo -e "$TMDB_INFOLIST\n$TMDB_INFO")
		fi
		
		echo -en "\e[0K\rGetting TMDb info: $((100 * I / N)) %"
	done <<< "$MOVIES"
	echo
	echo

	# Create new files for found and not found movies
	echo -e "List list of movies for which no match could be found (Note: If you have a year in a movie file name it is extracted and used to improve the search, the downside is that a wrong year completely prevents finding the movie):\n" > "$FILE_MOVIES_NOTFOUND"
	echo -e "List of movies for which a match could be found. Your title and the datebase title is listed so you can check for any mistakes. This file will be used in the next step to add the movies to your trakt.tv account. If you want to correct something in the file, make sure you also change the ID to the correct TMDb ID (eg. https://www.themoviedb.org/movie/11-star-wars-episode-iv-a-new-hope --> ID=11) as only this number will actually used.\n\nScheme: ID$CHAR_IDSEPARATOR""datebase title$CHAR_IDSEPARATOR""your title\n" > "$FILE_MOVIES_FOUND"
	I=0
	while read -r TMDB_INFO
	do
		I=$((I+1))
		
		# Read same line of other variable
		MOVIE=$(echo "$MOVIES" | sed -n ${I}p)
		
		# Sort out not found movies
		if [ "$TMDB_INFO" == "-" ]
		then
			echo "$MOVIE" >> "$FILE_MOVIES_NOTFOUND"
		else
			echo -n "$TMDB_INFO$CHAR_IDSEPARATOR" >> "$FILE_MOVIES_FOUND"
			echo "$MOVIE" >> "$FILE_MOVIES_FOUND"
		fi
	done <<< "$TMDB_INFOLIST"
	
	echo "Files created:"
	echo ' - "'"$FILE_MOVIES"'": List of the scanned movies.'
	echo ' - "'"$FILE_MOVIES_NOTFOUND"'": List list of movies for which no match could be found.'
	echo ' - "'"$FILE_MOVIES_FOUND"'": List of the movies for which a match could be found. Your title and the datebase title is listed so you can check for any mistakes.'
}

# Send JSON data to server
# param 1: address
# param 2: json data
# retval:  none
function sendJSON {
	curl --silent -H "Content-Type: application/json" -d "$2" "$1"
}

# Update the trakt account (specivied in "config.sh") with the movies
# param:  movie list
# retval: none (echoes info)
function updateTraktAccount {
	# Generate password hash if not specified already
	if [ "$TRAKT_PASSHASH" == "" ]
	then
		TRAKT_PASSHASH=$(echo -n "$TRAKT_PASSWORD" | openssl dgst -sha1)
	fi

	# Test trakt.tv account
	DATA='{"username":"'"$TRAKT_USER"'","password":"'"$TRAKT_PASSHASH"'"}'
	DATA=$(sendJSON "http://api.trakt.tv/account/test/$TRAKT_APIKEY" "$DATA")
	VALUE=$(getJSONValue "$DATA" "status")
	if [ "$VALUE" != "success" ]
	then
		echo-err "trakt.tv error - "'"'$(getJSONValue "$DATA" "error")'"'
		return $ERROR
	fi
	
	# Return if there are no movies
	MOVIES="$1"
	if [ "$MOVIES" == "" ]
	then
		return $SUCCESS
	fi
	N=$(echo -n "$MOVIES" | grep -c '^')
	
	# Create list of TMDb IDs in JSON format
	I=0
	while read -r MOVIE
	do
		I=$((I+1))
		
		JSON_ID='{"tmdb_id":"'"$MOVIE"'"}'
		
		if [ "$JSON_IDS" == "" ]
		then
			# Beginning of list
			JSON_IDS="[$JSON_ID"
		else
			# Continuing list, seperate with comma
			JSON_IDS="$JSON_IDS,$JSON_ID"
		fi
	done <<< "$MOVIES"
	# Properly end the list
	JSON_IDS="$JSON_IDS]"
	# Put JSON data of movies and user information together
	DATA='{"username":"'"$TRAKT_USER"'","password":"'"$TRAKT_PASSHASH"'","movies":'"$JSON_IDS"'}'
	echo
	# Send data to the server with POST and read response
	DATA=$(sendJSON "http://api.trakt.tv/movie/library/$TRAKT_APIKEY" "$DATA")
	# Format JSON data to more readable text
	DATA=$(echo "$DATA" | perl -pe 's/(^{ *"?)|( *"?}$)//g')       # Remove beginning and end
	DATA=$(echo "$DATA" | perl -pe 's/"? *: *"?/ : /g')            # Format space between key and value
	DATA=$(echo "$DATA" | perl -pe 's/"? *}? *,? *{ *"?/\n\  /g')  # Format ident and space of nested JSON objects
	DATA=$(echo "$DATA" | perl -pe 's/"? *} */ /g')                # Format end of nested JSON objects
	DATA=$(echo "$DATA" | perl -pe 's/"? *, *"?/\n/g')             # Format space between key/value pairs
	echo "$DATA" > "$FILE_RESULT"
	echo 'File "'"$FILE_RESULT"'" created: Contains information about updating your collection'
}

# Start of main script part --------------------------------------------

# Check if file with found movies already exists from previous run
if [ -e "$FILE_MOVIES_FOUND" ]; then
	echo -n "File $FILE_MOVIES_FOUND already exists. The script can use this file or start a new scan. "
	while true; do
		read -p "Start new scan (overwrite existing file)? [Y/n] " SCAN
		case "$SCAN" in
			[Nn]* ) SCAN=false; break;;
			[Yy]* ) SCAN=true; break;;
		esac
	done
	echo
else
	SCAN=true
fi

# Start scan and get TMDb info
if [ "$SCAN" == true ]
then
	createScanFile "$DIR"
	echo
fi

# Wait for user before continuing
while true; do
	read -p "Continue with updating your trakt.tv collection? [Y/n] " SCAN
	case "$SCAN" in
		[Nn]* ) exit $SUCCESS;;
		[Yy]* ) break;;
	esac
done

# Read file with movie list
MOVIES=$(<"$FILE_MOVIES_FOUND")
# Keep only the IDs
MOVIES=$(echo "$MOVIES" | perl -pe "s/^ *([0-9]*).*$/\1/g" | perl -pe "s/^\s*$//g")

# Add the movies to the trakt.tv account
updateTraktAccount "$MOVIES"