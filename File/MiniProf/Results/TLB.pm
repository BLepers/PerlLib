use Switch;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;

package File::MiniProf::Results::TLB;
use File::MiniProf;

sub cost {
   my ($self, $info, $parse_options, $opt) = @_;

   if(scalar(keys $info->{usable_events}) == 4) {
      my @events = (
         $self->_scripted_value_to_event(0, $info), #L2M due to TLB
         $self->_scripted_value_to_event(1, $info), #Total Latency
         $self->_scripted_value_to_event(2, $info), #Number of DRAM access used to measure Latency
         $self->_scripted_value_to_event(3, $info), #Cycles
      );
      my @sums = (0, 0, 0, 0);
      
      for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
         for my $evt (0..3) {
            my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[$evt] );
            $sums[$evt] += $sum;
         }
      }

      if($sums[2] > 0 && $sums[3] > 0) {
         $info->{results}->{GLOBAL} = ($sums[0]*$sums[1]/$sums[2])/$sums[3];
      } else {
         $info->{results}->{GLOBAL} = 'No samples';
      }
   } else {
      my @events = (
         $self->_scripted_value_to_event(0, $info), #L2M due to TLB
         $self->_scripted_value_to_event(1, $info), #Total Latency to nodes 0-3
         $self->_scripted_value_to_event(2, $info), #Number of DRAM access used to measure Latency to nodes 0-3
         $self->_scripted_value_to_event(3, $info), #Cycles
         $self->_scripted_value_to_event(4, $info), #Total Latency to nodes 4-7
         $self->_scripted_value_to_event(5, $info), #Number of DRAM access used to measure Latency to nodes 4-7
      );
      my @sums = (0, 0, 0, 0, 0, 0);
      
      for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
         for my $evt (0..5) {
            my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[$evt] );
            $sums[$evt] += $sum;
         }
      }

      if(($sums[2] + $sums[5]) > 0 && $sums[3] > 0) {
         $info->{results}->{GLOBAL} = ($sums[0]*($sums[1]+$sums[4])/($sums[2]+$sums[5]))/$sums[3];
      } else {
         $info->{results}->{GLOBAL} = 'No samples';
      }
   }
}


1;
