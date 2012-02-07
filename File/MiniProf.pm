#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Switch;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use File::MiniProf::Results::Avg;
use File::MiniProf::Results::HT;
use File::MiniProf::Results::Core;
use File::MiniProf::Results::DRAM;
use File::MiniProf::Results::Latency;

package File::MiniProf;
=head
TODO: Add miniprof_min/max_time + need to parse the cpu frequency (1st line) to convert rdt in seconds.

Usage:
   $file->miniprof_parse(%opt);

   %opt :
      gnuplot => 1            : Activate a gnuplot output (default 0)
      gnuplot_max_cpu => x    : Limit the gnuplot output to CPUs [0..x[ (default : all CPUs are plotted)


Returns:
{
   events {          #List of available events in the file.
      $Event number in the file => {
         name        => $Event name,
         hwc_value   => $Event performance counter value,
      }
   }
   avail_info [      #List of things we were able to do with these events. Each 'thing' is a hash:
      {
         name => $Name of the thing (e.g. IPC)
         usable_events {      #Events used to do this thing.
            $Event name => $Event number in the file
         }
         results {
            $Core number => $Value of the thing  (e.g 0 => 0.30)
         }
      }
   ]
   analysed {
      Contains average, sum & count of events available in the file, for each core.
   }
   raw {
      Contains the raw values, as read in the file. Should never be useful (use analysed).
   }
=cut

my %parse_options = (
   IPC => {
      name => 'IPC',                    
      events => [ 'CPU_CLK_UNHALTED', 'RETIRED_INSTRUCTIONS' ],
      value => 'sum_1/sum_0', #Numbers are relative to previous events. 1 is RETIRED.
   },
   
   L3_MISS_INST => {
      name => 'L3 misses per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L3_MISSES' ],
      value => 'sum_1/sum_0-global', 
   },
   
   L3_RATIO => {
      name => 'L3 Miss Ratio',                    
      events => [ 'L3_ACCESSES', 'L3_MISSES' ],
      value => 'sum_1/sum_0', 
      gnuplot_range => [ 0, 1 ],
   },

   LATENCY_0 => {
      name => 'Latency to node 0',
      events => [ '100401fE3', '100401fE2' ], #Number of mem accesses monitores, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   LATENCY_1 => {
      name => 'Latency to node 1',
      events => [ '100402fE3', '100402fE2' ], #Number of mem accesses monitores, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   LATENCY_2 => {
      name => 'Latency to node 2',
      events => [ '100404fE3', '100404fE2' ], #Number of mem accesses monitores, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   LATENCY_3 => {
      name => 'Latency to node 3',
      events => [ '100408fE3', '100408fE2' ], #Number of mem accesses monitores, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },
   
   READ_CMD_LATENCY_0 => {
      name => 'READ_CMD_LATENCY_0',
      events => [ '100401fE2' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   READ_CMD_LATENCY_1 => {
      name => 'READ_CMD_LATENCY_1',
      events => [ '100402fE2' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   READ_CMD_LATENCY_2 => {
      name => 'READ_CMD_LATENCY_2',
      events => [ '100404fE2' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   READ_CMD_LATENCY_3 => {
      name => 'READ_CMD_LATENCY_3',
      events => [ '100408fE2' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
  READ_CMD_REQUESTS_0 => {
      name => 'READ_CMD_REQUESTS_0',
      events => [ '100401fE3' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   READ_CMD_REQUESTS_1 => {
      name => 'READ_CMD_REQUESTS_1',
      events => [ '100402fE3' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   READ_CMD_REQUESTS_2 => {
      name => 'READ_CMD_REQUESTS_2',
      events => [ '100404fE3' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   READ_CMD_REQUESTS_3 => {
      name => 'READ_CMD_REQUESTS_3',
      events => [ '100408fE3' ],
      value => 'latencies',
      gnuplot => 0,
   },

   HT_LINK => {
      name => 'Usage of HT Links',
      events => [ '403ff8', 'HT_LINK0-NOP', 'HT_LINK1-NOP', 'HT_LINK2-NOP' ],
      value => 'ht_link',
      gnuplot_range => [ 0, 100 ],
   },
   
   HT_DATA => {
      name => 'HT Links data',
      events => [ 'HT_LINK0-DATA', 'HT_LINK1-DATA', 'HT_LINK2-DATA' ],
      value => 'per_core',
      legend => 'HT link',
   },

   CPU_DRAM => {
      name => 'CPU to DRAM',
      events => [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', 'CPU_DRAM_NODE2', 'CPU_DRAM_NODE3' ],
      #events => [ 'CPUDRAM_TO_NODE0', 'CPUDRAM_TO_NODE1', 'CPUDRAM_TO_NODE2', 'CPUDRAM_TO_NODE3' ],
      #events => [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1'],
      value => 'per_core',
      legend => 'DRAM of node',
      #gnuplot_range => [ 0, 250 ],
   },

   LOCAL_DRAM_RATIO => {
      name => 'CPU to DRAM locality',
      events => [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', 'CPU_DRAM_NODE2', 'CPU_DRAM_NODE3' ],
      value => 'locality_per_node',
      legend => 'Local DRAM of node',
   },

   MAPI => {
      name => 'CPU to all DRAM per instruction',
      events => [ 'RETIRED_INSTRUCTIONS', 'CPU_DRAM_ALL' ],
      value => 'sum_1/sum_0-global',
   },
 
   #Same as previous rule but with different events name
   CPU_DRAM_PER_INST2 => {
      name => 'CPU to all DRAM per instruction',
      events => ['RETIRED_INSTR', 'CPUDRAM_TO_ALL'],
      value => 'sum_1/sum_0-global',
   },
   
   DRAM_RW_RATIO => {
      name => 'DRAM read/write ratio',
      events => ['MCR_READ_WRITE', 'MCR_READ'],
      value => 'sum_1/sum_0',
   },
   
   DRAM_RW_RATIO_NO_PREFECTH => {
      name => 'DRAM read/write ratio',
      events => ['MCR_READ_WRITE', 'MCR_READ', 'MCR_PREFETCH'],
      value => '(sum_1-sum_2)/sum_0',
   },
   
   DRAM_READ_PREFETCH_RATIO => {
      name => 'DRAM read/write ratio',
      events => ['MCR_READ', 'MCR_PREFETCH'],
      value => 'sum_1/sum_0',
   }
   
   
);

sub _find_something_to_do {
   my ($self) = @_;
   if(!defined($self->{miniprof}->{events})) {
      die "No event found in $self";
   }

   for my $known_evt (keys %parse_options) {
      my $fail = 0;
      my %matches = ();
      for my $evt (@{$parse_options{$known_evt}->{events}}) {
         my $match = 0;
         for my $avail_evt (keys %{$self->{miniprof}->{events}}) {
            if(($self->{miniprof}->{events}->{$avail_evt}->{name} =~ m/^$evt$/)
               || ($self->{miniprof}->{events}->{$avail_evt}->{hwc_value} =~ m/^$evt$/i)) {
               $match = 1;
               $matches{$evt} = $avail_evt;
               last;
            }
         }
         if(!$match) {
            $fail = 1;
            last;
         }
      }
      if(!$fail) {
         push(@{$self->{miniprof}->{avail_info}}, {
               name => $known_evt,
               usable_events => \%matches,
            });
      }
   }
   if(!defined($self->{miniprof}->{avail_info})) {
      die "Found nothing to do with events [".join(", ", map($_->{name}, (values %{$self->{miniprof}->{events}})))."]";
   }
}

sub _scripted_value_to_event {
   my ($self, $scripted_val, $info) = @_;
   my $event_name = $parse_options{$info->{name}}->{events}->[$scripted_val];
   return $info->{usable_events}->{$event_name};
}

sub _do_info {
   my ($self, $info, %opt) = @_;
   return if(!defined($parse_options{$info->{name}}->{value}));


   switch($parse_options{$info->{name}}->{value}) {
      case 'sum_1/sum_0' {
         File::MiniProf::Results::Avg::sum_1_div_sum_0_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'sum_1/sum_0-global' {
         File::MiniProf::Results::Avg::sum_1_div_sum_0_global($self, $info, \%parse_options, \%opt);
      }
      case '(sum_1-sum_2)/sum_0' {
         File::MiniProf::Results::Avg::sum_1_sum_2_div_sum_0_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'ht_link' {
         File::MiniProf::Results::HT::ht_link($self, $info, \%parse_options, \%opt);
      }
      case 'per_core' {
         File::MiniProf::Results::Core::per_core($self, $info, \%parse_options, \%opt);
      }
      case 'locality_per_node' {
         File::MiniProf::Results::DRAM::local_dram_usage($self, $info, \%parse_options, \%opt);
      }
      case 'latencies' {
         File::MiniProf::Results::Latency::sum($self, $info, \%parse_options, \%opt);
      }
      else {
         die $parse_options{$info->{name}}->{value}." function not implemented yet!";
      }
   }
}

sub miniprof_parse {
   my ($self, %opt) = @_;
   my $freq;
   while (my $line = <$self>) {
      if($line =~ m/#Event (\d): ([^\s]+) \((\w+)\)/) {
         $self->{miniprof}->{events}->{$1}->{name} = $2;
         $self->{miniprof}->{events}->{$1}->{hwc_value} = $3;
      }
      elsif ($line =~ m/#Clock speed: (\d+)/) {
         $self->{miniprof}->{freq} = $1;
         $freq = $1;
      }

      last if($line =~ m/#Event	Core/);
      next if($line =~ m/^#/);
      next if($line =~ m/^signal/);
   }
   $self->_find_something_to_do;
   
   my $first_time;
   while (my $line = <$self>) {

      next if($line =~ m/^#/);
      next if($line =~ m/^signal/);

      (my $event, my $core, my $time, my $value) = ($line =~ m/(\d+)\t(\d+)\t(\d+)\t(\d+)/);
      
      if(!defined $event || !defined $core || !defined $time || !defined $value){
         print "Warning: found an unknown/incomplete line: $line\n";
         next;
      }
      
      $first_time //= $time;
      $time = ($time-$first_time)/$freq;

      #TODO: ignore time below a defined threshold
      next if( 
         ((defined $opt{miniprof_mintime}) && $time < $opt{miniprof_mintime}) 
         || 
         ((defined $opt{miniprof_maxtime}) && $time > $opt{miniprof_maxtime})
      );

      #print main::Dumper($opt{cores});
      
      if((!defined $opt{cores}) || ($core ~~ @{$opt{cores}})){
         push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{val}}, $value);
         push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{time}}, $time);
      }
   }
   for my $evt (keys %{$self->{miniprof}->{events}}) {
      for my $core (keys %{$self->{miniprof}->{raw}}) {
         my @analyse = _miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $evt);
         $self->{miniprof}->{analysed}->{$core}->{$self->{miniprof}->{events}->{$evt}->{name}} = {
            average => $analyse[0],
            sum => $analyse[1],
            count => $analyse[2],
         };
         $self->{miniprof}->{analysed}->{$core}->{$self->{miniprof}->{events}->{$evt}->{hwc_value}} = {
            average => $analyse[0],
            sum => $analyse[1],
            count => $analyse[2],
         };
      }
   }
   for my $evt (@{$self->{miniprof}->{avail_info}}) {
      $self->_do_info($evt, %opt);
   }
   return $self->{miniprof};
}

sub _miniprof_get_average_and_sum {
   my ($array_ref, $index) = @_;
   return @{$array_ref->{$index.'_analysed'}} if defined $array_ref->{$index.'_analysed'};

   my $sum = 0;
   my $count = 0;
   for my $val (@{$array_ref->{$index}->{val}}) {
      $sum += $val;
      $count++;
   }
   my @ret;
   if($count != 0) {
      @ret = ($sum / $count, $sum, $count);
   } else {
      @ret = (0, $sum, $count);
   }
   $array_ref->{$index.'_analysed'} = \@ret;
   return @ret;
}


