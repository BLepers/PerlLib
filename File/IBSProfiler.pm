#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use Graphics::GnuplotIF qw(GnuplotIF);

package File::IBSProfiler;

=head
Usage:
   $file->nw_parse;

Returns:
=cut

sub ibsprofiler_parse {
   my ($self, $opt) = @_;

   while (my $line = <$self>) {
      if($line =~ m/\[Core (\d+)\] number of local accesses (\d+)/){
         $self->{ibsprofiler}->{nb_local_accesses}->{$1} = $2;
      }
      elsif($line =~ m/\[Core (\d+)\] number of remote accesses (\d+)/){
         $self->{ibsprofiler}->{nb_remote_accesses}->{$1} = $2;
      }
      elsif($line =~ m/\[Core (\d+)\] local access average latency (\d+)/){
         $self->{ibsprofiler}->{local_accesses_latency}->{$1} = $2;
      }
      elsif($line =~ m/\[Core (\d+)\] remote access average latency (\d+)/){
         $self->{ibsprofiler}->{remote_accesses_latency}->{$1} = $2;
      }
      elsif($line =~ m/\[Core (\d+)\] average access latency (\d+)/){
         $self->{ibsprofiler}->{global_accesses_latency}->{$1} = $2;
      }
      elsif($line =~ m/\[Core (\d+)\] (\d+) IBS interrupts, (\d+) avg time/){
         $self->{ibsprofiler}->{nb_interrupts}->{$1} = $2;
         $self->{ibsprofiler}->{nb_interrupts}->{GLOBAL} += $2;
         $self->{ibsprofiler}->{avg_interrupt_time}->{$1} = $3;
         push @{$self->{ibsprofiler}->{avg_interrupt_time}->{GLOBAL}}, $3;
      }
      elsif($line =~ m/\[GLOBAL\] number of local accesses (\d+)/){
         $self->{ibsprofiler}->{nb_local_accesses}->{GLOBAL} = $1;
      }
      elsif($line =~ m/\[GLOBAL\] number of remote accesses (\d+)/){
         $self->{ibsprofiler}->{nb_remote_accesses}->{GLOBAL} = $1;
      }
      elsif($line =~ m/\[GLOBAL\] local access average latency (\d+)/){
         $self->{ibsprofiler}->{local_accesses_latency}->{GLOBAL} = $1;
      }
      elsif($line =~ m/\[GLOBAL\] remote access average latency (\d+)/){
         $self->{ibsprofiler}->{remote_accesses_latency}->{GLOBAL} = $1;
      }
      elsif($line =~ m/\[GLOBAL\] average access latency (\d+)/){
         $self->{ibsprofiler}->{global_accesses_latency}->{GLOBAL} = $1;
      }
      
   }
   
   return $self->{ibsprofiler};
}

1;
