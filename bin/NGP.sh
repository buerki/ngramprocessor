#!/bin/bash -
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin:"$HOME/bin"" # needed for Cygwin
##############################################################################
# NGP.sh
copyright="(c) 2016-17 Cardiff University, 2013 Andreas Buerki, 2006 Bjoern Wilmsmann, 2000-2006 Ted Pedersen, Satanjeev Banerjee, Amruta Purandare, Bridget Thomson-McInnes and Saiyam Kohli"
####
version="0.6.5"
# DESCRRIPTION: extracts n-grams from a corpus
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
##############################################################################
#
################# defining variables ###############################
# initialise some variables
export installation_dir="$(dirname $(which list.pl))"
export extended="-r"
export required_nsizes="2 3 4 5 6 7"
export required_perdoc="-d"
export stoplist=Leipzig_en_top200_1.2 # this needs complemeting with the name of the stoplist
export required_stoplist="-o $installation_dir/$stoplist" 
#export required_cross_sentence=
export required_minfreq="-f 2"
export LC_ALL="en_GB.UTF-8"
################# defining functions ###############################
#
#######################
# define help function
#######################
help ( ) {
	echo "
DESCRRIPTION: $(basename $0) extracts n-grams from texts
SYNOPSIS:     $(basename $0) [OPTIONS]

OPTIONS:      -d    run in debugging mode
              -h    display this help message
              -p SEP set the word-separator on n-gram lists to SEP
              -V    display version number
              
NOTE:         all other functions are accessed interactively.
"
}
###############
# tidy function
###############
# The 'tidy' function tidies the output n-gram lists so that n-grams are 
# separated from the frequencies by a tab and the document frequencies by a
# further tab and the trailing space on each line is removed
tidy ( ) {
total=$#
if [ "$verbose" == "true" ]; then
	echo "$total list(s) to be processed"
fi
progress=0
for lists in $@
do
	# first write sum of tokens to file
	grep '^[0-9]*$' $lists > $lists.tidy
	sed -e "s/$separator\([0-9]*\)  /$separator	\1	/g" -e "s/$separator\([0-9]*\) $/$separator	\1/g" -e 's/ $//g' < $lists | grep -v '^[0-9]*$' | eval $korean sort -k2,2nr -k1,1 >> $lists.tidy; mv $lists.tidy $lists
	
	# the above lines are explained as follows:
	# sed line: replace patterns of '$separator' followed by a number 
	# followed by a space
	# replace that pattern with the first number found after the '$separator' 
	# followed and preceeded by a tab. This takes care of lines
	# like these 'ZAHL·—·ZAHL·132  38 ' producing this
	# 'ZAHL·—·ZAHL·	132	38'
	# 
	# grep line: get rid of the total number of n-grams printed at the beginning
	# of the list and sort the list
	#
	# sort: we sort without -d option as this option has thrown some errors in
	# testing and sort after frequency in reverse order
	((progress +=1))
done
if [ "$verbose" == "true" ]; then
	echo "$progress list(s) tidied."
fi
}
#######################
# define add_windows_returns function
#######################
add_windows_returns ( ) {
sed 's/$//' "$1"
}
#######################
# define remove_windows_returns function
#######################
remove_windows_returns ( ) {
sed 's///' "$1"
}
#######################
# define splash function
#######################
splash ( ) {
printf "\033c"
echo "NGP $copyright - Licensed under the GNU General Public License"
echo
echo
echo
echo
echo "          N-GRAM PROCESSOR"
echo "          version $version"
echo 
echo 
echo
echo "          Would you like to use the following standard extraction parameters?"
echo 
echo "          a. n-grams of length 2 to 7 orthographic words"
echo "          b. global frequencies and frequencies per document"
echo "          c. additive stoplist of top 200 English words"
echo "          d. no n-grams across line breaks"
echo "          e. alphanumeric characters and the following count as tokens:"
echo "             -'&§%/+°ß"
echo "          f. window size = n-gram size"
echo "          g. minimum frequency: 2 per document"
echo "             (or globally if no document frequencies derived)"
echo
echo "          (y) yes     (n) no     (x) exit"
echo
read -p '         > ' module  < /dev/tty
case $module in
Y|y)	make_SCRATCHDIRs
	# reset standard extraction parameters as they might have been changed last time 'round
	export required_nsizes="2 3 4 5 6 7"
	export required_perdoc="-d"
	export required_stoplist="-o $installation_dir/$stoplist" 
	export required_minfreq="-f 2"
	run_extraction_phase1
	run_extraction_phase2
	echo
	echo "          Would you like to run another extraction?"
	echo 
	echo "          (y) yes     (n) no"
	read -p '         > ' next < /dev/tty
	if [ "$next" == "y" ] || [ "$next" == "Y" ]; then
		return
	else
		exit 0
	fi
	;;
N|n)	customisation_menu
	make_SCRATCHDIRs
	run_extraction_phase1
	run_extraction_phase2
	echo
	echo "          Would you like to run another extraction?"
	echo 
	echo "          (y) yes     (n) no"
	read -p '         > ' next < /dev/tty
	if [ "$next" == "y" ] || [ "$next" == "Y" ]; then
		return
	else
		exit 0
	fi
	;;
X|x)	echo "This window can now be closed"; exit 0
	;;
*)	echo "$module is not a valid choice."
	return
	;;
esac
}
#######################
# define customisation_menu function
#######################
customisation_menu ( ) {
next=
echo "          Which parameter would you like to adjust? (enter a/b/c/d/e/f/g; one at a time)"
echo 
read -p '         > ' next < /dev/tty
case $next in
a)	echo "          Enter the lengths required, separated by spaces, e.g. 1 2 3"
	read -p '         > ' required_nsizes < /dev/tty
	export required_nsizes
	echo "          Your required n are $required_nsizes"; sleep 1
	;;
b)	echo "          (g) global frequencies only"
	echo "          (d) global frequencies as well as document frequencies"
	echo 
	read -p '         > ' b < /dev/tty
	if [ "$b" == "g" ] || [ "$b" == "G" ]; then
		export required_perdoc=""
	fi
	;;
c)	echo "          Please drop the stoplist you would like to use into this window"
	echo "          or just press ENTER to use no stoplist."
	read -p '         > ' new_stop < /dev/tty
	if [ -z "$new_stop" ]; then
		echo "          no stoplist will be used"; sleep 1
		export required_stoplist=
	else
		export required_stoplist="-o $new_stop"
		echo "           stoplist $new_stop will be used"; sleep 1
	fi
	;;
d)	echo "          n-grams across line sentence boundaries are going to be extracted"; sleep 1
	export linebreaks="-l"
	;;
e)	echo "          Please drop a custom token definition file into this window"
	echo "          or just press ENTER to use the standard token definition."
	read -p '         > ' new_stop < /dev/tty
	if [ -z "$new_tokendef" ]; then
		echo "          standard token definition will be used"; sleep 1
	else
		export required_tokendef="-t $new_tokendef"
		echo "           token definitions from $new_tokendef will be used"; sleep 1
	fi
	;;
f)	echo "          Please enter the number by which the window size should be larger than the n-gram size"
	echo "          (e.g. for 2-grams with a window size 3, enter 1)"
	read -p '         > ' window < /dev/tty
	if [ -z "$window" ]; then
		echo "          window size = n-gram size"; sleep 1
	else
		export window
		echo "           a window size of $window larger than the n-gram will be used"; sleep 1
	fi
	;;
g)	echo "          Please enter the new minimum frequency value to be used"
	read -p '         > ' new_minfreq < /dev/tty
	if [ -z "$new_minfreq" ]; then
		echo "          standard minimum frequency of 2 will be used"; sleep 1
	else
		export required_minfreq="-f $new_minfreq"
		echo "           a minimum frequency of $new_minfreq will be used"; sleep 1
	fi
	;;
*)	echo "          $next is not a valid choice of parameter. Please try again"
	customisation_menu
	;;
esac
echo "          Would you like to adjust another parameter?"
echo
echo "          (y) yes     (n) no"
read -p '         > ' next < /dev/tty
if [ "$next" == "y" ] || [ "$next" == "Y" ]; then
	customisation_menu
fi
}
#######################
# define make SCRATCHDIRs function
#######################
make_SCRATCHDIRs ( ) {
	################ create scratch directories
	# for the outputNGP
	export SCRATCHDIR1=$(mktemp -dt NGP1XXX) 
	# if mktemp fails, use a different method to create the SCRATCHDIR
	if [ "$SCRATCHDIR1" == "" ] ; then
		mkdir ${TMPDIR-/tmp/}NGP1XXX.1$$
		SCRATCHDIR1=${TMPDIR-/tmp/}NGP1XXX.1$$
	fi
	# for debugging purposes
	if [ "$debug" ]; then
		export SCRATCHDIR2=$(mktemp -dt NGP2XXX) 
		# if mktemp fails, use a different method to create the SCRATCHDIR
		if [ "$SCRATCHDIR2" == "" ] ; then
			mkdir ${TMPDIR-/tmp/}NGP2XXX.1$$
			SCRATCHDIR2=${TMPDIR-/tmp/}NGP2XXX.1$$
		fi
	fi
	# another one to keep other auxiliary and temporary files in
	export SCRATCHDIR=$(mktemp -dt NGPXXX) 
	# if mktemp fails, use a different method to create the SCRATCHDIR
	if [ "$SCRATCHDIR" == "" ] ; then
		mkdir ${TMPDIR-/tmp/}NGPXXX.1$$
		SCRATCHDIR=${TMPDIR-/tmp/}NGPXXX.1$$
	fi
	if [ "$debug" ]; then
		open $SCRATCHDIR $SCRATCHDIR1 $SCRATCHDIR2 $R_SCRATCHDIR
	fi
}
#######################
# define run_extraction_phase1 function
#######################
run_extraction_phase1 ( ) {
printf "\033c"
echo
echo
echo
echo
echo
echo "          Drag the folder with input textfile(s) into this window and press ENTER."
echo 
read -p '           ' indir  < /dev/tty
if [ "$(grep ' ' <<< "$indir")" ]; then
	echo "The path to the folder includes a space. This will cause errors in processing. Please put the textfiles into a path without spaces (for example by replacing spaces in folder names with underscores) and try again."
exit 0
fi
# get rid of any single quotation marks that might have attached
export indir="$(sed "s/'//g" <<<"$indir")"
# check if anything was entered
if [ -z "$indir" ]; then
	echo "A folder with textfiles must be provided. Please drop the folder into this window."
	read -p '           ' indir  < /dev/tty
	if [ -z "$indir" ]; then
		echo "No data provided." >&2; sleep 1
		splash
		return
	fi
fi
# check if the path provided was to a directory
if [ -d "$indir" ]; then
	:
else
	echo "A folder with textfiles must be provided. Please drop the folder into this window."
	read -p '           ' indir  < /dev/tty
	if [ -d "$indir" ]; then
		:
	else
		echo "No data of the correct type was provided." >&2; sleep 1
		return
	fi
fi
# check if anything is inside the directory
if [ "$(ls "$indir" | wc -l | sed 's/ //g')" -gt 0 ]; then
	# check if there is only a single file in the directory
	if [ "$(ls "$indir" | wc -l | sed 's/ //g')" -eq 1 ]; then
		single_file=TRUE
		if [ "$debug" ]; then
			echo "single file detected in $indir; switching to single-file mode."
		fi
	fi
else
	echo "$indir is empty."
	echo "A folder with textfiles must be provided. Please drop the folder into this window."
	read -p '           ' indir  < /dev/tty
	if [ -n "$indir" ] && [ "$(ls "$indir" | wc -l | sed 's/ //g')" -gt 0 ]; then
		:
	else
		echo "No data of the correct type was provided." >&2; sleep 1
		return
	fi
fi
# remove any Windows returns from in-files
for file in $(ls "$indir"); do
	remove_windows_returns "$indir"/$file > "$indir/$file."
	mv "$indir"/$file. "$indir"/$file
done
# change dir to that of the in-dir
#export working_dirname="$(dirname "$indir" | sed "s/'//g")"
#cd "$working_dirname" 2>/dev/null || dirfail=true
#if [ "$debug" ]; then 
#	echo "now in $(pwd). dirname is $working_dirname"
#	read -p 'press ENTER to continue ' xxx < /dev/tt
#fi
# sort out potential cygwin problems
#if [ "$CYGWIN" ]; then
#	# if it wasn't possible to cd earlier, warn if in -d mode
#	if [ "$dirfail" ]; then
#		if [ "$debug" ]; then
#			echo "cd failed, still in $(pwd)"
#			read -p 'press ENTER to continue ' xxx < /dev/tt
#		fi
#	fi
#   cd "$working_dirname" || echo "ERROR: could not change dir to $working_dirname"
#fi
# run multi-list.sh
echo
echo "N-gram extraction in progress..."
echo
if [ "$CYGWIN" ]; then
	# run multi-list.sh for cygwin
	for required_size in $required_nsizes; do
		echo "extracting n-grams of length $required_size. "
		# calculate window size if necessary
		if [ "$window" ]; then
			required_window=$(echo "-w $(( $required_size + $window ))")
		fi
		if [ "$debug" ]; then
			"$installation_dir/multi-list.sh" -p '<>' -v -s $linebreaks $required_perdoc $required_stoplist $required_minfreq -H $required_tokendef $required_window -n $required_size "$SCRATCHDIR1" "$indir"
			echo "$installation_dir/multi-list.sh -p '<>' -v -s $linebreaks $required_perdoc $required_stoplist $required_minfreq -H $required_tokendef $required_window -n $required_size $SCRATCHDIR1 $indir"
		else
			"$installation_dir/multi-list.sh" -p '<>' -s $linebreaks $required_perdoc $required_stoplist $required_minfreq -H $required_tokendef $required_window -n $required_size "$SCRATCHDIR1" "$indir"
		fi
	done
else
	for required_size in $required_nsizes; do
		echo "extracting n-grams of length $required_size. "
		# calculate window size if necessary
		if [ "$window" ]; then
			required_window=$(echo "-w $(( $required_size + $window ))")
		fi
		if [ "$debug" ]; then
			echo "$installation_dir/multi-list.sh $special_sep -s $linebreaks $required_perdoc $required_stoplist $required_minfreq -H $required_tokendef $required_window -n $required_size $SCRATCHDIR1 $indir"
			"$installation_dir/multi-list.sh" -v $special_sep -s $linebreaks $required_perdoc $required_stoplist $required_minfreq -H $required_tokendef $required_window -n $required_size "$SCRATCHDIR1" "$indir"
		else
			"$installation_dir/multi-list.sh" $special_sep -s $linebreaks $required_perdoc $required_stoplist $required_minfreq -H $required_tokendef $required_window -n $required_size "$SCRATCHDIR1" "$indir"
		fi
	done
fi
echo
if [ "$debug" ]; then
	cp -r $SCRATCHDIR1 $SCRATCHDIR2/after_phase1
fi
}
#######################
# define run_extraction_phase2 function
#######################
run_extraction_phase2 ( ) {
	# run split-unify.sh
	echo "Combining split lists..."
	echo
	for required_size in $required_nsizes; do
		if [ "$single_file" ] || [ -z "$required_perdoc" ]; then
			tidy "$SCRATCHDIR1/$required_size-grams/"*.lst
			mv "$SCRATCHDIR1/$required_size-grams/"*.lst "$SCRATCHDIR1/$required_size.lst"
		else
			echo "now combining $required_size-grams..."
			"$installation_dir/split-unify.sh" -ins $required_perdoc "$SCRATCHDIR1/$required_size-grams"
		fi
	done
	# remove any directories left uncombined
	for dir in $(ls $SCRATCHDIR1 | grep -v '.lst'); do
		rm -r $SCRATCHDIR1/$dir
	done
	# determine outdir
	outdir="$(dirname "$indir")"
	cd "$outdir"
	add_to_name N-gram_lists
	cd - > /dev/null
	#mkdir $output_filename
	if [ "$debug" ]; then
		echo "scratchdir is $SCRATCHDIR1"
		echo "output dir is $outdir/$output_filename"
	fi
	mkdir $outdir/$output_filename
	# change extention to .txt and add windows returns if necessary
	for file in $(ls $SCRATCHDIR1/*); do
		if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
			add_windows_returns $file > $file.
			mv $file. $file
		fi
		if [ "$debug" ]; then
			cp $file "$outdir/$output_filename/$(basename $(sed 's/.lst/.txt/g' <<< "$file"))"
		else
			mv $file "$outdir/$output_filename/$(basename $(sed 's/.lst/.txt/g' <<< "$file"))"
		fi
	done
	#mv $SCRATCHDIR1/* "$output_filename"
	echo
	echo "          N-gram lists were placed in $outdir/$output_filename."
	echo "          Would you like to open the output directory?"
	echo "          (Y) yes       (N) no"
	echo
	read -p '          > ' a  < /dev/tty
	if [ "$a" == "y" ] || [ "$a" == "Y" ] || [ -z "$a" ]; then
		if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
			cygstart "$outdir"/$output_filename
		elif [ "$(grep 'Darwin' <<< $platform)" ]; then
			open "$outdir"/$output_filename
		else
			xdg-open "$outdir"/$output_filename
		fi
	fi
	# tidy up
	if [ "$debug" == true ]; then
		:
	else
		rm -r $SCRATCHDIR1 &
		rm -r $SCRATCHDIR &
	fi
}
#######################
# define add_to_name function
#######################
# this function checks if a file name (given as argument) exists and
# if so appends a number to the end so as to avoid overwriting existing
# files of the name as in the argument or any with the name of the argument
# plus an incremented count appended.
####
add_to_name ( ) {
count=
if [ "$(grep '.csv' <<< "$1")" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed 's/\.csv//' <<< "$1")"
		while [ -e "$new$add$count.csv" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed 's/\.csv//' <<< "$1")$add$count.csv"
elif [ "$(grep '.lst' <<< "$1")" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed 's/\.lst//' <<< "$1")"
		while [ -e "$new$add$count.lst" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed 's/\.lst//' <<< "$1")$add$count.lst"
elif [ "$(grep '.txt' <<< "$1")" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed 's/\.txt//' <<< "$1")"
		while [ -e "$new$add$count.txt" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed 's/\.txt//' <<< "$1")$add$count.txt"
else
	if [ -e "$1" ]; then
		add=-
		count=1
		while [ -e "$1"-$count ]
			do
			(( count += 1 ))
			done
	else
		count=
		add=
	fi
	output_filename=$(echo "$1$add$count")
fi
}
############### end defining functions #####################

# check what platform we're under
platform=$(uname -s)
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	alias clear='printf "\033c"'
	echo "running under Cygwin"
	export CYGWIN=true
elif [ "$(grep 'Darwin' <<< $platform)" ]; then
	extended="-E"
	DARWIN=true
else
	LINUX=true
fi
# analyse options
while getopts dhpV opt
do
	case $opt	in
	d)	export debug=true
		echo "Running in debug mode";sleep 1
		;;
	h)	help
		exit 0
		;;
	p)	special_sep="-p $OPTARG"
		;;
	V)	echo "$(basename "$0")	-	version $version"
		echo "$copyright"
		echo "Licensed under the GNU General Public License"
		exit 0
		;;
	esac
done
shift $((OPTIND -1))
# splash screen
#printf "\033c"
#echo "N-Gram Processor - (c) 2016 Cardiff University - licensed under the GNU General Public License"
printf "\033c"
splash
sleep 5
until [ "$module" == "X" ]; do
	splash
	sleep 5
done