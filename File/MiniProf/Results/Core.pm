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

package File::MiniProf::Results::Core;
use File::MiniProf;

sub per_core_sum {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;


   my $tsize = scalar(keys %{$info->{usable_events}}) - 1;

   my @events = map { $self->_scripted_value_to_event($_, $info) } (0..$tsize);
   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my $to_plot = 0;
      for my $i (0..$tsize) {
         my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[$i] );

         my $local_dram = File::MiniProf::_local_dram_fun($self, $core, $opt->{local_dram_fun});

         $info->{results}->{$core}->[$i] = $sum;
         $info->{results}->{GLOBAL}->[$i] += $sum;
         $info->{results}->{"NODE$local_dram"}->[$i] += $sum;

         if($sum > 0) {
            $to_plot = 1;
         }
      }

      if($to_plot && $opt->{gnuplot} && ((!defined $parse_options->{$info->{name}}->{gnuplot}) || ($parse_options->{$info->{name}}->{gnuplot} != 0)) ) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            $plot =  File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name}.' on core '.$core);

            my @plota;
            for my $link (0..$tsize) {
               my @vals = ();
               for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$events[$link]}->{val}}); $i++) {
                  my $val = $self->{miniprof}->{raw}->{$core}->{$events[$link]}->{val}->[$i];
                  push(@vals, $val);
               }
               push(@plota, $self->{miniprof}->{raw}->{$core}->{$events[$link]}->{time});
               push(@plota, \@vals);
            }

            $plot->gnuplot_set_plot_titles(map(($parse_options->{$info->{name}}->{legend}//'')." $_", (0..$tsize)));

            $plot->gnuplot_plot_many(
               @plota
            );
         }
      }
   }
}


1;
