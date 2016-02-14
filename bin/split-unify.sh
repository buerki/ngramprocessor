#!/bin/bash -

##############################################################################
# split-unify.sh
version="2.0"
copyright="Copyright 2013 Andreas Buerki, 2016 Cardiff University"
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
# DESCRRIPTION: a shell script wrapper for unify.pl; combines n-gram
#               lists created by cou.sh
# SYNOPSIS: split-unify.sh [OPTIONS] source_dir
# DEPENDENCIES: unify.pl (NGP)
# UNDOCUMENTED OPTIONS (experimental):
# -j ARG To request processing with unify.pl or a version of count.pl
#	     where ARG is the name of the version to be used.
#		 Currently, unify.pl is used in standard mode, in -s mode if statistics
#		 are requested and in -b mode. In -s mode without statistics, the
#		 consolidate function of split-unify.sh is used.
# -k	 declare data are in Hangeul script
# the script implements a procedure allowing the n-gram lists to
# hold n-gram frequencies AS WELL AS document frequencies. It employs various
# splitting methods in order to reduce memory requirements
# In case of the -s option, the splitting is bypassed.
#
# output lists list n-grams in the following format:
# ZAHL·ZAHL·ZAHL·cm·  205     10
# -> tab delimited without trailing space, first number is freq., 
#    second doc count
#
####
# dependencies: these external scripts need to installed
# • unify.pl (NSP)
####
# CHANGELOG
# date			change
# 01 Jan 2016	changed copyright assignment
# 25 Dec 2013	added consolidation function to unify without calling unify.pl
#				this function is called if -s (but not stats) is requested
# 19 Nov 2013	reorganised options, added safeguard to alphabet split for the
#				case that some sections may be empty, adjusted tidy function
# 10 Nov 2013	adjusted script to work with new NGP version of unify.pl as well
#				as legacy NSP versions (huge-combine.pl); final deletion of tmp
#				files now happens in the background, allowing the script to
#				finish before that task is completed.
# 30 Oct 2013	switched to using NGP's unify.pl; reversed display of changelog
#				now showing most recent change first; fixed display of 84-way 
#				progress to say 'of 85' since it's 84 + remainder regex; added 
#				-j option to chose version of unify.pl to be used
# 02 Jan 2012	adjusted split 47 and 84 functions to work with loops
#				and with with huge-combine_exp.pl instead of huge-combine.pl
# 06 Dec 2011	adjusted script to work with changes made to huge-combine.pl
# 06 Nov 2011	split and combination is now done in a proper scratch dir;
#				if there is just one input file, the script now simply applies
#				the tidying function and outputs the file as usual rather than
#				throwing an error
#				changed argument structure: now the source directory in which
#				files to be operated on are located must be specified as
#				second argument. This means the script can now be run from
#				any pwd
# 02 Nov 2011	changed handling of immediate output file of huge-combine.pl
#				now first puts file in temp dir, and moves it in place later
#				added -u option to additionally produce an untidy output list
# 27 Oct 2011	adjusted script to make use of ---filecount option in
#				huge-combine.pl
#  				added -i option to retain individual lists after combination
#				removed -d -j and -r options as they are no longer needed
#				revised tidy-function
# 26 Oct 2011	changed encoding of script file to utf-8
# 09 Mar 2011	fixed error in -d option
# 24 Jan 2011	adjusted treatment of lines starting with digits (should now
#				no longer be excluded
# 13 Oct 2010	integrated alphabet-split47 and 84 as functions (used to be
#				independent scripts) and adjusted progress reporting to
#				use less screen space
# 14 Aug 2010	added -d option and made default no 8-way grouping
# 18 Jul 2010	added -b option for an 84-way split for very large data sets
# 15 Jul 2010	now runs on alphabet-split47.sh rather than 42
##############################################################################

I=$(date +"%e-%b-%H:%M:%S") # putting start date and time in variable I
ID=$(echo $I | sed 's/ //g') # cutting any leading space from string and put $ID

#################################define functions#############################

#################
### help function (displays help)
#################
help ( ) {
	echo "
Usage: $(basename $0) [OPTIONS] IN-DIRECTORY
Example: $(basename $0) -s .
Options: 
-d  include document frequencies in lists
-h  display this message
-i  discard directory with individual lists (otherwise this directory
    is renamed and retained)
-m  memory-saving algorithm (keeps RAM usage to minimum, but takes more time)
-n  no numbers for calculation of statistical measures of association
-s  run the version for smaller amounts of data (less then 5M words)
-b  run big version for large amounts of data (84-way alphabet split)
-u  leave lists untidy, i.e. in the format n·gram·0 0
-v  causes the script to run verbose
-V  display the version number of this programme

NOTE: IN-DIRECTORY would ordinarily be the output directory of 'multi-list.sh'
      (i.e. a directory with lists in it, all of which need to be combined)
      If -m option is combined with -s, the smalled possible memory footprint
      is achieved, compensated by the longest processing time.
"
}

#####
# define add_to_name function
add_to_name ( ) {
#####
# this function checks if a file name (given as argument) exists and
# if so appends a number to the end so as to avoid overwriting existing
# files of the name as in the argument or any with the name of the argument
# plus an incremented count appended. The safe name is put in the variable
# output_filename
####

count=
if [ -a "$1" ]; then
	add=-
	count=1
	while [ -a "$1"-"$count" ]
		do
		(( count += 1 ))
		done
else
	count=
	add=
fi
output_filename=$(echo "$1$add$count")

}


###############
# tidy function
###############
# The 'tidy' function tidies the output of huge-count.pl so that n-grams are 
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
	sed -e "s/$separator\([0-9]*\)  /$separator	\1	/g" -e "s/$separator\([0-9]*\) $/$separator	\1/g" -e 's/ $//g' < $lists | grep -v '^[0-9]*$' | eval $korean sort -k2,2nr -k1,1 >> $lists.tidy
	
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


###########################
# alphabet-split function
###########################
alphabet-split ( ) {
###
# This function runs unify.pl more efficiently on argument files given
# by dividing lists into 48 or 84 sub-lists based on the letters the n-grams 
# start with, then running unify.pl on each and finally merging the result
# with cat.
#
# OPTIONS: -v verbose
#		   -b use the 84-way split (otherwise 48-way split is used)
# !!! first argument must be output file name !!!
# !!! subsequent arguments must be n-gram lists to be combined !!!
###

# analyse options
while getopts vb opt
do
	case $opt	in
	v)	verbose=true
		;;
	b)	big=true
		;;
	esac
done

shift $((OPTIND -1))

# check if at least 3 arguments were supplied
if [ $# -lt 3 ] ; then
	echo 'ERROR: output filename and 2 lists to combine must minimally be supplied as arguments to the function alphabet-split' >&2
	exit 1
fi

out="$1"
shift  # shift so that subsequent arguments start with the lists supplied

# create scratch directories where temp files can be moved about
SCRATCHDIR1=$(mktemp -dt combinationXXX) 
# if mktemp fails, use a different method to create the SCRATCHDIR1
if [ "$SCRATCHDIR1" == "" ] ; then
	ID1=$$
	mkdir ${TMPDIR-/tmp/}combination.1$ID1
	SCRATCHDIR1=${TMPDIR-/tmp/}combination.1$ID1
fi
SCRATCHDIR2=$(mktemp -dt combinationXXX) 
# if mktemp fails, use a different method to create the SCRATCHDIR2
if [ "$SCRATCHDIR2" == "" ] ; then
	ID2=$$
	mkdir ${TMPDIR-/tmp/}combination.2$ID2
	SCRATCHDIR2=${TMPDIR-/tmp/}combination.2$ID2
fi

# create a variable with the required letter sequences for the splits
if [ -n "$big" ]; then
	letters="$(echo -n {A..Z}; echo -n " "; echo -n {A..B}{A..Z}; echo -n " "; echo -n C{A..F})"
else
	letters="$(echo -n {A..Z}; echo -n " "; echo A{A..T})"
fi

# create alphabet directories in SCRATCHDIR1
for label in $letters ; do
	mkdir $SCRATCHDIR1/$label
done
mkdir $SCRATCHDIR1/remainder

if [ -n "$big" ]; then
	# put the split regexes into the variable split_into
	split_into="^A[a-q] ^A[r-z] ^B[a-e] ^B[f-z] ^[CD] ^[E] ^[G] ^F ^[HIJ] ^K ^L ^M ^N[A-E] ^N[F-Z|a-z] ^[O-P] ^[Q-R] ^S[a-o] ^S[p-z] ^[T] ^[UV] ^[W] ^[X-Z] ^a[a-l] ^a[m-t] ^au[a-n] ^au[o-z] ^b[a-e] ^b[f-z] ^(c|er[a-z]|ü) ^d[a-d] ^de[a-q] ^der$separator[a-z] ^der$separator[A-Z] (^der[a-z]|^de[s-z]) ^die$separator[a-z] ^die$separator[A-Z] ^die[a-z] ^(di[f-z]|d[j-z]|e[a-h]) ^ein[a-z] ^einA$separator[A-Z] ^einA$separator[a-z] ^(e[j-q]|er$separator) ^e[s-z] ^f ^h[a-g] ^ge ^(h[h-z]|g[f-z]|g[a-d]) ^i[a-e] ^i[f-m] ^in ^i[o-z] ^j ^k ^l ^m[a-h] ^mit ^m(i[a-s]|i[u-z]|k-z) ^n[a-g] ^n[h-z] ^[opqr] ^s[a-d] ^s[e-h] ^si[a-c] ^si[d-z] ^s[j-z] ^(t|u[a-m]) ^und$separator[A-Z|a-d] ^u(nd$separator[e-z]) ^u(n[o-z]|[o-z]) ^v[a-n] ^v[o-z] ^w[a-d] ^we ^w[f-l] ^(w[m-z]|xy) ^zu ^z([a-t]|[v-z]) ^dA$separator[A-D] ^dA$separator[E-L] ^dA$separator[M-S] ^dA$separator[T-Z] ^dA$separator[a-j] ^dA$separator[k-z] ^(dA$separator(ü|Ü|-|&|ä|Ä|ö|Ö)|m(ä|ö|ü)|d(ä|ö|ü)|ö|ä|Ä|Ö|Ü|h(ä|ö|ü)|w(ä|ö|ü))"

	# combine the above 84 into a single regex with | and put it in its 
	# own variable
	remainder_regex=$( echo $split_into | sed 's/ /|/g' )
else
	# put the split regexes into the variable split_into
	# though there are incidentally only 46, the 47th is the remainder
	split_into="^[A] ^[B] ^[CDE] ^[G] ^[FHIJ] ^[KL] ^[MN] ^[O-R] ^[S] ^[T] ^[UV] ^[W] ^[X-Z] ^a[a-o] ^a[p-z] ^[bc] ^d[a-d] ^de[a-q] ^der$separator[a-z] ^der$separator[A-Z] (^der[a-z]|^de[s-z]) ^die$separator[a-z] ^die$separator[A-Z] ^die[a-z] ^(di[f-z]|d[j-z]|e[a-g]) ^e[h-i] ^e[j-z] ^[fh] ^[g] ^i[a-m] ^i[n-z] ^[jk] ^[lm] ^[n] ^[opqr] ^s[a-d] ^s[e-k] ^s[l-z] ^(t|u[a-m]) ^u[n-z] ^[v] ^[wxy] ^[z] ^dA$separator[A-L] ^dA$separator[M-Z] ^dA$separator[a-z]"

	# combine the above 46 into a single regex with | and put it in its 
	# own variable
	remainder_regex=$( echo $split_into | sed 's/ /|/g' )
fi

# create the array labels (from scalar 'letters') which will be used to
# name the split lists and put them into the correct directory
labels=( $letters )

# inform user and create feedback variables
if [ "$verbose" == "true" ]; then
	echo -n "splitting lists.  0%"
	total=$(echo "$@" | wc -w | sed 's/ //g')
	progress=0
fi

# divide lists into sub-lists (plain 'for' operates on $@)
for arg
do
	if [ "$verbose" == "true" ]; then
		if [ "$(( $progress * 100 / $total))" -lt "10" ]; then
			echo -en "\b\b\b $(( $progress * 100 / $total))%"
		else
			echo -en "\b\b\b\b $(( $progress * 100 / $total))%"
		fi
		(( progress += 1 ))
	fi
	iteration=0
	for regex in $split_into; do
		egrep "$regex" "$source_dir/$arg" > \
		$SCRATCHDIR1/${labels[$iteration]}/$arg.${labels[$iteration]}
		(( iteration += 1 ))
	done
	grep -E -v "$remainder_regex" "$source_dir/$arg" > \
	$SCRATCHDIR1/remainder/$arg.remainder
	# removed this from above: | grep -v ^[0-9]*$
done
# the second grep makes sure no total n-gram counts end up in the remainder


# inform user
if [ "$verbose" == "true" ]; then
	echo -e "\b\b\b Done splitting."
fi



# combine sub-lists

# add 'remainder' to the letter variable
letters="$letters remainder"

# initiate variable for user report and start reporting
if [ "$verbose" == "true" ] && [ -n "$big" ]; then
	# set user feedback variable
	progress=0
	# it's 85 because 84 + remainder regex
	echo -n "processing combination: $progress of 85"
elif [ "$verbose" == "true" ]; then
	# set user feedback variable
	progress=0
	echo -n "processing combination: $progress of 47"
fi

for letter in $letters; do
	# purge any files of size 0
	for file in $(ls $SCRATCHDIR1/$letter/*); do
		if [ -s "$file" ]; then
			:
		else
			rm $file
		fi
	done
	# run unify.pl or alternative legacy NSP script
	if [ "$unify_version" == "unify.pl" ]; then
		unify.pl -q $doc_count $SCRATCHDIR2/combined.$letter $SCRATCHDIR1/$letter/
	else
		if [ -z "$doc_count" ]; then
				:
		else
			doc_count="--filecount"
		fi
		$unify_version $doc_count --set_freq_combo $TMPfreqfile --ngram $nsize --destination $SCRATCHDIR2/combined.$letter --input_dir $SCRATCHDIR1/$letter/
	fi
	if [ "$verbose" == "true" ] && [ -n "$big" ]; then
		(( progress += 1 ))
		if [ $progress -gt 10 ]; then
			echo -en "\b\b\b\b\b\b\b\b\b $progress of 85"
		else
			echo -en "\b\b\b\b\b\b\b\b $progress of 85"
		fi
	elif [ "$verbose" == "true" ]; then
		(( progress += 1 ))
		if [ $progress -gt 10 ]; then
			echo -en "\b\b\b\b\b\b\b\b\b $progress of 47"
		else
			echo -en "\b\b\b\b\b\b\b\b $progress of 47"
		fi
	fi
done

if [ "$verbose" == "true" ]; then
	echo " "
fi



# put final list together
if [ "$verbose" == "true" ]; then
	echo "assembling final list ..."
fi
cat $SCRATCHDIR2/* | grep -v ^0$ > "$out"  # | grep -v ^[0-9]*$
# Lines consisting only of 0s need purging (they are put there by
# unify.pl at the beginning of each combined list) because if they occur
# within a list they cause errors.

# tidying up in the background (& runs these processes in the background)
rm -r $SCRATCHDIR1 $SCRATCHDIR2 > /dev/null &
}


######################
# consolidate function
######################
consolidate ( ) {
###
# This function takes as input lists of n-grams in which some n-grams
# (but possibly not their frequencies) are identical. It outputs a list
# in which the frequencies of identical n-grams are consolidated.
# 
#
# OPTIONS: -v verbose
#		   -b use the 84-way split (otherwise 48-way split is used)
# !!! first argument must be output file name !!!
# !!! subsequent arguments must be n-gram lists to be combined !!!
###

# analyse options


local OPTIND
while getopts nqrs:v opt
do
	case $opt	in
	n)	sort_by_n='-k2,2nr -k1,1'
		;;
	q)	verbose=
		;;
	r)	replace=true
		;;
	s)	suffix=".$OPTARG"
		;;
	v)	verbose=true
		;;
	esac
done

shift $((OPTIND -1))

# set document count handling
if [ "$doc_count" == "-d" ]; then
	:
else
	no_document_count=true
fi



# putting name of input file in variable $list
list=$1

### for debugging purposes
#echo "list is $list"
#echo "TMPFILE is $TMPFILE"
###
	
# sort and move list into memory (i.e. into a variable)
#copied_list="$SCRATCHDIR/$(basename $list).sorted"
new_list="$SCRATCHDIR/$(basename $list).new"
if [ "$verbose" == "true" ]; then
	echo "sorting ... (this can take a while)"
fi

# now tidy and sort list
copied_list=$(sed -e "s/$separator\([0-9]*\)  /$separator	\1	/g" -e "s/$separator\([0-9]*\) $/$separator	\1/g" -e 's/ $//g' -e 's/	/•/g' $list | grep -v '^[0-9]*$' | eval $korean sort)


# check if source list has document count 
# (i.e. check for a third column with an integer greater than 0)
if [ "$(head -2 $copied_list | tail -1 | cut -f 3)" -ge 0 ]; then
	:
else
	nodoc=true # list is originally supplied without doc counts
	if [ "$verbose" == "true" ]; then
		echo "lists without document count detected"
	fi
fi 2> /dev/null

	
# cut off document count if -n option is active and list has a doc-count
# this is an unlikely scenario, but just in case
if [ "$no_document_count" == "true" ] && [ -z "$nodoc" ]; then
	if [ "$verbose" == "true" ]; then
		echo "cutting out document counts..."
	fi
	copied_list=$(echo "$copied_list" | cut -d '•' -f 1-2)
fi
	
	
if [ "$verbose" == "true" ]; then
	# define variable with total lines in list
	total=$(echo "$copied_list" | wc -l | sed 's/ *\([0-9]*\).*/\1/g')
	echo -n "consolidating n-grams. Progress:   0% "
fi
	
	
	
# initiate some variables
total_freq=0
previous_ngram=""
progress=0
	
# work out how document counts should be treated
if [ -z "$no_document_count" ]; then # doc count is required
	if [ -z "$nodoc" ]; then # doc count is present in input
		mode="max" # doc count should be the highest value among those
				   # being consolidated
	else
		mode="dupl" # doc count should be the number of duplicates being
		            # consolidated
	fi
else
		mode="none" # no doc count required
fi
	
# go through list line by line
for line in $(echo "$copied_list"); do

	# keep track of line count to decide when to write buffer
	((lines +=1))
	
	# produce progress information to show to user
	if [ "$verbose" == "true" ]; then
		((progress +=1))
		((report +=1))
		# report only once every 10,000 lines
		if [ "$report" -gt 10000 ]; then
			if [ "$(( $progress * 100 / $total))" -lt "10" ]; then
				echo -en "\b\b\b $(( $progress * 100 / $total))%"
			else
				echo -en "\b\b\b\b $(( $progress * 100 / $total))%"
			fi
			report=0
		fi
	fi
	
	# set variables for current line
	IFS='•' read -a in <<< "$line"
	#current n-wc -gram is then ${in[0]}
	#freq of current n-gram is then ${in[1]}
	#and any current document frequency is then ${in[2]}
		
		
	if [ "${in[0]}" == "$previous_ngram" ]; then
		(( total_freq += ${in[1]} ))
		case $mode in
			max)	acc_doc_freqs="$acc_doc_freqs ${in[2]}";;
			dupl)	(( acc_doc_freqs += 1 ))
		esac
	elif [ -z "$previous_ngram" ]; then # ie. if there is no previous n-gram
		previous_ngram="${in[0]}"
		total_freq=${in[1]}
		case $mode in
			max)	acc_doc_freqs=${in[2]};;
			dupl)	(( acc_doc_freqs += 1 ))
		esac
	else # i.e. if a new n-gram is encountered
		case $mode in
			max)	# work out the highest doc count in acc_doc_freqs
					max=0
					for count in $acc_doc_freqs; do
						val=$count
						if [ $val -gt $max ]; then
							max=$val
						fi
					done
					# write to buffer
					buffer+=$"$previous_ngram	$total_freq	$max "
					# reset acc_doc_freqs
					acc_doc_freqs=${in[2]}
					;;
			dupl)	# write to buffer
					buffer+=$"$previous_ngram	$total_freq	$acc_doc_freqs "
					# reset acc_doc_freqs
					acc_doc_freqs=1
					;;
			none)	# write to buffer
					buffer+=$"$previous_ngram	$total_freq "
		esac
		# shift {in[0]} to previous_ngram
		previous_ngram="${in[0]}"
		# shift {in[1]} to total_freq
		total_freq="${in[1]}"
	fi
	
	# write buffer every 50,000 lines
	if [ $lines -gt 50000 ]; then
		# write buffer to file
		echo "$buffer" | tr ' ' '\n' >> $TMPFILE$suffix
		# empty buffer
		buffer=
		# reset lines count
		lines=0
	fi
	
	
	
done

# write last line
case $mode in
	max)	# work out the highest doc count in acc_doc_freqs
		max=0
		for count in $acc_doc_freqs; do
			val=$count
			if [ $val -gt $max ]; then
				max=$val
			fi
		done
		# write to new list
		buffer+=$"$previous_ngram	$total_freq	$max "
		# reset acc_doc_freqs
		acc_doc_freqs=${in[2]}
		;;
	dupl)	# write to new list
		buffer+=$"$previous_ngram	$total_freq	$acc_doc_freqs "
		# reset acc_doc_freqs
		acc_doc_freqs=1
		;;
	none)	# write to new list
		buffer+=$"$previous_ngram	$total_freq "
esac

# write remaining buffer to file
echo "$buffer" | tr ' ' '\n' >> $TMPFILE$suffix

# make sure 100% completion is reported
if [ "$verbose" == true ]; then
	echo -en "\b\b\b\b 100%"
fi

}





##############################end define functions#############################


# set default value for variable small to false
small=false

# analyse options
while getopts hbdsvij:kumnV opt
do
	case $opt	in
	d)	doc_count="-d"
		;;
	h)	help
		exit 0
		;;
	b)	big=true
		if [ "$verbose" == "true" ]; then
			echo "running 84-way split version"
		fi
		;;
	s)	small=true
		;;
	v)	verbose=true
		;;
	i)	discard_indiv_lists=true
		;;
	k)	korean="LC_ALL='ko-KR'"
		;;
	j)	unify_version=$OPTARG
		;;	
	u)	retain_untidy=true
		;;
	m)	cons_used=true
		;;
	n)	absolutely_no_statistics=true
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version."
echo "This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>."
		exit 0
		;;
	esac
done

shift $((OPTIND -1))

# check if 1 argument was supplied
if [ $# != 1 ] ; then
	echo "Error: please supply source directory as argument, script terminated without changing any files" >&2
	exit 1
fi

# check if both -m and -b options are active
if [ "$cons_used" == "true" ] && [ "$big" == "true" ]; then
	echo "-b option overrides -m option. -m option will be turned off" >&2
	cons_used=
fi

# check if source directory exists
if [ -d "$1" ] ; then
	:
else
	echo "$1 does not appear to be a valid directory" >&2
	exit 1
fi


# obtain full path to source directory (if not already specified)
# and put it in source_dir variable
cd "$1"
source_dir="$(pwd)"
cd - > /dev/null


# set separator and
# set nsize variable by checking first input list (unless unify.pl used)
line=$(head -2 "$source_dir/"$(ls "$source_dir" | head -1) | tail -1 )|| exit 1
nsize=$(echo $line | awk '{c+=gsub(s,s)}END{print c}' s='<>') 
if [ "$nsize" -gt 0 ]; then
	separator='<>'
else
	nsize=$(echo $line | awk '{c+=gsub(s,s)}END{print c}' s='·')
	if [ "$nsize" -gt 0 ]; then
		separator='·'
	else
		nsize=$(echo $line | awk '{c+=gsub(s,s)}END{print c}' s='_')
		if [ "$nsize" -gt 0 ]; then
			separator='_'
		else
			echo "unknown separator in $line" >&2
			exit 1
		fi
	fi
fi

if [ "$verbose" == "true" ]; then
	echo "separator is $separator"
fi


# inform user
if [ "$verbose" == "true" ]; then
	echo "processing $nsize - gram lists ..."
fi

# check if source dir contains at least 2 files ending in .list
# if not, check if no files ending in .list are in the source dir
# if that isn't the case either, check if there is 1 file and set the variable
#  'single_list' to true
no_of_files=$(ls "$source_dir" | egrep "(\.lst|\.list)" | wc -l)
if [ "$no_of_files" -lt 1 ]; then
	echo "no lists to be combined found in $source_dir. Lists must end in .lst or .list" >&2
	exit 1
elif [ "$no_of_files" -eq 1 ]; then
	single_list=true
fi

# check if there are other files present in the source dir
if [ "$no_of_files" -ne "$(ls "$source_dir" | wc -l)" ] ; then
	echo "ERROR non-conforming files were detected in the $source_dir. Only files ending in .list or .lst can be processed with this script." >&2
	exit 1
fi



# if the -n option is active, set statistics_requested to false,
# otherwise check if -n option could be on
if [ "$absolutely_no_statistics" == "true" ]; then
	statistics_requested=
else
	# check if input files contain statistics numbers by checking how
	# many spaces there are on line two of the first input file
	# if there's only 1 space, there are no statistics numbers
	spaces=$(head -2 "$source_dir/"$(ls "$source_dir" | head -1) | tail -1 | awk '{c+=gsub(s,s)}END{print c}' s=' ')

	case $spaces in
		1)	:
		;;
		0)	echo "ERROR: input lists appear to be in an unkown format" >&2
			exit 1
		;;
		*)	statistics_requested=true
		;;
	esac
fi

# check if file contains mostly Korean and if so, flip -k option ON
# if not on already
if [ -z "$korean" ]; then
	if [ -n "$(head -2 "$source_dir/"$(ls "$source_dir" | head -1) | tail -1 | grep -m 1 '[가이를을다습서'])" ]; then
		korean="LC_ALL='ko-KR'"
		if [ -n "$verbose" ]; then
			echo "Hangeul data detected"
		fi
	fi
fi


# create name and path for temporary output file
TMPFILE=$(mktemp -t combinationXXX) || TMPFILE=${TMPDIR-/tmp/}combination.$$
# this uses mktemp to create a path to a random filename with 'combination'
# in it, using the path given in the TMPDIR variable and then puts the
# path into the TMPFILE variable. If this fails, a path is put into the 
# TMPFILE variable which takes the TMPDIR variable as path (or else the
# /tmp directory) and 'combination' dot process number as file name.
# delete the actual file, so we don't get the error that the OUTFILE
# exists
rm $TMPFILE

# statistics can only be calculated reliably if -s option is active.
# so if it is not active, give warning and switch to no statistics
if [ "$statistics_requested" == "true" ] && [ "$small" == "false" ]; then
	echo "numbers for assessing statistical measures of association can" >&2
	echo "only be computed if -s option is active. Proceeding without" >&2
	echo "calculation of those numbers." >&2
	statistics_requested=
fi

# if statistics are requested for 5-grams and above, inform user
# that that won't be done.
if [ "$statistics_requested" == "true" ] && [ $nsize -gt 4 ]; then
	echo 'statistics can only be calculated in n-grams up to 4-grams.' >&2
	echo 'processing without statistics numbers...' >&2
	statistics_requested=
fi


# produce temporary frequency-combination file for use with --set_freq_combo
# option of unify.pl
# make temp file
if [ "$unify_version" == "unify.pl" ] && [ -z "$statistics_requested" ]; then
	:
else
	TMPfreqfile=$(mktemp -t freqXXX) || TMPfreqfile="/tmp/$$.freq"

	# write appropriate freqency combinations to it
	# if statistics are requested, we have to write out a lot
	if [ "$statistics_requested" == "true" ]; then
		case $nsize in
		0)	echo 'ERROR: n-grams size could not be determined' >&2
			exit 1
		;;
		1)	echo '0 ' > $TMPfreqfile
		;;
		2)	echo '0 1 ' > $TMPfreqfile
			echo '0 ' >> $TMPfreqfile
			echo '1 ' >> $TMPfreqfile
		;;
		3)	echo '0 1 2 ' > $TMPfreqfile
			echo '0 ' >> $TMPfreqfile
			echo '1 ' >> $TMPfreqfile
			echo '2 ' >> $TMPfreqfile
			echo '0 1 ' >> $TMPfreqfile
			echo '0 2 ' >> $TMPfreqfile
			echo '1 2 ' >> $TMPfreqfile
		;;
		4)	echo '0 1 2 3 ' > $TMPfreqfile
			echo '0 ' >> $TMPfreqfile
			echo '1 ' >> $TMPfreqfile
			echo '2 ' >> $TMPfreqfile
			echo '3 ' >> $TMPfreqfile
			echo '0 1 ' >> $TMPfreqfile
			echo '0 2 ' >> $TMPfreqfile
			echo '0 3 ' >> $TMPfreqfile
			echo '1 2 ' >> $TMPfreqfile
			echo '1 3 ' >> $TMPfreqfile
			echo '2 3 ' >> $TMPfreqfile
			echo '0 1 2 ' >> $TMPfreqfile
			echo '0 1 3 ' >> $TMPfreqfile
			echo '0 2 3 ' >> $TMPfreqfile
			echo '1 2 3 ' >> $TMPfreqfile
		;;
		*)	echo 'statistics can only be calculated for bigram, trigram and quadgram lists'  >&2; exit 1
		;;
		esac
	else
		# if statistics numbers are not requested, things are easier, we just
		# deduct one from the nsize variable and then put the numbers from 0 to 
		# that number, followed by a space in the TMPfreqfile file.
		# if unify.pl is used, this isn't necessary, of course
		TMPfreq=$(( $nsize - 1 ))
		eval echo {0..$TMPfreq} > $TMPfreqfile
	fi
fi

# check if 'single_list' was turned on
if [ "$single_list" == "true" ] ; then
	mv "$source_dir/"*.list $TMPFILE
else


	# check for -s option
	if [ "$small" == "true" ] ; then
	#########################################run small version##################
	
		# inform user
		if [ "$verbose" == "true" ]; then
			echo "performing combination on $(ls "$source_dir" | egrep "(\.lst|\.list)" | wc -l) files."
		fi
	
		# run unify.pl or alternative legacy NSP script if statistics requested
		# or if a unify_version is especially requested,
		# otherwise use consolidate function
		
		# if both statistics are requested and unify.pl, run unify.pl w/stats
		if [ "$unify_version" == "unify.pl" ] && [ "$statistics_requested" == "true" ]; then
			unify.pl $doc_count -s $TMPfreqfile $TMPFILE "$source_dir"
		# if statistics are requested, also run unify.pl w/stats
		elif [ "$statistics_requested" == "true" ]; then
			unify.pl $doc_count -s $TMPfreqfile $TMPFILE "$source_dir"
		# if unify.pl specifically requested or -m inactive,
		# run unify.pl w/o stats
		elif [ "$unify_version" == "unify.pl" ] || [ -z "$cons_used" ]; then
			unify.pl $doc_count $TMPFILE "$source_dir"
		# if a different version specifically requested, run that version
		elif [ -n "$unify_version" ]; then
			unify_version="unify.pl"
			if [ -z "$doc_count" ]; then
				:
			else
				doc_count="--filecount"
			fi
			$unify_version $doc_count --set_freq_combo $TMPfreqfile --ngram $nsize -destination $TMPFILE -count "$source_dir/"*.l*st 
		else
			# else run consolidate function
			
			# create scratch directory
			SCRATCHDIR=$(mktemp -dt combinationXXX) 
			# if mktemp fails, use a different method to create the SCRATCHDIR
			if [ "$SCRATCHDIR" == "" ] ; then
				mkdir ${TMPDIR-/tmp/}combination.1$$
				SCRATCHDIR=${TMPDIR-/tmp/}combination.1$$
			fi
			
			# put all input lists into a single file
			for file in $(ls "$source_dir"); do 
				cat "$source_dir/"$file >> $SCRATCHDIR/catfile
			done
			
			# now consolidate
			consolidate -n $SCRATCHDIR/catfile
		fi
	
	elif [ -n "$cons_used" ]; then
	######################run generic consolidate version####################

		# create scratch directory
		SCRATCHDIR=$(mktemp -dt combinationXXX) 
		# if mktemp fails, use a different method to create the SCRATCHDIR
		if [ "$SCRATCHDIR" == "" ] ; then
			mkdir ${TMPDIR-/tmp/}combination.1$$
			SCRATCHDIR=${TMPDIR-/tmp/}combination.1$$
		fi
			
		# put all input lists into a single file
		for file in $(ls "$source_dir"); do 
			grep '^[A-Ma-g]' "$source_dir/"$file >> $SCRATCHDIR/catfile1
			grep -v '^[A-Ma-g]' "$source_dir/"$file >> $SCRATCHDIR/catfile2
		done
		
		# now consolidate
		consolidate -nqs A $SCRATCHDIR/catfile1 > /dev/null &
		consolidate -ns B $SCRATCHDIR/catfile2
		
		# wait for A to finish
		if [ "$verbose" == "true" ]; then
			echo ""
			echo "waiting for parallel process to complete..."
		fi
		wait
		
		# merge
		cat $TMPFILE.A $TMPFILE.B > $TMPFILE
	
	else
	##############################run mid or big version####################
	
		# inform user
		if [ "$verbose" == "true" ]; then
			echo "performing combination on $no_of_files files in $source_dir ..."
		fi
		
		# if no unify-version is set, set to unify.pl
		if [ -z "$unify_version" ]; then
			unify_version="unify.pl"
		fi
		

		if [ "$verbose" == "true" ]; then
			if [ "$big" == "true" ]; then
				alphabet-split -vb $TMPFILE $(ls "$source_dir" | \
				egrep "(\.lst|\.list)" )
			else
				alphabet-split -v $TMPFILE $(ls "$source_dir" | \
				egrep "(\.lst|\.list)" )
			fi
		else
			if [ "$big" == "true" ]; then
				alphabet-split -b $TMPFILE $(ls "$source_dir" | \
				egrep "(\.lst|\.list)" )
			else
				alphabet-split $TMPFILE $(ls "$source_dir" | \
				egrep "(\.lst|\.list)" )
			fi
		fi
	######################################################################
	fi

fi

### check name of source_dir and put it in the variable dir_name
dir_name=$(basename "$source_dir")
# if it was '.' , then replace it with pwd
if [ "$dir_name" == "." ] ; then 
	dir_name=$(basename $(pwd))
fi


# get path to dir above source_dir
source_dir_plus=$(echo "$source_dir" | sed "s/\/$dir_name//")

# check if individual lists should be retained (if not, delete),
# and rename the source_dir
if [ "$discard_indiv_lists" == "true" ] ; then
	rm -r "$source_dir"
else
	mv "$source_dir" "$source_dir_plus/indiv_lists_$dir_name"
fi


# check if planned name for output list is taken and adjust accordingly
add_to_name "$source_dir_plus/"$(echo "$dir_name" | cut -d '.' -f 1,2).lst


# delete frequency combination file, if it exists
if [ -n "$TMPfreqfile" ] && [ -e $TMPfreqfile ] ; then
	rm $TMPfreqfile
fi


# if consolidation function was used (rather than a form of unify.pl)
if [ -n "$cons_used" ]; then
		# sort final list
		if [ "$verbose" == "true" ]; then
			echo " "
			echo "sorting output list ..."
		fi
	
		eval $korean sort -k2,2nr -k1,1 $TMPFILE | sed '/^$/d' > "$output_filename"
		
		# tidy up in the background
		rm -r $TMPFILE > /dev/null &
		rm -r $SCRATCHDIR > /dev/null &
else
	# check if statistics were requested or -u option is active
	# and move untidy list to proper location
	if [ "$statistics_requested" == "true" ]; then
		mv "$TMPFILE" "$output_filename"
	elif [ "$retain_untidy" == "true" ]; then
		mv "$TMPFILE" "$output_filename.untidy"
	else
		# rename tidied output list and move it (if it exists)
		tidy "$TMPFILE"
		mv "$TMPFILE.tidy" "$output_filename"
		rm -r $TMPFILE > /dev/null &
	fi
fi





if [ "$verbose" == "true" ]; then
	echo "output directory written to $output_filename"
	echo "start:		$ID"
	echo "completion:	$(date +"%e-%b-%H:%M:%S")"
fi

