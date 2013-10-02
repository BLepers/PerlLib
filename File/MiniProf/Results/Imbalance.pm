package File::MiniProf::Results::Imbalance;
use File::MiniProf;
use List::Util qw(sum);

sub imbalance {
   my ($self, $info, $parse_options, $opt) = @_;

   my $nb_events = scalar(keys $info->{usable_events});

   my  $plot;

   my @event = map { $self->_scripted_value_to_event($_, $info) } (0..($nb_events - 1));
   my @sums = (0)x(scalar(@event));

   for(my $i = 0; $i < $nb_events; $i++) {
      for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
         my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event[$i]);
         $sums[$i] += $sum;
      }
   }

   my $avg = _imb_average(\@sums);
   my $dev = _imb_stdev(\@sums);
   if($dev) {
      $info->{results}->{ALL} = 100*$dev/$avg;
   } else {
      $info->{results}->{ALL} = 'No samples';
   }
}


sub _imb_average{
        my($data) = @_;
        if (not @$data) {
                die("Empty array\n");
        }
        my $total = 0;
        foreach (@$data) {
                $total += $_;
        }
        my $average = $total / @$data;
        return $average;
}
sub _imb_stdev{
        my($data) = @_;
        if(@$data == 1){
                return 0;
        }
        my $average = &_imb_average($data);
        my $sqtotal = 0;
        foreach(@$data) {
                $sqtotal += ($average-$_) ** 2;
        }
        my $std = ($sqtotal / (@$data-1)) ** 0.5;
        return $std;
}

1;
