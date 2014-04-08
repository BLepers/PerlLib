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

#[ 'ALL0,0', 'NOP0,0', 'ALL0,1', 'USEFUL0,1', etc.]
sub ht_link {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;

   my @events = map { $self->_scripted_value_to_event($_, $info) } (0..15);
   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      for my $link (0..7) {
         my ($avg_all, $sum_all, $count_all) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[2*$link] );
         my ($avg_link, $sum_link, $count_link) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[2*$link+1] );

         next if ($avg_all == 0);
         next if ($sum_all <= $sum_link || $sum_link == 0); # More DATA than NOP+DATA, that's bad (usually disconnected link)
         $info->{results}->{$core}->{'ht_link'.int($link/2).".".($link%2)} = $sum_link/$sum_all; #HT Usage : 0 = good, 1 = bad
      }
   }
}

1;
