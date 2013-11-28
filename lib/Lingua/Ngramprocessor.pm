package Lingua::Ngramprocessor;
#####################################################################
# Ngramprocessor.pm (part of the N-Gram Processor)
our $VERSION = '0.03';
####
# Copyright 2013, Andreas Buerki
# Copyright 2006, Bjoern Wilmsmann
# Copyright 2004, Ted Pedersen, Satanjeev Banerjee
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
# CHANGELOG
# date		 v.		change
# 2013-11-07 0.03	added necessary functions formerly contain in Tokenizer.pm
#					and some functions for displaying and calculating frequency
#					combinations.
# 2013-11-01 0.02	added function to create frequency combinations to
#					what used to be just a dummy module.
####

## include external libraries

use strict;
use warnings;
#use diagnostics;
use Exporter;
use utf8;

###############################declaring variables#############################

our @ISA  = qw(Exporter);
our @EXPORT = qw(calculate_ALL_freq_combos calculate_freq_combo show_freq_combo_array_109 show_freq_combo_array read_freq_combo_file addNgramEntry merge printTokens $freq_combo);
our $freq_combo; # ref to array holding frequency combinations
our @freq_combo;
our $combIndex;
our $required_nsize;
our $merge; # this is a ref to the hash which is to hold the merged list
our $frequencies; # ref to hash holding frequencies
our $ngrams;
our %ngrams;

# function to create all frequency combinations that can be computed
# and output (from count.pl 0.58 of NSP 1.23)
# result will be put in the @freq_combo array and needs $nsize as argument
sub calculate_ALL_freq_combos {
    my $i;
    $required_nsize = shift;

    # first create the first index of the comb, that is the
    # combination that includes all the constituents in the n-gram

    $combIndex = 0;
    $freq_combo[0][0] = $required_nsize;
    for ($i = 0; $i < $required_nsize; $i++)
    {
        $freq_combo[0][$i+1] = $i;
    }
    $combIndex++;

    # now create the rest, starting with size 1
    for ($i = 1; $i < $required_nsize; $i++)
    {
        createCombination(0, $i);
    };
    $freq_combo = \@freq_combo; # make $freq_combo a ref to @freq_combo
    return $combIndex;
    #show_freq_combo_array_109($freq_combo, $combIndex);
}

# define calculate_freq_combo function (generates plain n-gram frequency only)
sub calculate_freq_combo {
	# assign arguments to proper variable
	my ($nsize, $opt_set_freq_combo, $original_dir) = @_;
	# derive freq_combo numbers when n-gram size given as argument
	# first check if freq_combo file was supplied
	if ( defined $opt_set_freq_combo )
		{
    		# read in freq combo file
    		$freq_combo = read_freq_combo_file($original_dir, $opt_set_freq_combo);
		}
	else {
		my $i;
		my $ii = $_[0]-1;
		for $i (0..$ii)
			{
				$freq_combo->[0]->[$i] = $i;
		}
	};
	return $freq_combo;

};

# function called by calculate_ALL_freq_combos
# at the end of those two functions we should have with us the @freq_combo
sub createCombination # (from count.pl 0.58 of NSP 1.23)
{
    my $level = shift;
    my $size = shift;
	no strict;
	no warnings;
	
    if ($level == $size)
    {
        $freq_combo[$combIndex][0] = $size;

        my $i;
        for ($i = 1; $i <= $size; $i++)
        {
            $freq_combo[$combIndex][$i] = $tempCombArray[$i-1];
        }
        $combIndex++;
    }
    else
    {
        my $i;
        my $loopStart = (!$level)?0:$tempCombArray[$level-1]+1;

        for ($i = $loopStart; $i < $required_nsize; $i++)
        {
            $tempCombArray[$level] = $i;
            createCombination($level+1, $size);
        }
    }
}

# function to display frequency combinations created (count.pl 1.09-style)
sub show_freq_combo_array_109
{
    my ($freq_combo, $combIndex) = @_;
    my ($i, $j);

    for ($i = 0; $i < $combIndex; $i++)
    {
        #print STDERR "$freq_combo[$i][0]: ";
        for ($j = 1; $j <= $$freq_combo[$i][0]; $j++)
        {
            print "$$freq_combo[$i][$j] ";
        }
        print "\n";
    }
}

# define show_freq_combo_array function
sub show_freq_combo_array {
	my ($freq_combo) = @_; 
	# dereference and display $freq_combo
	my ($j, $i);
    for ($i = 0; $i < @{$freq_combo}; $i++) {
		for ($j = 0; $j < @{$freq_combo->[$i]}; $j++) {
	    	print "$freq_combo->[$i]->[$j] ";
		}
		print "\n";
    }
};

# define read_freq_combo_file function (originally from SupportFunctionLibrary.pm) reads from a freq combo file passed via option and puts the result into the freq_combo array.
sub read_freq_combo_file {
		my ($original_dir, $path) = @_;
		
		# define array for buffering combinations
		my @combinations;
		
		# define variable for buffering single combination
		my $singleCombination;

		# initialise counter variable
		my $i = 0;
		
		# unless $path starts with a slash (indicating a full path), prepend it
		# with $original_dir
		unless ($path =~ /^\//) {
			$path = "$original_dir/$path";
		};
		
		# open file for getting frequency combinations
		open(FREQ_COMBO_IN, "$path") || die ("Couldn't open file for frequency combination input: $path");    	    

		# get frequency combinations
		while (<FREQ_COMBO_IN>) {
			my $j = 0;
			chomp();
			@combinations = split(/ /);
			for $singleCombination (0 .. @combinations - 1) {
				$freq_combo->[$i]->[$j] = $combinations[$singleCombination];
				$j++;
			}
			$i++;
		}
		# close file
    	close(FREQ_COMBO_IN);
    	return $freq_combo;
};






# function for adding information in an n-gram file entry to queue
# for merge process
sub addNgramEntry {
	my ($ngramString, $scores, $file, $separator, $freq_combo) = @_;
	# $ngramString is used to keep the n-gram in (no frequencies)
	# $scores ref to array holding each of the frequency numbers
	# $file is the name of the INFILE currently processed
	# $separator hold the n-gram separator, i.e. · <> _ or something else
	# $freq_combo is a reference to the array holding the frequency combinations
	my @ngram; # this is an array to hold the words of the current n-gram
	my $i;
	my $j;
	my $frequencyValue;
	my $frequencyBuffer; # Buffer for use only in this subroutine

	# split n-gram into single words and put them in @ngram
	@ngram = split(/$separator/, $ngramString);
	#print "@ngram\n";
	#print "$freq_combo->[0]\n";
	#print "the separator is: $separator\n";

# now increment the various frequencies according to $frequencyCombinations
    for ($i = 0; $i < @{$freq_combo}; $i++) {
		# reset frequency buffer
		$frequencyBuffer = "";

		# go through frequency combinations
    	for ($j = 0; $j < @{$freq_combo->[$i]}; $j++) {
		#print "\$ngram[\$freq_combo->[$i]->[$j]]$separator --- ";
		#print "$ngram[$freq_combo->[$i]->[$j]]$separator\n";
			if ( $separator eq '<>' ) {
        		$frequencyBuffer .= "$ngram[$freq_combo->[$i]->[$j]]<>";}
        	elsif ( $separator eq '_' ) {
        		$frequencyBuffer .= "$ngram[$freq_combo->[$i]->[$j]]_";}
        	elsif ( $separator eq '·' ) {
        		$frequencyBuffer .= "$ngram[$freq_combo->[$i]->[$j]]·";}
        	else {
        		$frequencyBuffer .= "$ngram[$freq_combo->[$i]->[$j]]$separator";
        	};
        }
        $frequencyBuffer .= $i;
        
        # get frequency value
        $frequencyValue = $scores->[$i];
        #print "$scores->[$i]\n";

		# write frequency value to frequency hash
		# if value for this frequency does not yet exist
		# in this file
		unless(defined $merge->{$file}->{frequencies}->{$frequencyBuffer}) {
	    	$merge->{$file}->{frequencies}->{$frequencyBuffer} = $frequencyValue;
		}
		
		# write frequency for n-gram to n-gram hash
		# for this file
		if ($i == 0) {
			$merge->{$file}->{ngrams}->{$ngramString} = $frequencyValue;
		}
	}
}



# function for merging n-gram models
sub merge {
	my $frequencyBuffer; # Buffer for use only in this subroutine
	my $ngramBuffer;
	my $file; # to hold the keys in the merge hash
	# iterate over frequency models to be merged
	
	# the hash ref $merge was created by sub addNgramEntry
	foreach $file (keys(%{$merge})) {
		# iterate over frequencies in this model
		foreach $frequencyBuffer (keys(%{$merge->{$file}->{frequencies}})) {
			# write entry to global frequency hash
			$frequencies->{$frequencyBuffer} += $merge->{$file}->{frequencies}->{$frequencyBuffer};
		}
		
		# iterate over n-grams in this model
		foreach $ngramBuffer (keys(%{$merge->{$file}->{ngrams}})) {
			# write entry to global n-gram hash
			$ngrams->{$ngramBuffer}->{total} += $merge->{$file}->{ngrams}->{$ngramBuffer};
			$ngrams->{$ngramBuffer}->{filecount}++;
		}
	}
}

# function for printing tokens
sub printTokens {
	my ($out_file, $nsize, $separator, $filecount, $freq_combo) = @_;
	my $i;
	my $j;
	my @ngram; # this is an array to hold the words of the current n-gram
	my $ngramBuffer; # Buffer for use only in this subroutine

	# try to open out_file file
	open(DST, ">>$out_file") || die("Couldn't open output file: $out_file");

	# if n-gram size > 1
	if ($nsize > 1) {
		# sort token frequencies
		#print "$_\n" for keys %$ngrams;
		foreach (sort {$ngrams->{$b}->{total} <=> $ngrams->{$a}->{total}} keys (%{$ngrams})) {

        	# split n-gram into single words
        	@ngram = split(/$separator/, $_);

	    	# if a line starts with a single @, its a command (extended output).
    		# if it starts with two consequtive @'s, then its a single 'literal' @.
    		if ($_ =~ /^@/) {
    			print DST "@";
    		}
    	
    		# print n-gram
    		print DST "$_";
    		#print "$_\n";

			# go through frequency combinations
        	for ($i = 0; $i < @{$freq_combo}; $i++) {		
   				# reset n-gram buffer
        		$ngramBuffer = "";

				# go through frequency combinations
    		    for ($j = 0; $j < @{$freq_combo->[$i]}; $j++) {
        	    	$ngramBuffer .= "$ngram[$freq_combo->[$i]->[$j]]$separator";
            	}
            	$ngramBuffer .= $i;
            	#print "The n-gramBuffer: $ngramBuffer\n";

				# print this frequency combination
    	    	print DST "$frequencies->{$ngramBuffer} ";
        	}


		if ($filecount) {
			print DST " $ngrams->{$_}->{filecount} ";
		}
			# new line
    		print DST "\n";
		}
	} else {
		# sort token frequencies
		foreach (sort {$ngrams->{$b} <=> $ngrams->{$a}} keys (%{$ngrams})) {

			# if n-gram size = 1, just print this unigram and its frequency and that's it!
			print DST $_ . $frequencies->{$_ . "0"};
			if ($filecount) {
				print DST " $ngrams->{$_}->{filecount} ";
			}
			print DST "\n";
		}
	}
	
	# close out_file
	close(DST);
}



1;

__END__


=head1 NAME

Lingua::Ngramprocessor - extracting and processing n-grams

=head1 SYNOPSIS

=head2 Basic Usage

  use Lingua::Ngramprocessor
  
  individual functions are accessed through the unify.pl and list.pl scripts supplied.


=head1 DESCRIPTION

The N-Gram Processor is a set of scripts and a Perl module allowing the creation and processing of n-gram lists out of text files. It is based on code from two versions of the N-Gram Statistics Package (NSP), v. 1.09 and 1.10. N-Gram Processor can be used for broadly the same purposes as the original N-Gram Statistics Package but focuses on a some key improvements, namely:

- support for unicode-encoded in- and output and multi-language awareness
- generating document counts for n-grams
- modifications to allow the processing of larger amounts of data

On the other hand, the N-Gram Processor does not include a statistics module (a key component of the original NSP), although NSP's statistics module can be used on output of the N-Gram Processor under certain conditions.

N-Gram Processor was tested under MacOS X and Xubuntu Linux, but should work well on any platform that can run Perl code and bash shell code.

=head1 AUTHOR

Andreas Buerki, Humboldt-Universität zu Berlin, andreas.buerki@hu-berlin.de

Authors of the NSP on which N-Gram Processor is based in part:

Ted Pedersen,                University of Minnesota Duluth
                             E<lt>tpederse@d.umn.eduE<gt>

Satanjeev Banerjee,          Carnegie Mellon University
                             E<lt>satanjeev@cmu.eduE<gt>

Amruta Purandare,            University of Pittsburgh
                             E<lt>amruta@cs.pitt.eduE<gt>

Bridget Thomson-McInnes,     University of Minnesota Twin Cities
                             E<lt>bthompson@d.umn.eduE<gt>

Saiyam Kohli,                University of Minnesota Duluth
                             E<lt>kohli003@d.umn.eduE<gt>


=head1 SEE ALSO

L<http://buerki.github.io/ngramprocessor/>

For information on the the N-Gram Statistics Package (NSP) see

L<http://www.d.umn.edu/~tpederse/nsp.html>

L<https://github.com/BjoernKW/Publications/blob/master/Re-write_of_Text-NSP.pdf/>


=head1 COPYRIGHT

Copyright (C) 2013, Andreas Buerki

Copyright (C) 2000-2006, Ted Pedersen, Satanjeev Banerjee,
Amruta Purandare, Bridget Thomson-McInnes and Saiyam Kohli

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
