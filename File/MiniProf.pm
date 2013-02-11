#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Switch;
use FindBin;
use lib "$FindBin::Bin";
use Math::BigInt;
use File::Utils;
use File::MiniProf::Results::Avg;
use File::MiniProf::Results::HT;
use File::MiniProf::Results::Core;
use File::MiniProf::Results::DRAM;
use File::MiniProf::Results::Latency;
use File::MiniProf::Results::TLB;

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

my $default_minimum_percentage_running = 0.1;

my %parse_options = (
   ## Processed measurements
   
   IPC => {
      name => 'IPC',                    
      events => [ '76', 'c0' ], # cpu clock unhalted, retired instructions
      value => 'sum_1/sum_0', #Numbers are relative to previous events. 1 is RETIRED.
   },

   INSTRUCTIONS => {
      name => 'Instructions',                    
      events => [ 'c0', '76' ],
      value => 'per_core_sum', #Numbers are relative to previous events. 1 is RETIRED.
   },

   DTLB_MISS_INST => {
      name => 'L1 and L2 DTLB miss per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'DTLB_MISS' ],
      value => 'sum_1/sum_0', 
   },

   HT_LINK_0_0_LOAD => {
      name => 'HT Link 0.0 load',
      events => [ '1FF6', '17F6' ],
      value => 'sum_1/sum_0',
   },

   HT_LINK_0_1_LOAD => {
      name => 'HT Link 0.1 load',
      events => [ '9FF6', '97F6' ],
      value => 'sum_1/sum_0',
   },
   
   HT_LINK_1_0_LOAD => {
      name => 'HT Link 1.0 load',
      events => [ '1FF7', '17F7' ],
      value => 'sum_1/sum_0',
   },

   HT_LINK_1_1_LOAD => {
      name => 'HT Link 1.1 load',
      events => [ '9FF7', '97F7' ],
      value => 'sum_1/sum_0',
   },

   HT_LINK_2_0_LOAD => {
      name => 'HT Link 2.0 load',
      events => [ '1FF8', '17F8' ],
      value => 'sum_1/sum_0',
   },

   HT_LINK_2_1_LOAD => {
      name => 'HT Link 2.1 load',
      events => [ '9FF8', '97F8' ],
      value => 'sum_1/sum_0',
   },

   HT_LINK_3_0_LOAD => {
      name => 'HT Link 3.0 load',
      events => [ '100001FF9', '1000017F9' ],
      value => 'sum_1/sum_0',
   }, 
   
   HT_LINK_3_1_LOAD => {
      name => 'HT Link 3.1 load',
      events => [ '100009FF9', '1000097F9' ],
      value => 'sum_1/sum_0',
   },

   ITLB_MISS_INST => {
      name => 'L1 and L2 ITLB miss per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'ITLB_MISS' ],
      value => 'sum_1/sum_0', 
   },
   
   L2APPI => {
      name => 'L2 accesses caused by prefetcher attempts per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_ACCESSES_PREFETCH' ],
      value => 'sum_1/sum_0', 
   },
   
   L2ADCFPI => {
      name => 'L2 accesses caused by instruction cache fill per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_ACCESSES_DC_FILL' ],
      value => 'sum_1/sum_0', 
   },
   
   L2AICFPI => {
      name => 'L2 accesses caused by data cache fill per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_ACCESSES_IC_FILL' ],
      value => 'sum_1/sum_0', 
   },
   
   L2ATLBFPI => {
      name => 'L2 Data accesses caused by tlb fill per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_ACCESSES_TLB_FILL' ],
      value => 'sum_1/sum_0', 
   },
 
   L2ATLBFPI2 => {
      name => 'L2 Data accesses caused by tlb fill per retired instructions',                    
      events => [ 'c0', '47d' ],
      value => 'sum_1/sum_0', 
   },

   L2MDCFPI => {
      name => 'L2 misses caused by instruction cache fill per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_MISSES_DC_FILL' ],
      value => 'sum_1/sum_0', 
   },
   
   L2MICFPI => {
      name => 'L2 misses caused by data cache fill per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_MISSES_IC_FILL' ],
      value => 'sum_1/sum_0', 
   },
   
   L2MTLBFPI => {
      name => 'L2 misses caused by tlb fill per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_MISSES_TLB_FILL' ],
      value => 'sum_1/sum_0', 
   },
  
  L2MTLBFPI2 => {
      name => 'L2 misses caused by tlb fill per retired instructions',
      events => [ 'c0', '47e' ],
      value => 'sum_1/sum_0',
  },
   
   L2MPPI => {
      name => 'L2 misses caused by prefetcher attempts per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'L2_MISSES_PREFETCH' ],
      value => 'sum_1/sum_0', 
   },
   
   MCTPPI => {
      name => 'Memory controller attempts per retired instructions',                    
      events => [ 'RETIRED_INSTRUCTIONS', 'MCR_PREFETCH' ],
      value => 'sum_1/sum_0-global', 
   },

   ##############################################
   ### Caches
   ##############################################

   L1_Miss_RATIO => {
      name => 'L1 Miss Ratio',     
      events => [ '40', '41' ], # L1 accesses, L1 misses 
      value => 'sum_1/sum_0', 
      gnuplot_range => [ 0, 1 ],
   },

   L1_MISS_INST => {
      name => 'L1 Misses per Retired Instruction',                    
      events => [ 'c0', '41' ], # retired instructions, L1 misses
      value => 'sum_1/sum_0', 
   },
   
   L1_ACCESS_INST => {
      name => 'L1 Accesses per Retired Instruction',                    
      events => [ 'c0', '40' ], # retired instructions, L1 accesses
      value => 'sum_1/sum_0', 
   },
  
   L2_MISS_RATIO => {
      name => 'L2 Miss Ratio',
      events => [ '277d', '0f7e' ], # L2 accesses, L2 misses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   L2_MISS_INST => {
      name => 'L2 Misses per Retired Instruction',                    
      events => [ 'c0', '0f7e' ], # retired instructions, L2 misses
      value => 'sum_1/sum_0', 
   },

   L2_ACCESS_INST => {
      name => 'L2 Accesses per Retired Instruction',                    
      events => [ 'c0', '277d' ], # retired instructions, L2 accesses
      value => 'sum_1/sum_0', 
   },

   L2_MISS_RATIO_JEREMY => {
      name => 'L2 Miss Ratio',
      events => [ 'ff7d', 'ff7e' ], # L2 accesses, L2 misses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   L2_MISS_INST_JEREMY => {
      name => 'L2 Misses per Retired Instruction',                    
      events => [ 'c0', 'ff7e' ], # retired instructions, L2 misses
      value => 'sum_1/sum_0', 
   },

   L2_ACCESS_INST_JEREMY => {
      name => 'L2 Accesses per Retired Instruction',                    
      events => [ 'c0', 'ff7d' ], # retired instructions, L2 accesses
      value => 'sum_1/sum_0', 
   },


   L3_MISS_RATIO => {
      name => 'L3 Miss Ratio',     
      events => [ '40040f7e0', '40040f7e1' ], # L3 accesses, L3 misses
      value => 'sum_1/sum_0', 
      gnuplot_range => [ 0, 1 ],
   },

   L3_MISS_INST => {
      name => 'L3 Misses per Retired Instruction',                    
      events => [ 'c0', '40040f7e1' ], # retired instructions, L3 misses
      value => 'sum_1/sum_0-global', 
   },
   
   L3_ACCESS_INST => {
      name => 'L3 Accesses per Retired Instruction',                    
      events => [ 'c0', '40040f7e0' ], # retired instructions, L3 accesses
      value => 'sum_1/sum_0-global', 
   }, 

   L3_MISS_RATIO_JEREMY => {
      name => 'L3 Miss Ratio',     
      events => [ '40040ffe0', '40040ffe1' ], # L3 accesses, L3 misses
      value => 'sum_1/sum_0', 
      gnuplot_range => [ 0, 1 ],
   },

   L3_MISS_INST_JEREMY => {
      name => 'L3 Misses per Retired Instruction',                    
      events => [ 'c0', '40040ffe1' ], # retired instructions, L3 misses
      value => 'sum_1/sum_0-global', 
   },
   
   L3_ACCESS_INST_JEREMY  => {
      name => 'L3 Accesses per Retired Instruction',                    
      events => [ 'c0', '40040ffe0' ], # retired instructions, L3 accesses
      value => 'sum_1/sum_0-global', 
   }, 


   ICACHE_MISS_RATIO => {
       name => 'Instruction Cache Miss Ratio',
       events => [ '80', '81' ], # instruction cache fetches, instruction cache misses
       value => 'sum_1/sum_0',
   },

   ICACHE_MISS_INST => {
       name => 'Instruction Cache Misses per Retired Instruction',
       events => [ 'c0', '81' ], # retired instructions, instruction cache misses
       value => 'sum_1/sum_0',
   },

   ICACHE_ACCESS_INST => {
       name => 'Instruction Cache Accesses per Retired Instruction',
       events => [ 'c0', '80' ], # retired instructions, instruction cache fetches
       value => 'sum_1/sum_0',
   },

   ##############################################
   ### TLB
   ##############################################

   L1TLB_MISS_PER_INSTR => {
      name => 'L1 TLB Miss per Instruction',     
      events => [ 'f45', 'f46', 'c0' ], # L2 DTLB hit, L2 DTLB miss, retired instructions
      value => '(sum_0+sum_1)/sum_2', # (L2 hit + L2 miss) / retired instructions 
   },

   L1TLB_HIT_RATIO => {
      name => 'L1 TLB Hit Ratio',     
      events => [ 'f4d', 'f45', 'f46' ], # L1 DTLB hit, L2 DTLB hit, L2 DTLB miss
      value => 'sum_0/sum_all', # L1 hit / (L1 hit + L2 hit + L2 miss)
      gnuplot_range => [ 0, 1 ],
   },

   L2TLB_MISS_PER_INSTR=> {
      name => 'L2 TLB Miss per Instruction',     
      events => [ 'c0', 'f46' ], # retired instructions, L2 DTLB hit 
      value => 'sum_1/sum_0',
   },
 
   L2TLB_HIT_RATIO => {
      name => 'L2 TLB Hit Ratio',     
      events => [ 'f45', 'f46' ], # L2 DTLB hit, L2 DTLB miss
      value => 'sum_0/sum_all', # L2 hit / (L2 hit + L2 miss)
      gnuplot_range => [ 0, 1 ],
   },

   #INTEL ONLY!!
   #Two rules to do the same thing because there are 2 counters to count the same thing!
   PERCENT_PMH_BUSY => {
      name => 'Percent of time whent the PMH is busy (Intel)',     
      events => [ '3c', '408' ], # #cycles-pmh-busy/#cycles 
      value => 'sum_1/sum_0', 
   },
   PERCENT_PMH_BUSY2 => {
      name => 'Percent of time whent the PMH is busy (Intel)',     
      events => [ '3c', '449' ], # #cycles-pmh-busy/#cycles
      value => 'sum_1/sum_0', 
   },


   HT_LINK => {
      name => 'Usage of HT Links',
      events => [ 'HT_LINK\d', 'HT_LINK0-NOP', 'HT_LINK1-NOP', 'HT_LINK2-NOP' ],
      value => 'ht_link',
      gnuplot_range => [ 0, 100 ],
   },

   CPU_DRAM => {
      name => 'CPU to DRAM',
      events => [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', 'CPU_DRAM_NODE2', 'CPU_DRAM_NODE3' ],
      value => 'per_core_avg',
      legend => 'DRAM of node',
      #gnuplot_range => [ 0, 250 ],
   },

   LOCAL_DRAM_RATIO => {
      name => 'CPU to DRAM locality',
      events => [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', 'CPU_DRAM_NODE2', 'CPU_DRAM_NODE3' ],
      value => 'locality_per_node',
      legend => 'Local DRAM of node',
   },

   CPU_DRAM2 => {
      name => 'CPU to DRAM',
      events => [ '1004001e0', '1004002e0', '1004004e0', '1004008e0' ],
      value => 'per_core_avg',
      legend => 'DRAM of node',
      #gnuplot_range => [ 0, 250 ],
   },

   LOCAL_DRAM_RATIO2 => {
      name => 'CPU to DRAM locality',
      events => [ '1004001e0', '1004002e0', '1004004e0', '1004008e0' ],
      value => 'locality_per_node',
      legend => 'Local DRAM of node',
      gnuplot_per_core => 1,
   },

   MAPI => {
      name => 'CPU to all DRAM per instruction',
      events => [ 'RETIRED_INSTRUCTIONS', 'CPU_DRAM_ALL' ],
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
      name => 'DRAM read prefetch ratio',
      events => ['MCR_READ', 'MCR_PREFETCH'],
      value => 'sum_1/sum_0',
   },
   
   LOCKPI => {
      name => 'Bus locking per instruction',
      events => [ 'RETIRED_INSTRUCTIONS', 'LOCKED_OPERATIONS' ],
      value => 'sum_1/sum_0',
   },

   DCMR => {
      name => 'DCMR',
      events => [ 'DCR_ALL', 'DCR_MODIFIED' ],
      value => 'sum_1/sum_0',
   },

   DPPI => {
      name => 'Data prefetcher per instruction',
      events => [ 'DATA_PREFETCHER_SUCCESS', 'RETIRED_INSTRUCTIONS' ],
      value => 'sum_1/sum_0',
   },

   MCPPI => {
      name => 'DRAM prefetch per instruction',
      events => ['MCT_PREFETCH', 'RETIRED_INSTRUCTIONS'],
      value => 'sum_1/sum_0',
   },



   ##### Not really processed data
   READ_LATENCY_0 => {
      name => 'Latency to node 0',
      events => [ '100401fE3', '100401fE2' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   READ_LATENCY_1 => {
      name => 'Latency to node 1',
      events => [ '100402fE3', '100402fE2' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   READ_LATENCY_2 => {
      name => 'Latency to node 2',
      events => [ '100404fE3', '100404fE2' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   READ_LATENCY_3 => {
      name => 'Latency to node 3',
      events => [ '100408fE3', '100408fE2' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   READ_LATENCY_GLOB => {
      name => 'Latency',
      events => [ '10040ffE3', '10040ffE2' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
      gnuplot_per_core => 1,
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
   
   
   ### CPU Latencies
   CPU_LATENCY_0 => {
      name => 'Latency to node 0',
      events => [ 'CPU_CMD_NUMBER_N0', 'CPU_CMD_LATENCY_N0' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   CPU_LATENCY_1 => {
      name => 'Latency to node 1',
      events => [ 'CPU_CMD_NUMBER_N1', 'CPU_CMD_LATENCY_N1' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   CPU_LATENCY_2 => {
      name => 'Latency to node 2',
      events => [ 'CPU_CMD_NUMBER_N2', 'CPU_CMD_LATENCY_N2' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },

   CPU_LATENCY_3 => {
      name => 'Latency to node 3',
      events => [ 'CPU_CMD_NUMBER_N3', 'CPU_CMD_LATENCY_N3' ], #Number of mem accesses monitored, latency of these accesses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1000 ],
   },
   
   CPU_CMD_LATENCY_0 => {
      name => 'CPU_CMD_LATENCY_0',
      events => [ 'CPU_CMD_LATENCY_N0' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   CPU_CMD_LATENCY_1 => {
      name => 'CPU_CMD_LATENCY_1',
      events => [ 'CPU_CMD_LATENCY_N1' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   CPU_CMD_LATENCY_2 => {
      name => 'CPU_CMD_LATENCY_2',
      events => [ 'CPU_CMD_LATENCY_N2' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   CPU_CMD_LATENCY_3 => {
      name => 'CPU_CMD_LATENCY_3',
      events => [ 'CPU_CMD_LATENCY_N3' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
  CPU_CMD_REQUESTS_0 => {
      name => 'CPU_CMD_REQUESTS_0',
      events => [ 'CPU_CMD_NUMBER_N0' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   CPU_CMD_REQUESTS_1 => {
      name => 'CPU_CMD_REQUESTS_1',
      events => [ 'CPU_CMD_NUMBER_N1' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   CPU_CMD_REQUESTS_2 => {
      name => 'CPU_CMD_REQUESTS_2',
      events => [ 'CPU_CMD_NUMBER_N2' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   CPU_CMD_REQUESTS_3 => {
      name => 'CPU_CMD_REQUESTS_3',
      events => [ 'CPU_CMD_NUMBER_N3' ],
      value => 'latencies',
      gnuplot => 0,
   },
   
   TLB_COST => {
      name => '% of time spent doing TLB Miss',
      events => ['47e', '10040ffE2', '10040ffE3', '76' ],
      value => 'tlb_cost',
   },
   
   PROPORTION_L2M_TLB => {
      name => 'Proportion of L2 misses due to TLB fill',
      events => ['ff7e', '47e'],
      value => 'sum_1/sum_0',
   },

   ### Useless ?
   HT_DATA => {
      name => 'HT Links data',
      events => [ 'HT_LINK0-DATA', 'HT_LINK1-DATA', 'HT_LINK2-DATA' ],
      value => 'per_core_avg',
      legend => 'HT link',
   },
   
   LOCK => {
      name => 'Bus locking',
      events => [ 'LOCKED_OPERATIONS' ],
      value => 'per_core_avg',
      legend => 'LOCK',
      
   },   
   
);


sub _local_dram_fun {
   my ($self, $core, $local_dram_fun) = @_;
   
   
   if(defined $self->{memory_mapping}) {
      my %mapping = %{$self->{memory_mapping}};
      my $local_dram = -1;
      for my $d (keys %mapping) {
         for my $c (@{$mapping{$d}}) {
            if($c == $core) {
               $local_dram = $d;
               last;
            } 
         }
         
         last if ($local_dram != -1);
      }
      
      die "Did not find any die for core $core\n" if ($local_dram == -1);
      return $local_dram;
   }
   elsif (defined $local_dram_fun) {
      return &{$local_dram_fun} ($core);
   }
   else {
      print "I don't know what's the local DRAM. Exiting...\n";
      exit;
   }
}

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
         my $evt_hex = $evt;
         #For HWC events like '76', we also consider '400076' as a valid match
         #(The extra 40000 was sometimes added in Miniprof scripts to explicitly start counters)
         if($evt_hex =~ m/^[0-9a-fA-F]+$/) {
            $evt_hex = Math::BigInt->new('0x'.$evt_hex);
            if($evt_hex & 0x400000) {
               $evt_hex -= 0x400000;
            } else {
               $evt_hex += 0x400000;
            }
            $evt_hex = "".$evt_hex->as_hex;
            $evt_hex =~ s/^0x//;
         }
         for my $avail_evt (keys %{$self->{miniprof}->{events}}) {
            if(($self->{miniprof}->{events}->{$avail_evt}->{name} =~ m/^$evt$/)
               || ($self->{miniprof}->{events}->{$avail_evt}->{hwc_value} =~ m/^$evt$/i)
               || ($self->{miniprof}->{events}->{$avail_evt}->{hwc_value} =~ m/^$evt_hex$/i)) {
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

sub _nb_events {
   my ($self, $info) = @_;
   return scalar(@{$parse_options{$info->{name}}->{events}});
}

sub _do_info {
   my ($self, $info, %opt) = @_;
   return if(!defined($parse_options{$info->{name}}->{value}));

   switch($parse_options{$info->{name}}->{value}) {
      case 'sum_1/sum_0' {
         File::MiniProf::Results::Avg::sum_1_div_sum_0_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'sum_0/sum_all' {
         File::MiniProf::Results::Avg::sum_0_div_sum_all_per_core($self, $info, \%parse_options, \%opt);
      }
      case '(sum_0+sum_1)/sum_2' {
         File::MiniProf::Results::Avg::sum_0_sum_1_div_sum_2_per_core($self, $info, \%parse_options, \%opt);
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
      case 'per_core_avg' {
         File::MiniProf::Results::Core::per_core($self, $info, \%parse_options, \%opt);
      }
      case 'per_core_sum' {
         File::MiniProf::Results::Core::per_core_sum($self, $info, \%parse_options, \%opt);
      }
      case 'locality_per_node' {
         File::MiniProf::Results::DRAM::local_dram_usage($self, $info, \%parse_options, \%opt);
      }
      case 'latencies' {
         File::MiniProf::Results::Latency::sum($self, $info, \%parse_options, \%opt);
      }
      case 'tlb_cost' {
         File::MiniProf::Results::TLB::cost($self, $info, \%parse_options, \%opt);
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
      #print $line;
      if($line =~ m/#Event (\d): ([^\s]+) \((\w+)\)/) {
         $self->{miniprof}->{events}->{$1}->{name} = $2;
         $self->{miniprof}->{events}->{$1}->{hwc_value} = $3;
      }
      elsif ($line =~ m/#Clock speed: (\d+)/) {
         $self->{miniprof}->{freq} = $1;
         $freq = $1;
      }
      elsif ($line =~ m/#Node\s+(\d+)\s+:\s+(.*)/) {
         my @cores;
         my $cores_s = $2;
         my $node = $1;
         while($cores_s =~ m/(\d+)/g){
            #print "Find core $1 for node $node\n";
            push @cores, int($1);
         }
         $self->{memory_mapping}->{$node} = \@cores;
         $freq = $1;
      }

      last if($line =~ m/#Event	Core/);
      next if($line =~ m/^#/);
      next if($line =~ m/^signal/);
   }

   $self->_find_something_to_do;
   
   my $first_time;
   my $line_no = 0;
   my %filtered;

   while (my $line = <$self>) {
      $line_no++;

      next if($line =~ m/^#/);
      next if($line =~ m/^signal/);

      my @content = split(/\s+/, $line); 
      (my $event, my $core, my $time, my $value) = @content;
      
      if(!defined $event || !defined $core || !defined $time || !defined $value){
         print "[$self] Unknown/incomplete line (file: ".$self->{filename}.", line $line_no): $line\n";
         next;
      }

      my $logical_time;

      if(scalar(@content) == 6) {
         my $percentage_running = $content[4];
         $logical_time = $content[5];

         if(defined $filtered{$logical_time}) {
            next;
         }

         if($percentage_running > 0) {
            $value /= $percentage_running;
         }
         elsif($percentage_running <= 0) {
            #print "[WARNING] Ignoring, the counter did not run (file ".$self->{filename}.", line $line_no): $line";

            ## Prevent future value to be added -- For all events (because when they are scheduled together that's for a reason usually)
            $filtered{$logical_time} = "removed";

            ## Remove values that may have been already added
            for my $c (keys %{$self->{miniprof}->{raw}}) {
               for my $e (keys %{$self->{miniprof}->{raw}->{$c}}) {
                  if (defined $self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}) {
                     my @array_lt = @{$self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}};

                     if(($#array_lt >= 0) && ($array_lt[$#array_lt] == $logical_time)) {
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{val}});
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{time}});
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}});
                     }
                  }
                  else {
                     print "BUG !\n";
                     print main::Dumper($self->{miniprof}->{raw}->{$c}->{$e});
                     exit;
                  }
               }
            }
            
            next;
         }
      }

      $first_time //= $time;
      $time = ($time-$first_time)/$freq;

      #TODO: ignore time below a defined threshold
      #print "$opt{miniprof_mintime}\t$opt{miniprof_maxtime}\n";

      if( ((defined $opt{miniprof_mintime}) && $time < $opt{miniprof_mintime}) 
         || 
         ((defined $opt{miniprof_maxtime}) && $time > $opt{miniprof_maxtime})){

         if(defined $logical_time) {
            ## Prevent future value to be added -- For all events (because when they are scheduled together that's for a reason usually)
            $filtered{$logical_time} = "removed";

            ## Remove values that may have been already added
            for my $c (keys %{$self->{miniprof}->{raw}}) {
               for my $e (keys %{$self->{miniprof}->{raw}->{$c}}) {
                  if (defined $self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}) {
                     my @array_lt = @{$self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}};

                     if($array_lt[$#array_lt] == $logical_time) {
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{val}});
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{time}});
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}});
                     }
                  }
                  else {
                     print "BUG !\n";
                     print main::Dumper($self->{miniprof}->{raw}->{$c}->{$e});
                     exit;
                  }
               }
            }
         }

         next;
      }

      #print main::Dumper($opt{cores});
      
      if((!defined $opt{cores}) || ($core ~~ @{$opt{cores}})){
         push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{val}}, $value);
         push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{time}}, $time);
         if(defined $logical_time) {
            push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{logical_time}}, $logical_time);
         }
      }
   }

   print "[WARNING] Ignoring ".(scalar(keys %filtered))." entries (file = ".$self->{filename}.")\n" if(scalar(keys %filtered) > 1);

   for my $evt (keys %{$self->{miniprof}->{events}}) {
      for my $core (keys %{$self->{miniprof}->{raw}}) {
         #print "Event $evt, core $core : ".(scalar(@{$self->{miniprof}->{raw}->{$core}->{$evt}->{time}}))." entries\n";

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
