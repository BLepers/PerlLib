#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::Sar;
use Data::Dumper;
$Data::Dumper::Maxdepth = 5;


my $file = File::CachedFile::new($ARGV[0]);
my $result = $file->miniprof_parse(gnuplot=>1, miniprof_mintime=> 300, miniprof_maxtime=>480);
#my $result = $file->miniprof_parse(gnuplot=>1, gnuplot_max_cpu=>4, miniprof_mintime=> 3, miniprof_maxtime=>15);
#my $result = $file->miniprof_parse(gnuplot=>1, gnuplot_max_cpu=>4, gnuplot_file=>'png', cores => [3]);
$result->{raw} = undef;
$result->{analysed} = undef;
print "Miniprof output:\n".Dumper($result);
