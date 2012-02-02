#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use File::Utils;
use File::Sar;
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;


my $file = File::CachedFile::new($ARGV[0]);
$file->{sar_min_time_to_consider} = 360;
$file->{sar_max_time_to_consider} = -180;

my $result = $file->sar_parse({gnuplot=>1});
print "$result\n";
$result->{raw} = "SUPPRESSED"; #So that the output remains readable
print "Sar output (->{raw} suppressed):\n".Dumper($result);

print "\n\n[WARNING] No time limitation is applyied on the analysis so don't use this script for SPECweb!\n";

for my $c (sort{$a<=>$b} keys %{$result->{cpu}}) {
   printf "%.2d -> %2d\n", $c, $result->{cpu}->{$c}->{usage};
}
