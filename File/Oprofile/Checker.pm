#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Switch;
use Data::Dumper;
use File::Basename;
use lib "$FindBin::Bin";

package File::Oprofile::Checker;

sub op_check {
   my $self = $_[0];
   my $file = File::Basename::basename($self->{file}->{filename});
   my $time = $self->op_check_time;
   my $freq = $self->op_check_frequency;
   my @ret = (@$time, @$freq);
   if(scalar @ret) {
      return "[ERROR $file] [".join(", ", @ret)."]\n";
   } else {
      return "";
   }
}

sub op_check_time {
   my $self = $_[0];
   my $times = $self->{times};
   my @ret;

   if(!defined($times) || scalar(@$times) < 3) {
      push(@ret, "no time information");
      return \@ret;
   }
   my $start_time = $times->[1] - $times->[0];
   my $profile_time = $times->[2] - $times->[1];

   my $expected_start_time = 780;
   my $expected_profile_time = 120;
   if($start_time == 0 || (($start_time - $expected_start_time) / $start_time > 0.05)) {
      push(@ret, ($start_time-$expected_start_time)."s start time diff");
   } 
   if($profile_time == 0 || ($profile_time - $expected_profile_time) / $profile_time > 0.05) {
      push(@ret, ($profile_time-$expected_profile_time)."s bench time diff");
   }
   return \@ret;
}

sub profile_time {
   my $self = $_[0];
   my $times = $self->{times};

   if(!defined($times) || scalar(@$times) < 3) {
      return;
   }
   return ($times->[2] - $times->[1]);
}

sub op_check_frequency {
   my ($self) = @_;
   my @ret;

   my $samples = $self->samples('CPU_CLK_UNHALTED:0x00');
   if(!defined $samples) {
      #$errno = "No CPU_CLK_UNHALTED in events";
      return \@ret;
   }
   if(!defined($self->{times}) || !defined($self->{nb_cpus}) || $self->{nb_cpus} == 0) {
      #$errno = "No time or CPU information";
      return \@ret;
   }

   my $cpu_freq = $samples->{samples} * $self->{events_metadata}->{'CPU_CLK_UNHALTED:0x00'}->{'count'}  / ( $self->profile_time ) / $self->{nb_cpus} / 1000 / 1000;
   if(abs($cpu_freq - $self->{estimated_freq}) > 100){
      push(@ret, sprintf "frequency (observed %4d/%4d)",$cpu_freq, $self->{estimated_freq}); 
   }
   $self->{freq} = $cpu_freq;
   return \@ret;
}

1;
