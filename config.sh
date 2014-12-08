#!/bin/bash

# User information -----------------------------------------------------
# Fill in your information, you can leave either TRAKT_PASSWORD or TRAKT_PASSHASH empty

# Your trakt.tv user name
TRAKT_USER=''

# Your trakt.tv password
TRAKT_PASSWORD=''

# SHA1 hash of your trakt.tv password
TRAKT_PASSHASH=''

# Your trakt.tv API key (found here: http://trakt.tv/settings/api) 
TRAKT_APIKEY=''

# Your themoviedb.org API key (found here: TODO)
TMDB_APIKEY=''


# Personal movie file naming options -----------------------------------
# If you have an own special naming scheme you can adjust these variables (extended RegEx format)

# Valid video file extensions to include
VIDEOEXT="webm|mkv|flv|flv|ogv|ogg|drc|mng|avi|mov|qt|wmv|yuv|rm|rmvb|asf|mp4|m4p|m4v|mpg|mp2|mpeg|mpe|mpv|mpg|mpeg|m2v|m4v|svi|3gp|3g2|mxf|roq|nsv|iso|nrg|img|adf|adz|dms|dsk|d64|sdi|mds|mdx|dmg|cdi|cue|cif|c2d|daa|ccd|sub|img|b6t"

# Valid space characters in the file name
SPACECHAR=" |_|\."

# Pattern for tags which don't actually belong to the title (e.g. 'UNCUT')
TAG="(([A-Z]+[a-z]*[A-Z]+)|(- Part))(($SPACECHAR)?[0-9]+)?"  # ((First and last letter of tags are uppercase) or ("- Part")) followed by a number (with or without space before of number)

# Pattern for the optional release year in the file name
YEARTAG="(^[0-9]{4})|(\([0-9]{4}\))"  # Year on the beginning of the file name or anywhere but within braces (e.g. "1977 Star Wars.avi" or "Star Wars (1977).avi")
