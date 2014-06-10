#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::NumaWatcher;
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;


my $file = File::CachedFile::new($ARGV[0]);

my $result = $file->nw_parse({gnuplot=>1, gnuplot_file=>'png'});
#my $result = $file->nw_parse({gnuplot=>1});
$result->{raw} = undef;
$result->{analysed} = undef;

print Dumper($result);
