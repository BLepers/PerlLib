#!/usr/bin/perl
use strict;
use warnings;


package File::MiniProf::AMD;

my %parse_options_amd = (
   ## Processed measurements
   IPC => {
      name => 'IPC',
      events => [ '76', 'c0' ], # cpu clock unhalted, retired instructions
      value => 'sum_1/sum_0', #Numbers are relative to previous events. 1 is RETIRED.
   },

   DTLB_MISS_INST => {
      name => 'L1 and L2 DTLB miss per retired instructions',
      events => [ 'RETIRED_INSTRUCTIONS', 'DTLB_MISS' ],
      value => 'sum_1/sum_0',
   },

   LDST_BUFF_FULL_PER_INST => {
      name => 'Load/Store buffer full per instruction',
      events => [ 'c0', '323' ],
      value => 'sum_1/sum_0',
   },

   LDST_BUFF_FULL_PER_CLK => {
      name => 'Load/Store buffer full per unhalted clk',
      events => [ '76', '323' ],
      value => 'sum_1/sum_0',
   },

   HT_LINK_0_0_LOAD => {
      name => 'HT Link 0.0 load',
      events => [ '1FF6', '17F6' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   HT_LINK_0_1_LOAD => {
      name => 'HT Link 0.1 load',
      events => [ '9FF6', '97F6' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   HT_LINK_1_0_LOAD => {
      name => 'HT Link 1.0 load',
      events => [ '1FF7', '17F7' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   HT_LINK_1_1_LOAD => {
      name => 'HT Link 1.1 load',
      events => [ '9FF7', '97F7' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   HT_LINK_2_0_LOAD => {
      name => 'HT Link 2.0 load',
      events => [ '1FF8', '17F8' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   HT_LINK_2_1_LOAD => {
      name => 'HT Link 2.1 load',
      events => [ '9FF8', '97F8' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   HT_LINK_3_0_LOAD => {
      name => 'HT Link 3.0 load',
      events => [ '100001FF9', '1000017F9' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   HT_LINK_3_1_LOAD => {
      name => 'HT Link 3.1 load',
      events => [ '100009FF9', '1000097F9' ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   ITLB_MISS_INST => {
      name => 'L1 and L2 ITLB miss per retired instructions',
      events => [ 'RETIRED_INSTRUCTIONS', 'ITLB_MISS' ],
      value => 'sum_1/sum_0',
   },

   L2ATLBFPI2 => {
      name => 'L2 Data accesses caused by tlb fill per retired instructions',
      events => [ 'c0', '47d' ],
      value => 'sum_1/sum_0',
   },

   MCTPPI => {
      name => 'MCT prefetch attempts per retired instructions',
      events => [ 'RETIRED_INSTRUCTIONS', 'MCR_PREFETCH' ],
      value => 'sum_1/sum_0-global',
   },

   ##############################################
   ### Caches
   ##############################################

   L1_MISS_RATIO => {
      name => 'L1 Miss Ratio',
      events => [
         [ '40', '41' ], # L1 accesses, L1 misses
         [ '40', 'ff41' ], # L1 accesses, L1 misses
      ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   L1_MISS_INST => {
      name => 'L1 Misses per Retired Instruction',
      events => [
         ['c0', '41' ], # retired instructions, L1 misses
         ['c0', 'ff41' ], # retired instructions, L1 misses
      ],
      value => 'sum_1/sum_0',
   },

   L1_ACCESS_INST => {
      name => 'L1 Accesses per Retired Instruction',
      events => [ 'c0', '40' ], # retired instructions, L1 accesses
      value => 'sum_1/sum_0',
   },

   L2_MISS_RATIO => {
      name => 'L2 Miss Ratio',
      events => [ 'ff7d', 'ff7e' ], # L2 accesses, L2 misses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   L2_MISS_INST => {
      name => 'L2 Misses per Retired Instruction',
      events => [ 'c0', 'ff7e' ], # retired instructions, L2 misses
      value => 'sum_1/sum_0',
   },

   L2_ACCESS_INST => {
      name => 'L2 Accesses per Retired Instruction',
      events => [ 'c0', 'ff7d' ], # retired instructions, L2 accesses
      value => 'sum_1/sum_0',
   },

   L3_MISS_RATIO => {
      name => 'L3 Miss Ratio',
      events => [
         [ '40040f7e0', '40040f7e1' ], # L3 accesses, L3 misses
         [ '40040ffe0', '40040ffe1' ], # L3 accesses, L3 misses
      ],
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   CPU_DRAM_ALL => {
      name => 'Number of memory accesses',
      events => [
         [ '10040ffe0' ],
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '!1004010e0' ],
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '1004010e0', '1004020e0', '1004040e0', '1004080e0' ],
      ],
      value => 'sum_all',
   },

   IMBALANCE => {
      name => 'Imbalance (Carrefour definition - in %)',
      events => [
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '!1004010e0' ],
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '1004010e0', '1004020e0', '1004040e0', '1004080e0' ],
      ],
      value => 'imbalance',
   },

   L3_MISS_INST => {
      name => 'L3 Misses per Retired Instruction',
      events => [
         [ 'c0', '40040f7e1' ], # retired instructions, L3 misses
         [ 'c0', '40040ffe1' ], # retired instructions, L3 misses
      ],
      value => 'sum_1/sum_0-global',
   },

   L3_MISS_CLK => {
      name => 'L3 Misses per Clk',
      events => [
         [ '76', '40040f7e1' ], # retired instructions, L3 misses
         [ '76', '40040ffe1' ], # retired instructions, L3 misses
      ],
      value => 'sum_1/sum_0-global',
   },

   L3_ACCESS_INST => {
      name => 'L3 Accesses per Retired Instruction',
      events => [
         [ 'c0', '40040f7e0' ], # retired instructions, L3 accesses
         [ 'c0', '40040ffe0' ], # retired instructions, L3 accesses
      ],
      value => 'sum_1/sum_0-global',
   },

   L3_LATENCY => {
      name => 'Latency of L3 accesses',
      events => [
         [ '4000002ef', '4000001ef' ], # Number of access, latency count
      ],
      value => 'sum_1/sum_0-global',
   },

   DRAM_ACCESS_INST => {
      name => 'DRAM Accesses per Retired Instruction',
      events => [ 'c0', '100403fe0' ], # retired instructions, DRAM accesses
      value => 'sum_1/sum_0-global',
   },

   MEMORY_CONTROLLER_REQUEST_INST => {
      name => 'Memory Controller Requests per Retired Instruction',
      events => [ 'c0', '10040fff0' ], # retired instructions, Memory controller requests
      value => 'sum_1/sum_0-global',
   },

   MEMORY_CONTROLLER_REQUEST_INST2 => {
      name => 'Memory Controller Requests per Retired Instruction excluding DCT full',
      events => [ 'c0', '100407ff0' ], # retired instructions, Memory controller requests
      value => 'sum_1/sum_0-global',
   },

   MEMORY_CONTROLLER_REQUEST_CLK => {
      name => 'Memory Controller Requests per Retired Instruction',
      events => [ '76', '10040fff0' ], # retired instructions, Memory controller requests
      value => 'sum_1/sum_0-global',
   },

   MEMORY_CONTROLLER_REQUEST_CLK2 => {
      name => 'Memory Controller Requests per Retired Instruction excluding DCT full',
      events => [ '76', '100407ff0' ], # retired instructions, Memory controller requests
      value => 'sum_1/sum_0-global',
   },

   ICACHE_MISS_RATIO => {
       name => 'Instruction Cache Miss Ratio',
       events => [ '80', '81' ], # instruction cache fetches, instruction cache misses
       value => 'sum_1/sum_0',
   },

   FPLDBUFFFULL_PER_INSTR => {
      name => 'FD/LD load buffer full per instruction',
      events => [ 'c0', '34' ],
      value => 'sum_1/sum_0',
   },

   DECODER_EMPTY_PER_INSTR => {
      name => 'Decoder empty per instruction',
      events => [ 'c0', 'd0' ],
      value => 'sum_1/sum_0',
   },

   DISPATH_FAILED_PER_INSTR => {
      name => 'Dispatch failed per instruction',
      events => [ 'c0', 'd1' ],
      value => 'sum_1/sum_0',
   },

   LOCKED_PER_INSTR => {
      name => 'Locked instructions per instruction',
      events => [ 'c0', '124' ],
      value => 'sum_1/sum_0',
   },

   DRAMEO_PER_INSTR => {
      name => 'DRAM Access per instruction',
      events => [ 'c0', '3fe0' ],
      value => 'sum_1/sum_0-global',
   },

   PROBES_PER_INSTR => {
      name => 'Probes per instruction',
      events => [ 'c0', 'fec' ],
      value => 'sum_1/sum_0-global',
   },
   PROBES_MISS_PER_INSTR => {
      name => 'Probes per instruction',
      events => [ 'c0', '1ec' ],
      value => 'sum_1/sum_0-global',
   },
   PROBES_MISS_RATIO => {
      name => 'Probes per instruction',
      events => [ 'fec', '1ec' ],
      value => 'sum_1/sum_0-global',
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

   L1TLB_MISS_PER_INSTR_4k => {
      name => 'L1 TLB Miss per Instruction with 4k pages',
      events => [ '145', '146', 'c0' ], # L2 DTLB hit, L2 DTLB miss, retired instructions
      value => '(sum_0+sum_1)/sum_2', # (L2 hit + L2 miss) / retired instructions
   },

  L1TLB_MISS_PER_INSTR_2M => {
      name => 'L1 TLB Miss per Instruction with 2M pages',
      events => [ '245', '246', 'c0' ], # L2 DTLB hit, L2 DTLB miss, retired instructions
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

   L2TLB_MISS_PER_INSTR_4k=> {
      name => 'L2 TLB Miss per Instruction with 4k pages',
      events => [ 'c0', '146' ], # retired instructions, L2 DTLB hit
      value => 'sum_1/sum_0',
   },

   L2TLB_MISS_PER_INSTR_2M=> {
      name => 'L2 TLB Miss per Instruction with 2M pages',
      events => [ 'c0', '246' ], # retired instructions, L2 DTLB hit
      value => 'sum_1/sum_0',
   },

   L2TLB_HIT_RATIO => {
      name => 'L2 TLB Hit Ratio',
      events => [ 'f45', 'f46' ], # L2 DTLB hit, L2 DTLB miss
      value => 'sum_0/sum_all', # L2 hit / (L2 hit + L2 miss)
      gnuplot_range => [ 0, 1 ],
   },

   L2ATLBFPI => {
      name => 'L2 Data accesses caused by tlb fill per retired instructions',
      events => [
         [ 'RETIRED_INSTRUCTIONS', 'L2_ACCESSES_TLB_FILL' ],
         [ 'c0', '47d' ],
      ],
      value => 'sum_1/sum_0',
   },

   L2MTLBFPI => {
      name => 'L2 misses caused by tlb fill per retired instructions',
      events => [
         [ 'RETIRED_INSTRUCTIONS', 'L2_MISSES_TLB_FILL' ],
         [ 'c0', '47e' ],
      ],
      value => 'sum_1/sum_0',
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
      events => [ '1FF6', '17F6',  #0,0
                  '9FF6', '97F6',  #0,1
                  '1FF7', '17F7',  #1,0
                  '9FF7', '97F7',
                  '1FF8', '17F8',
                  '9FF8', '97F8',
                  '100001FF9', '1000017F9' ,
                  '100009FF9', '1000097F9' ],
      value => 'ht_link',
      gnuplot_range => [ 0, 100 ],
   },

   CPU_DRAM => {
      name => 'CPU to DRAM',
      events => [
         ## 4 nodes
         [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', 'CPU_DRAM_NODE2', 'CPU_DRAM_NODE3', '!CPU_DRAM_NODE4' ],
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '!1004010e0' ],

         ## 8 nodes
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '1004010e0', '1004020e0', '1004040e0', '1004080e0' ],
      ],
      value => 'per_core_sum',
      legend => 'DRAM of node',
      #gnuplot_range => [ 0, 250 ],
   },

   LOCAL_DRAM_RATIO => {
      name => 'CPU to DRAM locality',
      events => [
         ## 2 nodes
         [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', '!CPU_DRAM_NODE2' ],
         [ '1004001e0', '1004002e0', '!1004004e0' ],
         ## 4 nodes
         [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', 'CPU_DRAM_NODE2', 'CPU_DRAM_NODE3', '!CPU_DRAM_NODE4' ],
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '!1004010e0' ],
         ## 8 nodes
         [ 'CPU_DRAM_NODE0', 'CPU_DRAM_NODE1', 'CPU_DRAM_NODE2', 'CPU_DRAM_NODE3', 'CPU_DRAM_NODE4', 'CPU_DRAM_NODE5', 'CPU_DRAM_NODE6', 'CPU_DRAM_NODE7' ],
         [ '1004001e0', '1004002e0', '1004004e0', '1004008e0', '1004010e0', '1004020e0', '1004040e0', '1004080e0' ],
      ],
      value => 'locality_per_node',
      legend => 'Local DRAM of node',
   },

   REMOTE_DRAM_RATIO => {
      name => 'CPU to DRAM non locality',
      events => [
         [ 'b8e9', '98e9' ],
      ],
      value => 'sum_1/sum_0-global',
      legend => 'Local DRAM of node',
   },

   MAPTU => {
      name => 'CPU to all DRAM per clk',
      events => [
            ['76', '10000ffe0']
         ],
      value => 'sum_1/sum_0-global',
   },

   MAPI => {
      name => 'CPU to all DRAM per instruction',
      events => [
            ['RETIRED_INSTRUCTIONS', 'CPU_DRAM_ALL'],
            ['c0', '10000ffe0']
         ],
      value => 'sum_1/sum_0-global',
   },

   MAPI2 => {
      name => 'DRAM read/write ratio',
      events => ['RETIRED_INSTRUCTIONS', 'MCR_READ_WRITE'],
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
      events => [
        [ '10040ffE3#allnodes', '10040ffE2#allnodes', '!10040ffE5', '!10040ffE4' ], #Number of mem accesses monitored, latency of these accesses; #all to indicate that the event must be monitored on ALL cores/nodes
        [ '10040ffE3#allnodes', '10040ffE2#allnodes', '10040ffE5#allnodes', '10040ffE4#allnodes'], #for 8 nodes machines...
      ],
      value => 'sum_odd/sum_even',
      gnuplot_range => [ 0, 1000 ],
      gnuplot_per_core => 1,
   },

   REMOTE_LATENCY_GLOB => {
      name => 'Remote Latency',
      events => [
        [ '10000EFE3', '10000EFE2',
          '10000DFE3', '10000DFE2',
          '10000BFE3', '10000BFE2',
          '100007FE3', '100007FE2',
          '10000FFE5', '10000FFE4',
          '!10000EFE4' ],
        [ '10000EFE3', '10000EFE2', #node 0->123
          '10000DFE3', '10000DFE2', #node 1->023
          '10000BFE3', '10000BFE2',
          '100007FE3', '100007FE2',
          '10000FFE5', '10000FFE4', #node 0123->4567
          '10000EFE5', '10000EFE4',
          '10000DFE5', '10000DFE4',
          '10000BFE5', '10000BFE4',
          '100007FE5', '100007FE4',
          '10000FFE3', '10000FFE2',
       ],
      ],
      value => 'sum_odd/sum_even',
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

   TLB_COST => {
      name => '% of time spent doing TLB Miss',
      events => [
         ['47e', '10040ffE2', '10040ffE3', '76', '!10040ffE4', '!10040ffE5' ],
         ['47e', '10040ffE2', '10040ffE3', '76', '10040ffE4', '10040ffE5' ],
      ],
      value => 'tlb_cost',
   },

   PROPORTION_L2M_TLB => {
      name => 'Proportion of L2 misses due to TLB fill',
      events => ['ff7e', '47e'],
      value => 'sum_1/sum_0',
   },


   ## Software events
   PAGE_TBL_MINOR_FAULTS_INST => {
      name => "PAGE_TBL_MINOR_FAULTS_INST",
      events => ['RETIRED_INSTRUCTIONS', 'minor-faults'],
      value => 'sum_1/sum_0'
   },


   PAGE_TBL_MINOR_FAULTS_PER_INST => {
      name => "Minor page fault per instruction",
      events => ['RETIRED_INSTRUCTIONS', 'minor-faults'],
      value => 'sum_1/sum_0',
   },

   CPU_MIGR_PER_INST => {
      name => "CPU migrations per instruction",
      events => ['RETIRED_INSTRUCTIONS', 'cpu-migrations'],
      value => 'sum_1/sum_0',
   },

   CTX_SWITCH_PER_INST => {
      name => "CPU migrations per instruction",
      events => ['RETIRED_INSTRUCTIONS', 'context-switches'],
      value => 'sum_1/sum_0',
   },

);

sub get_processed_events {
    return %parse_options_amd;
}

1;
