#!/bin/bash -

##############################################################################
# multi-nList.sh (c) A Buerki 2013
version="0.9.2"
copyright="Copyright 2013 Andreas Buerki"
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
# DESCRRIPTION: wrapper for nlist (NGP) or count.pl (NSP) adding efficiency in
#				for handling files in some circumstances.
# SYNOPSIS: cou.sh [OPTIONS] OUTDIR INDIR N-SIZE
# DEPENDENCIES: list.pl (NGP) or count.pl (NSP) or versions of those
# UNDOCUMENTED OPTIONS (experimental):
#	-C	create high freq per doc list
#	-i  process files in iso8859-1 encoding rather than unicode
#	
#	
#	
####
# dependencies: these external scripts need to installed
# • list.pl (NSP)
####
# CHANGELOG
# 
# DATE			VERSION			CHANGE
# 2013-12-26	0.9.2			adjusted progress reporting to use (( ))
##############################################################################

### defining important variables
path_to_freq_combo_file="$HOME/CHTK"

#################################define functions#############################

# define help function
help ( ) {
	echo "
Usage: $(basename $0) [OPTIONS] [N-SIZE] OUT-DIRECTORY IN-DIRECTORY
Example: $(basename $0) -e Bel 3 test_folder3 .
Options: 
-a  produces lists with the full set of numbers used to calculate statistics of association strength
-d  produces ONE output list per ONE input document
-e ARG causes the output dir to have the ARG prepended to its name
-f ARG causes the output dir to have the ARG appended to its name
-H  replace hyphens (-) with 'HYPH' in output lists
-h  displays this help message
-l  produces n-grams across line breaks
-n N gram size can also be specified with this option if that is prefererred
-o FILE supply a stoplist
-p SEP set the separator symbol to be used between n-gram constituents to SEP
-t FILE supply a custom token definition file (-t show = display token def)
-v  verbose
-V  display version information
-w N  sets window size to N
note: if neither an -n option nor [N-SIZE] is provided, bigrams will be produced.
"
}

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
if [ -a $1 ]; then
	add=-
	count=1
	while [ -a $1-$count ]
		do
		(( count += 1 ))
		done
else
	count=
	add=
fi
output_filename=$(echo "$1$add$count")

}

##############################end define functions#############################

# set default value for $sep
sep="·"

# analyse options
while getopts ac:de:f:hHiln:o:p:st:vVw: opt
do
	case $opt	in
	a)	stats=".s"
		;;
	c)	count_version=$OPTARG
		;;
	C)	create_highpd_list="true"
		;;
	d)	perdoc="per_doc"
		;;
	e)	prefix="$OPTARG."
		;;
	f)	affix=".$OPTARG"
		;;
	h)	help
		exit 0
		;;
	H)	hyphen=true
		;;
	i)	iso=true
		;;
	l)	newline='--newline'
		;;
	n)	nsize=$OPTARG
		;;
	o)	stoplist="$OPTARG"
		stop_option="--stop $stoplist"
		stop_name=".$(basename $stoplist)"
		;;
	p)	separator_option="-p $OPTARG"
		sep="$OPTARG"
		;;
	t)	tokendef=$OPTARG
		if [ "$tokendef" == "show" ]; then
			list.pl -t show
			exit 0	
		fi
		token_option="--token $tokendef"
		token_name=".$(basename $tokendef)"
		;;
	v)	verbose=true
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>."
		;;
	w)	win_size=$OPTARG
		window_option="--window $win_size"
		win_name=".w$win_size"
		export win_size
		;;
	*)	exit 0
		;;
	esac
done

shift $((OPTIND -1))

# check if right number of args remain
if [ $# -lt 2 ]; then
	echo "ERROR: insuficient number of arguments supplied" >&2
	help
	exit 1
fi
# assign arguments to their proper variables
if [ -d "$1" ]; then
	outdir=$1
	indir=$2
elif [ "$1" -le 10 ]; then
	nsize=$1
	outdir=$2
	indir=$3
else
	echo "ERROR $1 is neither a directory nor number smaller than 10" >&2
	exit 1
fi

# if nsize not set, set to 2
if [ -z "$nsize" ]; then
	nsize=2
fi

# check indir
if [ -d "$indir" ]; then
	:
else
	echo "$indir either does not exist or is not a directory" >&2
	exit 1
fi
# checking outdir
if [ -d "$outdir" ]; then
	:
else
	echo "$outdir either does not exist or is not a directory" >&2
	exit 1
fi

# check if count_version variable has a value assigned
# if no value assigned, assign standard $count_version
if [ -z "$count_version" ] ; then
	count_version=list.pl
fi

# check if count_version is accessible
if [ -x "$(which $count_version)" ]; then
	:
else
	echo "$count_version not found or executable on this machine. Please install and run $0 again." >&2
	exit 1
fi

# check if -i option active
if [ "$iso" == 'true' ] ; then
	:
# if an iso-only version of count.pl is used, set encoding to iso
elif [ "$count_version" == 'count.pl' ] || [ "$count_version" == 'count_new.pl' ] ; then
	enc='--encoding iso-8859-8'
elif [ "$count_version" != 'list.pl' ]; then
	enc='--encoding utf8'
fi

# make sure $separator_option isn't set if it isn't compatible with $count_version
if [ "$count_version" == "list.pl" ]; then
	:
else
	separator_option=
fi


# define some initial variables
orig_dir=$(pwd)
progress=0
mkdir $outdir 2> /dev/null


# sort out freq_combo
# if meant to run with plain n-gram frequencies
if [ -z $stats ]; then
	if [ "$verbose" == "true" ]; then
		echo "(running w/o stats)"
	fi
	if [ "$count_version" == "list.pl" ]; then
		:
	else
		# check if freq_file was supplied at default location
		if [ -e "$path_to_freq_combo_file/freq$nsize" ]; then
			# construct appropriate option
			freq_option="--set_freq_combo $path_to_freq_combo_file/freq$nsize"
		else
			echo "$count_version does not have an automatic option to run without the maximum possible frequency combinations. Run $count_version direclty, making use of the options supplied."
			exit 1
		fi
	fi
# if meant to run with full frequency combinations
elif [ "$count_version" == "list.pl" ]; then
	freq_option="-a"
fi

# sort out nsize vs ngram option
if [ "$count_version" == "list.pl" ]; then
	n_option="-n $nsize"
else
	n_option="--ngram $nsize"
fi

# create outdir
if [ -z "$perdoc" ]; then
	perdoc="comp"
fi
mkdir $outdir/$prefix$nsize.$perdoc$stats$stop_name$token_name$win_name$affix|| exit 1

outfolder=$prefix$nsize.$perdoc$stats$stop_name$token_name$win_name$affix
export outfolder



# check -d option
if [ "$perdoc" == "per_doc" ] ; then
####################running per_doc mode###############################

	total=$(ls $indir | wc -l)
	if [ "$verbose" == "true" ]; then
		echo -n "progress:   0% "
	fi

	# now process files in indir
	for file in $indir/*
	do
		$count_version $enc $n_option $window_option $token_option $stop_option $freq_option $newline $separator_option $outdir/$outfolder/$(basename $file).lst $file

		if [ "$hyphen" == "true" ]; then
			sed 's/-/HYPH/g' $outdir/$outfolder/$(basename $file).lst > $outdir/$outfolder/$(basename $file).lst.tmp
			mv $outdir/$outfolder/$(basename $file).lst.tmp $outdir/$outfolder/$(basename $file).lst
		fi
		((progress +=1))
		if [ "$verbose" == "true" ]; then
			if [ "$(($progress * 100 / $total))" -lt "10" ]; then
				echo -en "\b\b\b $(($progress * 100 / $total))%"
			else
				echo -en "\b\b\b\b $(($progress * 100 / $total))%"
			fi
		fi
		done
	echo " "

	if [ "$verbose" == "true" ]; then
		echo $progress lists created.
	fi

	if [ "$verbose" == "true" ]; then
		echo $progress lists created \in $outdir/$outfolder
	fi
	export nsize
	export outdir
	
	# create high-per-doc-freq.lst
	if [ -n "$create_highpd_list" ]; then
		cd $outdir/
		# create directory for high-per-doc freq log, 
		# ignore error message if it exists
		mkdir high-per-doc-freq_lists 2> /dev/null

		# create name for high-per-doc freq log
		cd high-per-doc-freq_lists
		add_to_name $(echo $nsize.high-per-doc-freq.lst)
		cd ..

		cd $outfolder/

		egrep "$sep(1[789]) $|$sep(2[0123456789]) $|$sep([3456789][0123456789]) $" * > ../high-per-doc-freq_lists/$output_filename

		# delete the log if empty
		if [ -s ../high-per-doc-freq_lists/$output_filename ] ; then
			:
		else
			rm ../high-per-doc-freq_lists/$output_filename
		fi

		cd "$orig_dir"
	fi

else
######################### without -d option (not per doc) ########


	total=$(ls | wc -l)
	if [ "$verbose" == "true" ]; then
		echo "progressing..."
	fi
	
	$count_version $enc $n_option $window_option $token_option $stop_option $freq_option -newLine $separator_option $outdir/$outfolder/$nsize.lst $indir/*

	if [ "$hyphen" == "true" ]; then
		sed 's/-/HYPH/g' $outdir/$outfolder/$nsize.lst > $outdir/$outfolder/$nsize.lst.tmp
		mv $outdir/$outfolder/$nsize.lst.tmp $outdir/$outfolder/$nsize.lst
	fi

	cd "$orig_dir"

	if [ "$verbose" == "true" ]; then
		echo "$nsize.lst list created in $outdir/$outfolder"
	fi
	export nsize
	export outdir
fi
