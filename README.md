drive2trakt
===========

Bash script which scans for movie files and adds the titles to your trakt.tv account. Movie file names don't have to be in English. TV shows not supported (yet?), sorry. The script is not very fast, but it does the job :) 


What you'll need
----------------

- [TMDb](https://www.themoviedb.org/) API key
- [trakt.tv](http://trakt.tv/) account
- bash (works with *git bash* for Windows, so it should work with *Cygwin* too)


How to
------

1. Add your user information to the file '*config.sh*'
2. Optional: Change the naming options in the same file
3. Make sure both files '*drive2trakt.sh*' and '*config.sh*' are executable

	```bash
	chmod +x drive2trakt.sh config.sh
	```
4. See help option for usage

	```bash
	./drive2trakt.sh --help
	```
	Output:
	```
	Usage: drive2trakt.sh [OPTION]... [DIR]
	Searches for movie files in DIR and add them to the library of the trakt.tv user.
	
	  -r, --recursive            search subdirectories recursively
	  -s, --seen                 add movies to seen list too
	  -w, --watchlist            add movies to watchlist too
	      --help                 display this info
	```

5. Run the script with the options you like