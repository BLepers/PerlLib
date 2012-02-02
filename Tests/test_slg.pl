#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::Slg;
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;


my $file = File::CachedFile::new($ARGV[0]);

my $result = $file->slg_parse({gnuplot=>1, plot_mbits=>1, verbose=>1});
print "$result\n";
print "Slg output :\n".Dumper($result);

