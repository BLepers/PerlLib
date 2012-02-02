#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::Vtune;
use Data::Dumper;
$Data::Dumper::Maxdepth = 5;


my $file = File::CachedFile::new($ARGV[0]);

my $vtune = File::Vtune::new($file);

my $result = $vtune;
print "DUMP=".Dumper($result)."\n";


