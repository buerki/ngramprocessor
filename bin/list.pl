#!/usr/bin/perl -w

##############################################################################
# list.pl
# based on NSP's count.pl
our $VERSION = '0.05';
####
# Copyright 2013, Andreas Buerki
# Copyright 2000-2003, Ted Pedersen and Amruta Purandare
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
# CHANGELOG
# 
# DATE			VERSION			CHANGE
# 2013-11-13	0.05			made calculation of plain n-gram frequencies the
#								default behaviour, -a to calculate all freq comb
#								added binmode(STDOUT, ":$opt_encoding") to have 
#								perl display all text as per the chosen encoding
#								retired the following functions/options:
#								- recurse, nontoken, directorySearch
#								changed default tokens to \w+-\'&§%\/\+°ß
#								made separators flexible (-p option)
#								retired the following options:
#								- recurse histogram extended remove nontoken
#								enforced 'use strict' and 'use warnings'
#								
#								
#								
# 2013-10-29	0.04			changed $opt_encoding to UTF-8 as default
#								renamed script nlist.pl
# 2011-10-25	0.03			added encoding option
#								made sure all in- and output is encoded 
#								according to the encoding option setting
# 2010-01-02	0.01			added 'use locale'
#
# 2003-07-01	v. 0.57 of count.pl N-gram Statistics Package as initial code 
#								base; http://search.cpan.org/dist/Text-NSP/
# 
###############################################################################


#-----------------------------------------------------------------------------
#                              Start of program
#-----------------------------------------------------------------------------

### require Perl 5.12 minimally for good unicode support
use v5.12;

### include external modules
use strict;
use warnings;
use locale;
use Encoding;

# set encoding of this code to utf-8
use utf8;

# use Getopt::Long to parse options (bundling, i.e. -ex for -e -x is allowed)
use Getopt::Long qw(:config bundling_override);

# use Ngramprocessor module
use Lingua::Ngramprocessor;

###############################declaring variables#############################

# set very important variables:
our $tokendef="-\'&§%\/\+°ß"; # this is in addition to alphanumeric characters (\w+)

# declare variables
our $opt_verbose;
our $opt_version;
our $opt_help;
our $opt_frequency; # used to hold a desired frequency cut-off
our $opt_window;
our $opt_stop; # used to hold (path to) stoplist file
our $opt_newline; 
our $opt_token; # used to hold path to token definition file
our $opt_nsize; # used to hold desired ngram size
our $opt_set_freq_combo; # used to hold path to customised freq combo file
our $opt_display_freq_combo; 
our $opt_all_freq_combos;
our $opt_separator;

our $nsize; # to store n of the n-gram
our $cutOff; # to store cut-off frequency
our $windowSize; # to store requested window size
our @freq_combo; # array that holds frequency combinations
our $freq_combo; # ref to array @freq_combo
our $combIndex; # stores number necessary for displaying $freq_combo
our $out_file; # output will be written to the filename in this variable
our @input_files; # array to store input file(s)
our $input_files; # ref to array @input_files
our @permutations; # array to hold combination of words in window
our $windex; # keeping the index of the current window in n-gram extraction
our $tokenizerRegex; # token definitions kept here
our $stop_regex; # to hold stoplist regex
our %ngramFreq; # the n-gram frequency hash
our %frequencies; # a secondary hash holding frequencies

# define variables
our $ngramTotal = 0; # stores the total number of ngrams globally
our $separator ="·"; # set the default separator value
our $opt_encoding = 'utf8';
binmode(STDOUT, ":$opt_encoding"); # utf8 or iso-8859-1
#################################define functions##############################

# function to output a minimal usage note when the user has not provided any
# commandline options
sub usage
{
    print STDERR "Usage: $0 [OPTIONS] DESTINATION {SOURCE+ | SOURCEDIRECTORY}\n";
    askHelp();
}

# function to output help messages for this program
sub help
{
    print "Usage: $0 [OPTIONS] OUT-FILE {IN-FILE+ | IN-DIRECTORY}\n\n";
	  
    print "OPTIONS:\n\n";
    
    print " -a  --all_freq_combos use all possible frequency combinations \n";
    print "                     (required if NSP's statistics.pl is to be used).\n\n";
	  
    print " -d --display_freq_combo \n";
    print "                     Prints out the frequency combinations used.\n";
    print "                     If frequency combinations have been\n";
    print "                     provided through --set_freq_combo switch above\n";
    print "                     these are output; otherwise the default\n";
    print "                     combinations being used are output.\n\n";  

    print " -e --encoding ENC   Handles input and output files with the given\n";
    print "                     character encoding. Default is utf8, but\n";
    print "                     if necessary a different encoding can be\n";
    print "                     forced using this option. A suitable token\n";
    print "                     definition must also be supplied as the\n";
    print "                     standard token definition is in utf8 (use -t)\n";
    print "                     Non-utf8 is not generally recommended and\n";
    print "                     here only provided for compatibility with\n";
    print "                     legacy data. It is better to convert the\n";
    print "                     data to utf8 as non-utf8 encodings have not\n";
    print "                     been widely used in testing.\n\n";

    print " -f --frequency N    Does not display n-grams that occur less\n";
    print "                     than N times.\n\n";
    	  
    print " -h --help           Prints this help message.\n\n";
	  
    print " -l --newline        Creates n-grams spanning across the new-line\n";
    print "                     character. By default those are barred\n\n";    
    
	print " -n --ngram N       Creates n-grams of N tokens each. N = 2 by\n";
    print "                     default.\n\n";
	    
    print " -o --stop FILE      Removes n-grams containing at least one (in\n"; 
    print "                     OR mode) or all stop words (in AND mode).\n"; 
    print "                     Stop words should be declared as Perl Regular\n"; 
    print "                     expressions in FILE.\n\n"; 
    
    print " -p --separator SEP  Uses SEP instead of the default separator to\n";
    print "                     separate constituents of n-grams. By default\n";
    print "                     the middledot (·) is used (<> if iso encoded\n";
    print "                     files are processed.\n\n";

    print " -t --token FILE     Uses regular expressions in FILE to create\n";
    print "                     tokens. By default two regular expressions\n";
    print "                     are provided (see manual).\n\n";
    
    print " -s  --set_freq_combo FILE \n";
    print "                     Uses the frequency combinations in FILE to\n";
    print "                     decide which combinations of tokens to\n";
    print "                     count in a given n-gram. By default, all\n";
    print "                     combinations are counted.\n\n";
	  
    print " -v --verbose        Outputs to stderr information about\n";
    print "                     current program status.\n\n";
	  
    print " -V --version        Prints the version number.\n\n";
    
    print " -w --window N       Sets window size to N. Defaults to n-gram\n";
    print "                     size above.\n\n";
}

# function to output the version number
sub version
{
    print STDERR "$0      -        $VERSION\n";
    print STDERR "Copyright (C) 2013, Andreas Buerki\n";
    print STDERR "Copyright (C) 2000-2003, Ted Pedersen & Satanjeev Banerjee\n";
}

# function to output "ask for help" message when the user's goofed up!
sub askHelp
{
    print STDERR "Type $0 --help for help.\n";
}



# function to create the default frequency combinations to be computed
# and output
sub calculate_freq_combo_109 {
    my $i;
	my $required_nsize = shift;
	
    # first create the first index of the combo, that is the
    # combination that includes all the characters in the window

    $freq_combo[0][0] = $nsize;
    for ($i = 0; $i < $nsize; $i++) # starting value, condition, change
    {
        $freq_combo[0][$i+1] = $i; # loop runs as long as condition is true
    }
    $combIndex=1;
	$freq_combo = \@freq_combo; # make $freq_combo a ref to @freq_combo
    return $combIndex;
}

# function to read in the user supplied frequency combinations
sub read_freq_combo_file_109 {
    my $sourceFile = shift;

    # open the source file
    open (FREQ_COMBO_IN, "<:encoding($opt_encoding)", "$sourceFile" ) || die ("Couldnt open $sourceFile\n");

    # read in the freq combo's one by one into the @freq_combo array
    $combIndex = 0;
    while (<FREQ_COMBO_IN>) {
        s/^\s*//; # remove spaces at the beginning 
        s/\s*$//; # and the end
        my @tempArray = split(/\s+/); # put space-separated numbers in tempArray

        # first how many words make up this combination
        $freq_combo[$combIndex][0] = $#tempArray+1;

        # next the indices of the words. note that these indices
        # shouldnt exceed $nsize-1... we'll check for that here.
        my $i;
        for ($i = 1; $i <= $freq_combo[$combIndex][0]; $i++)
        {
            $freq_combo[$combIndex][$i] = $tempArray[$i-1];

            # check!
            if ($freq_combo[$combIndex][$i] >= $nsize)
            {
                printf STDERR ("Illegal index value at row %d column %d in file %s\n", $combIndex+1, $i, $sourceFile);
                exit;
            }
        }
        $combIndex++;
    }
    close(FREQ_COMBO_IN);
    
    $freq_combo = \@freq_combo; # make $freq_combo a ref to @freq_combo
    return $combIndex;
}


# function to process tokens
sub processToken
{
    my $token = shift; # a token is here a word
    our @window; # array to hold tokens in windows

    if ($nsize > 1)
    {
        # first put the word into the window array
        $window[$windex] = $token;
	
        # until we have enough to make our first ngram, just keep going!
        if ( $windex < $nsize-1 )
        {
            $windex++;
            return; # ends function here to return to where it was called
        }
	
        # otherwise, create the ngrams. our method here will be to create all
        # possible ngrams that END with the token that's just come in. thus we
        # shall avoid the pitfall of creating the same ngram twice (a 
        # possibility when windowSize > ngram).

        # we already have the permutations array; it is now needed.
	
        my $permutationsIndex = 0;
        my $i;
        while ($permutationsIndex <= $#permutations)
        {
            my $ngramString = "";
            my $okFlag = 1;
            for ($i = 0; $i < $nsize-1; $i++)
            {
                if ( $permutations[$permutationsIndex] < $windex )
                {
                    $ngramString .= $window[$permutations[$permutationsIndex]] . "$separator";
                }
                else { $okFlag = 0; }
                $permutationsIndex++;
            }
	       
            if (!$okFlag) { next; } # starting a new iteration of the loop

            $ngramString .= "$window[$windex]$separator";

            # that is our ngram then!
            # increment the ngramTotal
            $ngramTotal++;

            # and the ngram freq hash. Output ngrams are going to
            # be sorted on this hash. we shall not show this frequency
            # though... if this has to be shown, the corresponding combo
            # has to be in the loop below!
            $ngramFreq{$ngramString}++; # increases freq of this n-gram by one
            
            # now increment the various frequencies according to the
            # @freq_combo array...
            my @words = split /$separator/, $ngramString;
            my $j;
            for ($j = 0; $j < $combIndex; $j++)
            {
                my $tempString = "";
                my $k;
                for ($k = 1; $k <= $$freq_combo[$j][0]; $k++)
                {
                    $tempString .= "$words[$$freq_combo[$j][$k]]$separator";
                }
                $tempString .= $j;
                $frequencies{$tempString}++;
            }
        }

        # having dealt with all the new ngrams in this window,
        # increment the windex, if less than the size, or shift out
        # the first element of the array to make place for the next
        # word thats coming in!
	
        if ( $windex < $windowSize - 1 )    { $windex++; }
        else                                { shift @window; }
    }
    else # this is the case when ngram = 1
    {
        my $ngramString = $token . "$separator";
        $ngramFreq{$ngramString}++;
		my $tempString = $token . "$separator" . "0";
		$frequencies{$tempString}++;
        $ngramTotal++;
    }
}

# function to remove an ngram and adjust the various frequency counts
# appropriately
sub removeNgram
{
    my $ngramString = shift;

    # first reduce the ngram total by the frequency of this ngram
    $ngramTotal -= $ngramFreq{$ngramString};

    # get hold of the component words
    my @words = split /$separator/, $ngramString;

    # and reduce each combination frequency by the freq of this ngram
    my $j;
    for ($j = 0; $j < $combIndex; $j++)
    {
        my $tempString = "";
        my $k;
        for ($k = 1; $k <= $$freq_combo[$j][0]; $k++)
        {
            $tempString .= "$words[$$freq_combo[$j][$k]]$separator";
        }
        $tempString .= $j;
        $frequencies{$tempString} -= $ngramFreq{$ngramString};
        if ($frequencies{$tempString} <= 0)
        {
            delete $frequencies{$tempString};
        }
    }

    # finally remove this ngram
    delete $ngramFreq{$ngramString};
}


# Function to get input files from the arguments provided on the command line
sub get_input_files
{
	# process INDIR if given: if next argument exists and is a directory
	# read its content into the array @input_files and change to that directory
	if ( -d $_[0] ) {
		our $in_dir=$_[0];
		# read the filenames in input directory into the input_files array
		opendir DIR, "$in_dir"		or die "cannot open directory $in_dir: $!";
		@input_files = grep !/^\./, readdir DIR;
		@input_files = map "$in_dir/$_", @input_files;
		closedir DIR;
		# check if there's more than one file in the directory
		if ( $#input_files < 0 ) {
			print STDERR "ERROR: there must be at least one INFILE in the directory.\n";
	    	exit(1);
	    }
	    shift; # shift to the next arg if any
	    if ( defined $_[0] ) {
	    	print STDERR "ERROR: only one source directory should be provided, @_ will be ignored!\n";
		}
	}
	# process INFILE+
	# else read the remaining arguments, check if files exist and put names into
	# the @input_files array
	else {
		# if number of source files is < 1, abort
		if ( $#_ < 0 ) {
		print STDERR "ERROR: at least one INFILEs must be supplied.\n";
	    exit(1);
		}
		# iterate over source files
		foreach my $file (@_) {
			# check if file exists
			unless (-e $file) {
				print STDERR "ERROR: $file does not exist.\n";
				exit(1);
			}
		}
		# put arguments into the @input_files array
		@input_files = @_;
	}
	# create ref to @input_files array and return it
	$input_files=\@input_files;
	return $input_files;
}



# function that takes two numbers and creates a (global) array of
# numbers thusly: given the nos 5, 3 it creates the following array: 
# 0 1 2 0 1 3 0 1 4 0 2 3 0 2 4 0 3 4 1 2 3 1 2 4 1 3 4 2 3 4 
# to be used to create all possible n grams within a given window 
# to generate above list, call function thusly: getPermutations(5,3,0). 
# 0 is mandatory to get the recursion started. 
# generated list will be in global array called permutation[]
sub getPermutations
{
    my $totalLength = shift;
    my $lengthReqd = shift;
    my $level = shift;
    my $i;
    # @tempArray is a local array, but we can't declare it here because
    # the function calls itself and therefore a declaration would cause trouble
    no strict;

    if ($level == $lengthReqd)
    {
        for ($i = 0; $i < $lengthReqd; $i++ )
        {
            push @permutations, $tempArray[$i];
        }
        return;
    }

    my $start = ($level == 0) ? 0 : $tempArray[$level-1] + 1;
    my $stop = $totalLength - $lengthReqd + $level;

    for ($i = $start; $i <= $stop; $i++)
    {
        $tempArray[$level] = $i;
        getPermutations($totalLength, $lengthReqd, $level+1);
    }
}


##############################end define functions#############################

### sanity check: were any arguments provided?
if ( $#ARGV == -1 )
{
    usage();
    exit;
}

### analyse options
GetOptions qw( verbose|v version|V help|h frequency|f=i window|w=i stop|o=s newline|l encoding|e=s token|t=s nsize|n=i set_freq_combo|s=s display_freq_combo|d all_freq_combos|a separator|p=s );

# if help has been requested, print out help
if ( defined $opt_help ) { 
	help();
    exit;
}

# if version has been requested, show version
if ( defined $opt_version ) {
    version();
    exit;
}

# if iso encoding is specified, change default separator to <>
if ( "$opt_encoding" eq "iso-8859-1" ) {
	$separator="<>";
}

# if separator was supplied, put it in the right variable
if ( defined $opt_separator ) {
	$separator=$opt_separator;
}
# tell the user
if ( defined $opt_verbose ) {
	print "The separator used is: $separator\n";
}

if ( defined $opt_frequency ) { $cutOff = $opt_frequency; }
else                          { $cutOff = 0; }

if ( defined $opt_nsize )     { $nsize = $opt_nsize; }
else                      { $nsize = 2; }

if ($nsize <= 0) {
    print STDERR "Cannot have 'n' value of ngrams as less than 1\n";
    askHelp();
    exit();
}

if ( defined $opt_window ) { $windowSize = $opt_window; }
else { 
    $windowSize = $nsize; 
    if (defined $opt_verbose) {
        print "Window size is: $windowSize\n";
    }
}

# check for implausible window size
if ($windowSize < $nsize || ($nsize == 1 && $windowSize != 1)) {
    print STDERR "Illegal value for window size. Should be >= size of ngram (1 if size of ngram is 1).\n";
    askHelp();
    exit();
}

# check if token definition display was requested
if ( defined $opt_token && $opt_token eq 'show' ) {
	print "default token definition: /\\w+|[$tokendef]/\n";
	exit 0
}



# get frequency combinations
if (defined $opt_set_freq_combo) {
    read_freq_combo_file_109($opt_set_freq_combo);
}
elsif (defined $opt_all_freq_combos) {
	$combIndex=calculate_ALL_freq_combos($nsize);
}
else {
    calculate_freq_combo_109($nsize);
}

if (defined $opt_display_freq_combo) {
    show_freq_combo_array_109($freq_combo, $combIndex);
    exit 0;
}

# at the end of those two functions we should have with us the @freq_combo
# array and $freq_combo as a reference to it.
# depending on options, $freq_combo only is available (when it is put together
# in Ngramprocessor.pm) so it should be referred as a ref


# check if tokens file has been supplied. if so, try to open it and extract
# the regex's.
my @tokenRegex; # array to put individual tokens in
if ( defined $opt_token ) {
    open (TOKEN, "<:encoding($opt_encoding)", "$opt_token" ) || die "Couldn\'t open $opt_token\n";
    
    while(<TOKEN>)
    {
        chomp; s/^\s*//; s/\s*$//;
        if (length($_) <= 0) { next; }
        if (!(/^\//) || !(/\/$/))
        {
            print STDERR "Ignoring regex with no delimiters: $_\n";
            next;
        }
        s/^\///; s/\/$//;
        push @tokenRegex, $_;
    }
    close TOKEN;
    # if there are no tokens in the file to work with, inform user
	if ( $#tokenRegex < 0 ) {
    	print STDERR "No token definitions present in $opt_token. The standard token definitions will be used.\n";
	}
}
else 
{
    push @tokenRegex, "\\w+";
    push @tokenRegex, "[$tokendef]";  # originally "[\.,;:\?!]"
}

# create the complete token regex
$tokenizerRegex = "";

foreach my $token_char (@tokenRegex)
{
    if ( length($tokenizerRegex) > 0 ) 
    {
        $tokenizerRegex .= "|";
    }
    $tokenizerRegex .= "(";
    $tokenizerRegex .= $token_char;
    $tokenizerRegex .= ")";
}



# display tokenRegex if a custom token definition is used
if ( defined $opt_verbose && defined $opt_token ) {
	print "Token definitions currently in use: $tokenizerRegex\n";
}
elsif ( defined $opt_verbose ) {
	print "Standard token definitions in use: $tokenizerRegex\n";
}



### analysing arguments

# put out_file arg in its proper variable
$out_file = shift;

# check to see if a destination has been supplied at all...
unless ( defined $out_file ) {
    print STDERR "No output file (DESTINATION) supplied.\n"; 
    askHelp();
    exit;
}


# call get_input_files to put all files provided in the array @input_files
get_input_files(@ARGV);


# check to see if destination exists, and if so, if we should overwrite...
if ( -e $out_file )
{
    print "Output file $out_file already exists! Overwrite (Y/N)? ";
    my $reply = <STDIN>;
    chomp $reply;
    $reply = uc $reply;
    exit 0 if ($reply ne "Y");
}


# open output file
open ( DST, ">:encoding($opt_encoding)", "$out_file" ) || die "Couldn't open output file $out_file";


# if verbose, show all input_files
if ( defined $opt_verbose )
{
	# construct number of input files
	my $no_of_input_files=$#input_files; $no_of_input_files++;
	my $i;
    print "\nFound the following $no_of_input_files file(s) to source from: \n";
    for  ( $i = 0; $i < $no_of_input_files; $i ++ ) { print "$input_files[$i]\n"; }
    print "\n";
}

# get all the permutations for this ngram/windowSize combination. this tells
# us which words to pick from a window to form the various ngrams
@permutations = ();
getPermutations($windowSize-1, $nsize-1, 0);





# get source files one by one from @input_files, and process them
foreach my $source (@input_files)
{
    open ( SRC, "<:encoding($opt_encoding)", "$source" ) || die "Cant open SOURCE file $source, quitting";
    
    # inform user if verbose
    if ( defined $opt_verbose ) { print "Accessing file $source.\n"; }    
    
    # set the window index which will tell us where in the window array
    # we are right now. this is a global variable to be used by processToken
    # to figure out what to do with a new token.
    
    $windex = 0; # the NEXT place in the window array to write to!
    
    # read in the file, tokenize and process the token thus found
    while (<SRC>) # for each line of the input file
    {
        # refresh the window unless the -l option is active
        unless ( defined $opt_newline ) {
            $windex = 0;
        }
 
        # for current line, tokenize the line and send the token for
        # processing. 
        while ( /$tokenizerRegex/g ) {
            my $token = $&; # a token is here a word
            processToken($token);
        }
        
        # FUTURE IMPROVEMENT IDEA:
		# to speed up pattern matching here, we only use a variable in the
		# while loop condition if a non-default token definition was supplied,
		# otherise we use the default token definition directly
		#
		#if ( defined $opt_token ) {
        #	while ( /$tokenizerRegex/g ) {
        #    	$token = $&;
        #    	processToken($token);
        #	}
    	#}
    	#else {
        #	while ( /$tokenizerRegex/g ) {
        #    	$token = $&;
        #    	processToken($token);
        #	}
    	#}
    }
}

# that is the tokenizing and token-processing done!
# now to put in the stop list, if its been provided

if ( defined $opt_stop ) {
	our $stop_mode; # the mode of the stop list (if supplied)
    open ( STP, "<:encoding($opt_encoding)", "$opt_stop" ) ||
        die ("Couldn't open the stoplist file $opt_stop\n");

    # this will accept the stop tokens from the 
    # stop file as Perl regular expressions 
    # delimited by slashes /regex/ 
    # each regex should appear on a separate line     
    while ( <STP> ) { 
        chomp; 

		# AND Mode will remove those ngrams which consist of all stop words 
		# OR Mode will remove those ngrams consisting of at least one stop word
		# Default Mode will be AND Mode
        if(/\@stop.mode\s*=\s*(\w+)\s*$/) {
			$stop_mode=$1;
			if(!($stop_mode=~/^(ADDITIVE|AND|and|OR|or|ABSOLUTE)$/)) {
				print STDERR "Requested Stop Mode $1 is not supported.\n";
				exit;
			}
			next;
		} 

		# accepting Perl Regexs from Stopfile
		s/^\s+//;
		s/\s+$//;

		#handling a blank lines
		if(/^\s*$/) {
			next;
		}
		#check if a valid Perl Regex
	    if(!(/^\//)) {
	        print STDERR "Stop token regular expression <$_> should start with '/'\n";
	        exit;
	    }
	    if(!(/\/$/)) {
	        print STDERR "Stop token regular expression <$_> should end with '/'\n";
	        exit;
	    }
	    #remove the / s from beginning and end
	    s/^\///;
	    s/\/$//;
	    #form a single big regex
	    $stop_regex.="(".$_.")|";
    }
    if (length($stop_regex)<=0) {
	print STDERR "No valid Perl Regular Experssion found in Stop file $opt_stop";
	exit;
    }
    chop $stop_regex;

    # making ADDITIVE a default stop mode
    if (!defined $stop_mode) {
		$stop_mode="ADDITIVE";
    }

    close STP;
    
    # having got the file, go thru the ngrams, removing the offending ngrams
    foreach (keys %ngramFreq) {

        my @tempArray = split /$separator/;
		my $doStop;

		#by default OR should get value 0 so that when any word matches 
		#a stop token, we can remove the ngram 
		if($stop_mode=~/ABSOLUTE|OR|or/) {
			$doStop = 0;
		}

		#by default AND should get value 1 so that when any word doesn't
		#match a stop token, we can accept the ngram 
		else	{
			$doStop = 1;
		}

        for (my $i = 0; $i <= $#tempArray; $i++ ) {
		    # if mode is OR, remove the current ngram if
            # any word is a stop word	
		    if($stop_mode=~/ABSOLUTE|OR|or/) {
				if($tempArray[$i]=~/$stop_regex/) {
					$doStop=1;
                    last;
                }
            }
		    # if mode is AND, accept the current ngram if
            # any word is not a stop word 
            else {
				if(!($tempArray[$i]=~/$stop_regex/)) {
					$doStop=0;
					last;
				}
		    }
        }
        
        if ($doStop) {
            # remove this ngram and adjust all frequencies appropriately
            removeNgram($_);
        }
    }
}


# end of processing all the files. now to write out the information.
if ( defined $opt_verbose ) { print "Writing to $out_file.\n"; }

# finally print out the total ngrams
print DST "$ngramTotal\n";

foreach (sort { $ngramFreq{$b} <=> $ngramFreq{$a} } keys %ngramFreq)
{
    # check if this is below the cut-off frequency to be displayed
    # as set by switch --frequency. if so, quit the loop
    last if ($ngramFreq{$_} < $cutOff);

    # get the components of this ngram
    my @words = split /$separator/;

    # if a line starts with a single @, its a command (extended output).
    # if it starts with two consequtive @'s, then its a single 'literal' @.

    if ( $_ =~ /^@/ ) { print DST "@"; } 
    print DST "$_"; # ngram 

    # now print the frequency combo's requested
    my $j;
    for ($j = 0; $j < $combIndex; $j++)
    {
        my $tempString = "";
        my $k;
        for ($k = 1; $k <= $$freq_combo[$j][0]; $k++)
        {
            $tempString .= "$words[$$freq_combo[$j][$k]]$separator";
        }
        $tempString .= $j;
        print DST "$frequencies{$tempString} ";
    }
    print DST "\n";
}

# having done it all, close all open files...
close SRC;
close DST;


=head1 NAME

list.pl - produces lists of n-grams and their frequencies

=head1 SYNOPSIS

list.pl [OPTIONS] OUT-FILE { IN-FILE+ | IN-DIRECTORY }

=head1 DESCRIPTION

list.pl takes as input one or more text files { IN-FILE+ | IN-DIRECTORY } and lists the n-grams in it together with their frequencies.

=head2 OPTIONS
	  
=over
                         
=item * -a  --all_freq_combos 

Produce figures for all possible frequency combinations (required if NSP's statistics.pl is to be used to calculate word association measures).

=item * -d --display_freq_combo 

Prints out the frequency combinations used. If frequency combinations have been provided through --set_freq_combo switch above, these are output; otherwise the default combinations being used are output.

=item * -e --encoding ENC  

Handles input and output files with the character encoding given as ENC. The default is utf8; if necessary a different encoding can be forced using this option. A suitable token definition must also be supplied as the standard token definition is in utf8 (use -t option). Non-utf8 is not generally recommended and the option is here only provided for compatibility with legacy data sets. It is better to convert the data to utf8 as non-utf8 encodings have not been widely used in testing.

=item * -f --frequency N    

Does not display n-grams that occur less than N times.

=item * -h --help           

Prints this help message.

=item * -l --newLine        

Includes n-grams spanning across the new-line character. These are excluded by default.

=item * -n --ngram N    
   
Creates n-grams of N tokens each. N = 2 by default.

=item * -o --stop FILE      

Removes n-grams containing at least one (in ABSOLUTE mode) or all stop words (in ADDITIVE mode). Stop words should be declared as Perl Regular expressions in FILE.

=item * -p --separator SEP

Uses SEP as the symbol(s) separating the words of an n-gram. By default, words in n-grams are separated by the middle dot, but this can be changed using this option, for example to <> or _. Care needs to be taken that the separator symbol does NOT occur in the input texts, otherwise errors will result.

=item * -s  --set_freq_combo FILE 

Uses the frequency combinations in FILE to decide which combinations of tokens to count in a given n-gram. By default, on the frequency of the entire n-gram is kept track of. This option is provided for compatibility with the Text::NSP only; see Text::NSP's documentation for details.

=item * -t --token FILE    

Uses regular expressions in FILE to create tokens. By default two regular expressions are provided.

=item * -v --verbose        

Prints information as the programme runs.

=item * -V --version        

Prints the version number.

=item * -w --window N
      
Sets window size to N. By default, the window size is the same as the size of the n-grams.

=back


=head1 AUTHOR

Andreas Buerki, BuerkiA@cardiff.ac.uk

authors of NSP on which this programme is partly based:

Satanjeev Banerjee, bane0025@d.umn.edu

Ted Pedersen, tpederse@d.umn.edu


=head1 SEE ALSO

 home page:    http://buerki.github.io/ngramprocessor/
 
 Text::NSP

=head1 COPYRIGHT

Copyright 2013, Andreas Buerki

Copyright 2000-2003, Ted Pedersen and Satanjeev Banerjee

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

