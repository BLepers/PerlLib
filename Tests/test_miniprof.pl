#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::MiniProf qw(miniprof_merge);
use Data::Dumper;

$Data::Dumper::Maxdepth = 5;

#my $file = File::CachedFile::new($ARGV[0]);
#my $result = $file->miniprof_parse(gnuplot=>0);
#my $result = $file->miniprof_parse(gnuplot=>1);
#my $result = $file->miniprof_parse(gnuplot=>1, gnuplot_file=>'png');
#my $result = $file->miniprof_parse(gnuplot=>1,  miniprof_mintime=> 3, miniprof_maxtime => 30);
#my $result = $file->miniprof_parse(gnuplot=>1, cores => [3]);
#my $result = $file->miniprof_parse(gnuplot=>1, gnuplot_max_cpu=>4, miniprof_mintime=> 3, miniprof_maxtime=>15);
#my $result = $file->miniprof_parse(gnuplot=>1, gnuplot_max_cpu=>4, gnuplot_file=>'png', cores => [3]);

my %opt = (gnuplot=>0);
#my %opt = (gnuplot=>1, gnuplot_file=>'png', cores=>[0, 48, 56]);
my $file = miniprof_merge(\@ARGV, %opt);
my $result = $file->miniprof_parse(%opt);

$result->{raw} = undef;
$result->{analysed} = undef;
print "Miniprof output:\n".Dumper($result);
