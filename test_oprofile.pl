#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::Oprofile;
use Data::Dumper;
$Data::Dumper::Maxdepth = 5;


my $file = File::CachedFile::new($ARGV[0]);
#$file->{sar_min_time_to_consider} = 0;
#$file->{sar_max_time_to_consider} = 100;

my $oprof = File::Oprofile::new($file);

my $result = $oprof->top("all",10);
print "DUMP=".Dumper($result)."\n";
my @tmp = @$result;
my $s = $oprof->safe_get_item("all",$tmp[0]);

print "Oprofile output: s=".Dumper($s)."\nTOP=\n".Dumper($result);


