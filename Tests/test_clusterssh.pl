#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use ClusterSSH;
use Data::Dumper;
use Getopt::Long;

$| = 1;

my @nodes;
my $help;
my $cmdl;

sub usage {
    print "Usage: $0 [-n <node>]+ -cmd <command>\n";
    exit -1;
}

my $result = GetOptions(
   "cmd=s"      => \$cmdl,  # string
   "help|h"     => \$help,  # flag
   "node|n=s"   => \@nodes  # list
);

if ( scalar(@nodes) == 0 || defined $help || !defined $cmdl) {
   usage();
}

print "Running $cmdl on nodes: ".join(" ", @nodes)."\n";

my $client_nodes = ClusterSSH::new( \@nodes );
$client_nodes->run_cmd($cmdl, undef, {
   profile         => 0,
   silent          => 0,
   do_not_join     => 0,
   separate_window => 0,
   user            => "root",
});
