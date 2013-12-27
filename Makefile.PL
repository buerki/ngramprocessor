use v5.12;
# require Perl 5.12 minimally

use ExtUtils::MakeMaker;

my @perlscripts_to_install = qw(list.pl unify.pl);
my @shellscripts_to_install = qw(multi-list.sh split-unify.sh);


WriteMakefile(
    NAME              => 'Lingua::Ngramprocessor',
    VERSION		      => '0.4',
    PREREQ_PM         => {},
    EXE_FILES         => [
                           map ("bin/$_", @perlscripts_to_install),
                           map ("bin/$_", @shellscripts_to_install),
                         ],
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
    (ABSTRACT_FROM  => 'lib/Lingua/Ngramprocessor.pm', # retrieve abstract from module
    AUTHOR         => 'Andreas Buerki <buerkiA@cardiff.ac.uk>') : ()),
);

