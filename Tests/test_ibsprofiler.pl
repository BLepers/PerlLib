#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::IBSProfiler;
use Data::Dumper;

my $file = File::CachedFile::new($ARGV[0]);

my $result = $file->ibsprofiler_parse();

print Dumper($result);