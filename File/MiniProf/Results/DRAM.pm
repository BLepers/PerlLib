#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Switch;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use Graphics::GnuplotIF qw(GnuplotIF);
use File::MiniProf::Results::Plot;

package File::MiniProf::Results::DRAM;
use File::MiniProf;

#[ 'CPU_DRAM_Node0', 'CPU_DRAM_Node1', 'CPU_DRAM_Node2', 'CPU_DRAM_Node3' ],
sub local_dram_usage {
   my ( $self, $info, $parse_options, $opt ) = @_;
   my $plot;

   if ( $opt->{gnuplot} ) {
      $plot = File::MiniProf::Results::Plot::get_plot( $info, $parse_options, $opt, $parse_options->{ $info->{name} }->{name} );
   }

   my $global_sum_local;
   my $global_sum_all;
   my @accesses_to_node;
   
   my @events = map { $self->_scripted_value_to_event( $_, $info ) } ( 0 .. 3 );
   for my $core ( sort { $a <=> $b } keys %{ $self->{miniprof}->{raw} } ) {
      my $sum_all = 0;
      for my $dram ( 0 .. 3 ) {
         my ( $avg, $sum, $count ) = File::MiniProf::_miniprof_get_average_and_sum( $self->{miniprof}->{raw}->{$core}, $events[$dram] );

         $sum_all += $sum;
      }

      my $local_dram = File::MiniProf::_local_dram_fun($self, $core, $opt->{local_dram_fun});

      my ( $avg, $sum, $count ) = File::MiniProf::_miniprof_get_average_and_sum( $self->{miniprof}->{raw}->{$core}, $events[$local_dram] );
      
      $info->{results}->{$core}->{'local access ratio'} = $sum/$sum_all;
      
      for my $dram (0..3) {
         my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[$dram] );
         next if ($sum_all == 0);
         if($sum_all == 0){
            $info->{results}->{$core}->{'percent_access_to_'.$dram} = 0;
         }
         else{
            $info->{results}->{$core}->{'percent_access_to_'.$dram} = $sum/$sum_all;  
         }
         $accesses_to_node[$dram] += $sum;
      }
      
      $global_sum_local += $sum;
      $global_sum_all += $sum_all;
   }
   
   $info->{results}->{GLOBAL}->{'local access ratio'} = $global_sum_local/$global_sum_all;

   my ($max_access, $most_loaded_node) = (0,0);
   for my $dram (0..3) {
      $info->{results}->{GLOBAL}->{'access to '.$dram} = $accesses_to_node[$dram];
      if($accesses_to_node[$dram] > $max_access) {
         $max_access = $accesses_to_node[$dram];
         $most_loaded_node = $dram;
      }
   }
   $info->{results}->{GLOBAL}->{'most loaded node'} = $most_loaded_node;
   $info->{results}->{GLOBAL}->{'% of accesses to most loaded node'} = $max_access / $global_sum_all;


   if ( $opt->{gnuplot} ) {
#      my @plota;
#      
#      for my $die ( 0 .. 3 ) {
#         my $local_dram = &{$local_dram_fun}($die);
#         my @vals = ();
#         for ( my $i = 0 ; $i < scalar( @{ $self->{miniprof}->{raw}->{$die}->{ $events[0] }->{val} } ) ; $i++ ) {
#            my $val_0 = $self->{miniprof}->{raw}->{$die}->{ $events[$local_dram] }->{val}->[$i];    # LOCAL
#            my $val_1 = 0;
#            for my $k ( 0 .. 3 ) {
#               if ( $k != $local_dram ) {
#                  $val_1 += $self->{miniprof}->{raw}->{$die}->{ $events[$k] }->{val}->[$i];                   # LOCAL
#               }
#            }
#            my $avg = ( $val_1 ) ? ( $val_0 / $val_1 ) : 0;
#            push( @vals, $avg );
#         }
#         push( @plota, \@vals );     
#      }
#      
#      $plot->gnuplot_set_plot_titles( map( "Die $_", ( 0 .. 3 ) ) );
#      $plot->gnuplot_plot_xy( $self->{miniprof}->{raw}->{0}->{ $events[0] }->{time}, @plota ); 
   }
}

1;
