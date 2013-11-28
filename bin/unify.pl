#!/usr/bin/env perl

#####################################################################
# Unify.pl (part of the N-Gram Processor)
# incorporating code from NSP 1.10's huge-combine.pl/Combiner.pm
our $VERSION = '0.04';
#####
our $copyright = "Copyright 2013, Andreas Buerki
Copyright 2006, Bjoern Wilmsmann (v. 1.10 NSP)
Copyright 2004, Amruta Parundare & Ted Pedersen (v. 1.09 NSP)\n";
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
#####################################################################
# UNDOCUMENTED OPTIONS (experimental):
# -c --calculate_all_freq_combo
# calculates and displays only all possible frequency combinations which can be # used to calculate various statistics. The output of this option can be used to # produce an input file for the -s option (above).
#
#
#
# CHANGELOG
# date		 v.		change
# 2013-11-14 0.04	fixed and corrected pod documentation
# 2013-11-05 0.03	made separator flexible, so various separators can
#					be used; adjusted for use with Ngramprocessor.pm instead of
#					Tokenizer.pm.
# 2013-11-02 0.02	incorporated code from Combiner.pm and
#					SupportFunctionLibrary.pm so both of these NSP 1.10 modules
#					are no longer needed. OptionReader.pm is no longer needed
#					as these functions were replaced by the standard
#					Getopts::Long module. Set encoding to utf-8.
#					added -c option to display all poss freq combinations
####

#-----------------------------------------------------------------------------
#                              start of program
#-----------------------------------------------------------------------------


## include external modules

# use strict to enforce declaration of variables
use strict;
use warnings;

# use locale for localised tokenization
use locale;

# set encoding to utf-8
use utf8;

# use Getopt::Long to parse options (bundling, i.e. -ex for -e -x is allowed)
use Getopt::Long qw(:config bundling_override);

# use File::Copy to get the move command
use File::Copy;

# use Basename to refer to current programme
use File::Basename;

# use Ngramprocessor module
use Lingua::Ngramprocessor;

# use the Cwd module to be able to use cwd (equivalent to bash 'pwd')
use Cwd;


###############################declaring variables#############################

# declare variables
our $opt_help;
our $opt_version;
our $opt_doc_count; # the option to include document count
our $opt_separator; # if a separator other than <> _ · needs specifying
our $opt_verbose;
our $opt_set_freq_combo; # path to a freq combo file
our $opt_display_freq_combo;
our $opt_calculate_all_freq_combo; 
our $opt_quiet; # fail quietly if possible

our @input_files; # to hold the input files
our $out_file; # output will be written to the filename in this variable
our $nsize; # the length of n-grams processed
our $line; # this is convenient to keep all sorts of lines in
our $freq_combo; # ref to the freq_combo numbers (AoA)
our $separator; # the n-gram separator used in files
our $sep; # first character of $separator
our $combIndex; # variable needed for display of 1.09-style freq_combos

# define some variables
our $name = basename($0); # the name of this programme
our $original_dir = cwd; # store current working directory here

# set STDOUT to display in unicode
binmode(STDOUT, ":utf8");

#################################define functions##############################

# define Usage function
sub usage {
	print "Usage: $name [OPTIONS] OUTFILE [ INFILE+ | INDIRECTORY ] \n\n";
};

# define help function
sub help {
	print "Usage: $name [OPTIONS] OUT-FILE [ IN-FILE+ | IN-DIRECTORY ] \n\n";
	print "Combines two or more n-gram IN-FILEs and writes the results to OUT-FILE.\n\n";

	print "Options:\n\n";
    print "  -h --help             Displays this message.\n\n";
    print "  -V --version          Displays the version information.\n\n";
    print "  -v --verbose          Displays extra information as script runs.\n\n";
    print "  -D --display_freq_combo    Displays the file combinations used.\n\n";
    print "  -c --calculate_all_freq_combo N Displays all possible freq combinations for N\n\n";
    print "  -d --doc_count        Adds a document count to each n-gram.\n\n";
    print "  -p --separator SEP    Specifies a custom SEP\n'n";
    print "  -s --set_freq_combo FILE 	Uses the frequency combinations in FILE
                        when counting frequencies.\n\n";
   	print "Type \'perldoc $name\' for more detailed information.\n";
};


# define Version function
sub version {
	print "$name	-	version $VERSION\n";
	print "$copyright";
};



# define combine function (originally from NSP 1.10 Combiner.pm)
sub combine {
	
	# initialise variable for total number of n-grams that appears as first line
	# in n-gram lists
	my $ngramTotal = 0;
	
	# define n-gram hash
	my %ngrams;
	
	# define frequency hash
	my %frequencies;
	
	# define variable used for counting lines in INFILES
	my $lineNumber;

	# define variable to hold n-grams
	my $ngramString;
	
	# define variable to hold n-gram frequencies
	my $scores;
	
	# define array for storing split frequencies (i.e. the different frequencies
	# related to an n-gram as the elements of the array)
	my @splitScore;
	
	# define hash for storing split frequencies
	my %splitScores;

	# iterate over INFILES
	foreach my $source (@input_files) {
		# reset line number
		$lineNumber = 0;

		# open input file
		open(IN, $source)
			|| die("Can't open n-gram file <$source>.\n");
			  		
		# iterate over lines in the INFILE
		while (<IN>) {
			# increment line number
			$lineNumber++;
					
			# chomp, i.e. get rid of newline at the end of lines
			chomp($_);
			
			# first line, get total number of n-grams
			if (/^(\d+)\s*$/) {
				if ($lineNumber == 1) {
					# get total and add to existing value
					$ngramTotal += $1;
					next;
				} else {
					# malformed input
					print STDERR "Line $lineNumber in NGRAM file <$source> seems to be malformed.\n";
					exit(1);
				}
			}
	
	
			## process frequencies
			
			# check for frequencies
			if (/(^.*?$separator)([\d|\s]+)$/) {
				# put n-gram in $ngramString and frequencies in $scores
				$scores = $2;
				$ngramString = $1;

				# split the different frequencies into separate elements
				@splitScore = split(/ /, $scores);

				# add information from this line to queue for
				# merge process
				addNgramEntry($ngramString, \@splitScore, $source, $separator, $freq_combo);
			} elsif (!(/\s*/)) {
				# malformed input
				print STDERR "Line $lineNumber in file <$source> seems to be malformed.\n";
				exit(1);
			}
		}
		
		# close model file
		close(IN);
		
	}


	# merge models
	#print "calling merge\n";
	merge();

	# change back to original directory
	chdir($original_dir)	or die "Can't change back to $original_dir: $!";

	# try to open destination file
	open(DST, ">$out_file")
		|| die("Couldn't open output file: $out_file");

	# print out the total ngrams
	print DST "$ngramTotal\n";

	# close destination file
	close(DST);

	# print merged n-gram counts to destination file
	#print "calling printTokens($out_file, $nsize, $separator, \$opt_doc_count, $freq_combo)\n";
	printTokens($out_file, $nsize, $separator, $opt_doc_count, $freq_combo);	
	
}


##############################end define functions#############################


### sanity check

# if no arguments were passed, print usage notes
if ( $#ARGV == -1 ) {
	print STDERR "No arguments were supplied!\n";
    usage();
    exit;
}


### analyse options

GetOptions qw( help|h doc_count|d version|V verbose|v separator|p=s set_freq_combo|s=s display_freq_combo|D calculate_all_freq_combo|c=i quiet|q );

# if help has been requested, show help, then exit
if (defined $opt_help) {
	help();
	exit(0);
}
	
# if version display has been requested, show, then exit
if (defined $opt_version) {
	version();
	exit(0);
}

# if calculation of all freq combos has been requested, show, then exit
if (defined $opt_calculate_all_freq_combo) {
# print "All frequency combinations at n-gram size $opt_calculate_all_freq_combo are:\n";
	$combIndex=calculate_ALL_freq_combos($opt_calculate_all_freq_combo);
	show_freq_combo_array_109($freq_combo, $combIndex);
	exit(0);
}


# if there aren't at least two more arguments now, do some additional checks
if ( $#ARGV < 1 ) {
	print STDERR "ERROR: OUTFILE and INFILE+ must be supplied.\n";
    usage();
    exit(1);
}


### process options and arguments

# check if OUTFILE already exists, if not, assign to $out_file
if ( -e $ARGV[0] ) {
	print STDERR "ERROR: OUTFILE $ARGV[0] already exists! exiting.\n";
	exit(1);
}
else {
	$out_file=$ARGV[0];
	shift(@ARGV);
}	

# process INDIR if given: if next argument exists and is a directory
# read its content into the array @input_files and change to that directory
if ( -d $ARGV[0] ) {
	our $in_dir=$ARGV[0];
	# read the filenames in input directory into the input_files array
	opendir DIR, "$in_dir"		or die "cannot open directory $in_dir: $!";
	@input_files = grep { $_ ne '.' && $_ ne '..' && $_ ne '.DS_Store' } readdir DIR;
	closedir DIR;
	
	# change to input_directory
	chdir($in_dir)	or die "Can't change to $in_dir: $!";
	
	# check if there's more than one file in the directory
	if ( $#input_files < 1 ) {
		# check if one input files was provided
		if ( $#input_files == 0 ) {
			if ( defined $opt_verbose ) {
				print "\n 1 file provided; moving @input_files to outfile.\n";
			}
			# in that case, move the input file straight to output file
			move("@input_files","$out_file") or die "Can't move file @input_files: $!";;
			exit(0);
		}
		else {
			unless ( defined $opt_quiet ) {
				print STDERR "ERROR: no INFILES in the directory.\n";
			}
    	exit(1);
    	}
	}
}


# process INFILE+
# else read the remaining arguments, check if files exist and put names into @input_files array
else {
	# if number of source files is < 2, abort
	if ( $#ARGV < 1 ) {
	print STDERR "ERROR: at least two INFILEs must be supplied.\n";
    exit(1);
	}
	# iterate over source files
	foreach my $file (@ARGV) {
		# check if file exists
		unless (-e $file) {
			print STDERR "ERROR: $file does not exist.\n";
			exit(1);
		}
	}
	# put arguments into the @input_files array
	@input_files = @ARGV;
}

# get separator and n-gram size from line 2 of first input file
# open first input file and put second line (or last line if only 1)
# in variable $line
open(INFILE, "<$input_files[0]") || die "Can't open $input_files[0] for reading: $!\n";
while (<INFILE>) {
	$line=$_;
	last if $. == 2;
}
close(INFILE);

# check if $line is defined, and if no throw error
unless ( defined $line ) {
	print STDERR "ERROR: problematic line ($line) encountered in $input_files[0]\n";
}


# if separator was not set through options,
# check three possible separators to see if they appear and derive nsize
if ( defined $opt_separator ) {
	$separator = $opt_separator;
	$sep = substr($separator, 0, 1);
	while ($line =~ /$sep/g) { $nsize++ }; # derive n-gram size
}
elsif ( $line =~ /<>/) {$separator="<>";$nsize = $line =~tr/</</;}
elsif ( $line =~ /·/)  {$separator="·" ;$nsize = $line =~tr/·/·/;}
elsif ( $line =~ /_/)  {$separator="_" ;$nsize = $line =~tr/_/_/;}
else {
	print STDERR "ERROR: $input_files[0] uses unknown separator: $line\n";
	exit(1);
}
# reset variables for possible re-use
$line=0;

if (defined $opt_verbose) {print "separator detected: $separator
n-size detected:    $nsize\n"};

# derive freq_combo numbers
$freq_combo = calculate_freq_combo($nsize, $opt_set_freq_combo, $original_dir);


# if -d option called, display frequency combination numbers
#if (defined $opt_display_freq_combo) {
#	print "Frequency combination configuration currently in use:\n";
#	show_freq_combo_array($freq_combo);
#}


### call combine function
combine();

#-----------------------------------------------------------------------------
#                              end of programme
#-----------------------------------------------------------------------------

=head1 NAME

unify.pl - combines frequency lists produced by nlist.pl

=head1 SYNOPSIS

unify.pl [OPTIONS] OUT-FILE { IN-FILE+ | IN-DIRECTORY }

=head1 DESCRIPTION

Combines two or more n-gram IN-FILES and writes the results to OUT-FILE. The files to be combined need to be of the format produced by nlist.pl.

=head2 OPTIONS

=over

=item * -d --doc_count

Adds a count of how many documents (input files) each n-gram appears in. This figure is appended to the end of each line of output, separated by two spaces.

=item * -D --display_freq_combo

Shows the current frequency combinations setting.

=item * -h --help

Displays help.

=item * -V --version

Displays version information.

=item * -v --verbose

Displays processing information as the programme runs.

=item * -s --set_freq_combo FILE

Uses the frequency combinations in FILE to decide which combinations of tokens to count in a given n-gram. If n-gram lists with more frequency combinations than the frequency of the n-gram are needed (such as when statistics of association should be calculated), this option MUST be used, together with the appropriate file. The lists to be combined must contain the necessary frequencies, of course.

=back

=head1 AUTHORS

Andreas Buerki, BuerkiA@cardiff.ac.uk

Author of the original huge-combine.pl, part of NSP v. 1.10:
Bjoern Wilmsmann, Ruhr-University, Bochum.


=head1 SEE ALSO

nlist.pl, Lingua::Ngramprocessor, Text::NSP

 home page:    http://buerki.github.io/ngramprocessor/



=head1 COPYRIGHT

Copyright (c) 2013, Andreas Buerki
Copyright (c) 2006, Bjoern Wilmsmann, Ruhr-University, Bochum.

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
