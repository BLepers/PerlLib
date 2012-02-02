#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;

use Statistics::Basic qw(:all);

package File::SWS;

sub sws_parse {
	my $self = $_[0];

   (my $bench, my $nprocs, my $irq, my $server) = ($self->{filename} =~ m/SLG_([\w-]+)_(\d+)procs_(\w+)_(\w+).hwc/);

   my @lines = $self->get_lines;
   my $lock = "error";
   for my $line (@lines) {
      if($line =~ m/Thread (\d+): total (\d+) cycles \((\d+.\d+) %\), nb calls (\d+), per call (\d+) cycles/){
         die "Error not recoverable\n" if ($lock eq "error");

         $self->{libasync}->{$lock}->{$1}->{total} = $2;
         $self->{libasync}->{$lock}->{$1}->{ratio} = $3;
         $self->{libasync}->{$lock}->{$1}->{nbcalls} = $4;
         $self->{libasync}->{$lock}->{$1}->{cyclespercall} = $5;

         $self->{libasync}->{$lock}->{total} += $2;
         $self->{libasync}->{$lock}->{nbcalls} += $4;
      }
      elsif($line =~ m/Time spent in critical sections:/){
         $lock = "criticalsection";
      }
      elsif($line =~ m/Time spent in runtime locks:/){
         $lock = "lock";
      }
      elsif($line =~ m/Total message consummed: (\d+)/s) {
         $self->{libasync}->{nb_total_events} = $1;
      }

      elsif($line =~ m/PAGE_FAULTS_MIN (\d+) PAGE_FAULTS_MAJ (\d+)/) {
         $self->{libasync}->{pg_flt_min} += $1;
         $self->{libasync}->{pg_flt_maj} += $2;
         $self->{libasync}->{nb_iter}++;

         my @words = split /\s+/, $line;
         my @observed_events;
         my $current_thread = -1;
         my $current_event = 0;
         for my $w (@words) {
            if($w =~ m/PAPI_(\w+)/){
               push @observed_events, $1;
            }
            elsif($w =~ m/T(\d+)/) {
               $current_thread = $1;
               $current_event = 0;
            }
            elsif($w =~ m/(\d+)/ && $current_thread >= 0){
               $self->{libasync}->{hw_events}->{$observed_events[$current_event]}->{$current_thread} += $1;
               $self->{libasync}->{hw_events}->{$observed_events[$current_event]}->{global} += $1;
               $current_event++;
            }
         }
      }
      elsif($line =~ m/Thread (\d+): nb message consummed: (\d+)/){
         $self->{libasync}->{eventsconsumed}->{$1}->{total} = $2; 
      }

      elsif($line =~ m/Thread (\d+) : (\d+) steals done/){
         $self->{libasync}->{steals}->{$1}->{total} = $2; 
      }

      elsif($line =~ m/Global : (\d+) colors stolen/){
         $self->{libasync}->{steals}->{global}->{total} = $1; 
      }
   }

   $self->{libasync}->{bench} = $bench;
   $self->{libasync}->{nprocs} = $nprocs;
   $self->{libasync}->{irq} = $irq;
   $self->{libasync}->{server} = $server;

	return $self->{libasync};
}

1;
