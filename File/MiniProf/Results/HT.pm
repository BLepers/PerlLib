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

package File::MiniProf::Results::HT;
use File::MiniProf;

#[ '403ff8', 'HT_LINK0-NOP', 'HT_LINK1-NOP', 'HT_LINK2-NOP' ]
sub ht_link {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;

   my @events = map { $self->_scripted_value_to_event($_, $info) } (0..3);
   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      for my $link (0..2) {
         my ($avg_all, $sum_all, $count_all) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[0] );
         my ($avg_link, $sum_link, $count_link) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[$link+1] );

         next if ($avg_all == 0);

         $info->{results}->{$core}->{'ht_link'.$link} = 1. - $sum_link/$sum_all; #HT Usage : 0 = good, 1 = bad
      }

      if($opt->{gnuplot} && defined $info->{results}->{$core}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            $plot =  File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name}.' on core '.$core.' (%)');

            my @plota;
            for my $link (0..2) {
               my @vals = ();
               for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$events[0]}->{val}}); $i++) {
                  my $val_0 = $self->{miniprof}->{raw}->{$core}->{$events[0]}->{val}->[$i]; #ALL
                  my $val_1 = $self->{miniprof}->{raw}->{$core}->{$events[$link+1]}->{val}->[$i]; #Link$i-NOP
                  my $avg = ($val_1 && $val_0)?(1.-$val_1/$val_0):0;
                  
                  $avg *= 100.; ## Percentage
                  
                  push(@vals, $avg);
               }
               push(@plota, \@vals);
            }
            $plot->gnuplot_set_plot_titles(map("Link $_", (0..2)));
            $plot->gnuplot_plot_xy( 
               $self->{miniprof}->{raw}->{$core}->{$events[0]}->{time},
               @plota
            );
         }
      }
   }
}

1;
