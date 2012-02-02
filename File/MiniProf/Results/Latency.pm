#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Switch;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;

package File::MiniProf::Results::Latency;
use File::MiniProf;

sub _get_local_dram {
   my $local_dram = $_[0];
   $local_dram = 1 if ( $_[0] == 3 );
   $local_dram = 3 if ( $_[0] == 1 );
   
   return $local_dram;
}

sub sum {
   my ($self, $info, $parse_options, $opt) = @_;

   my $event_0 = $self->_scripted_value_to_event(0, $info);
   my $glob_sum_0 = 0;
   my $local_sum_0 = 0;
   
   if($info->{name} =~ m/READ_CMD_REQUESTS_(\d+)/ || $info->{name} =~ m/READ_CMD_LATENCY_(\d+)/){
      my $target_node = $1;
                 
      for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
         my ($avg0, $sum0, $count0) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_0 );
         
         my $local_dram = _get_local_dram($core);
         #print "$info->{name}, core $core, local dram $local_dram --> $sum0\n";
         
         $glob_sum_0 += $sum0;
         if($local_dram == $target_node){
            $local_sum_0 += $sum0;
         }
         
         $info->{results}->{"Core$core"} = $sum0;
         
      }
   
      $info->{results}->{ALL} = $glob_sum_0;
      $info->{results}->{LOCAL} = $local_sum_0;
      
      #print main::Dumper($info->{results});
   }
   else {
      die "This function encounterd an error\n";
   }
}

1;