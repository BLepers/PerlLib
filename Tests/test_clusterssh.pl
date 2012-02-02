#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use ClusterSSH;
use Data::Dumper;
$| = 1;

my @nodes = ( "proton.inrialpes.fr" );

print "MAIN WINDOW...\nTest going on...";
my $client_nodes = ClusterSSH::new( \@nodes );
$client_nodes->run_cmd( "echo 'toto'; sleep 1; echo 'oto'; sleep 1; echo 'fjifj'; sleep 1; echo 'fdsj'; echo 'toto'; echo 'Error'; sleep 1; echo 'oto'; sleep 1; echo 'fjifj'; sleep 1; echo 'fdsj'; echo 'Error';", undef, {
   do_not_profile => 0,
   silent => 0,
   do_not_join => 1,
   separate_window => 1,
});
my $client_nodes2 = ClusterSSH::new( [ 'localhost' ] );
$client_nodes2->run_cmd( "echo 'toto'; sleep 1; echo 'oto'; sleep 1; echo 'fjifj'; sleep 1; echo 'fdsj'; echo 'toto'; sleep 1; echo 'oto'; sleep 1; echo 'fjifj'; sleep 1; echo 'fdsj'; ", undef, {
   do_not_profile => 0,
   silent => 0,
   do_not_join => 1,
   separate_window => 1,
});
my $client_nodes3 = ClusterSSH::new( [ 'gluon' ] );
$client_nodes3->run_scriptfile( 'test_sar.pl', undef, {
   do_not_profile => 0,
   silent => 0,
   separate_window => 0,
});
$client_nodes3->run_scriptfile( 'test_sar.pl', undef, {
   do_not_profile => 0,
   silent => 0,
   separate_window => 0,
});

$client_nodes->wait_threads;
$client_nodes2->wait_threads;

print " and done.\n";
sleep 3;
