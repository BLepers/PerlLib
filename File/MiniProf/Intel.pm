#!/usr/bin/perl
use strict;
use warnings;

package File::MiniProf::Intel;

my %parse_options_intel = (
   ## Processed measurements
   IPC => {
      name => 'IPC',
      events => [ 'cpu-cycles', 'instructions' ], # cpu clock unhalted, retired instructions
      value => 'sum_1/sum_0', #Numbers are relative to previous events. 1 is RETIRED.
   },

   ## Cache related
   L2_MISS_RATIO => {
      name => 'L2 Miss Ratio',
      events => [ 'L2_ACCESSES_ALL', 'L2_MISSES_ALL' ], # L2 accesses, L2 misses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   L2_MISS_INST => {
      name => 'L2 Misses per Retired Instruction',
      events => [ 'instructions', 'L2_MISSES_ALL' ], # retired instructions, L2 misses
      value => 'sum_1/sum_0',
   },

   L2_ACCESS_INST => {
      name => 'L2 Accesses per Retired Instruction',
      events => [ 'instructions', 'L2_ACCESSES_ALL' ], # retired instructions, L2 accesses
      value => 'sum_1/sum_0',
   },

   L3_MISS_RATIO => {
      name => 'L3 Miss Ratio',
      events => [ 'L3_ACCESSES_ALL', 'L3_MISSES_ALL' ], # L3 accesses, L3 misses
      value => 'sum_1/sum_0',
      gnuplot_range => [ 0, 1 ],
   },

   L3_MISS_INST => {
      name => 'L3 Misses per Retired Instruction',
      events => [ 'instructions', 'L3_MISSES_ALL' ], # retired instructions, L3 misses
      value => 'sum_1/sum_0',
   },

   L3_ACCESS_INST => {
      name => 'L3 Accesses per Retired Instruction',
      events => [ 'instructions', 'L3_ACCESSES_ALL' ], # retired instructions, L3 accesses
      value => 'sum_1/sum_0',
   },

   ## Software events
   PAGE_TBL_MINOR_FAULTS_PER_INST => {
      name => "Minor page fault per instruction",
      events => ['instructions', 'minor-faults'],
      value => 'sum_1/sum_0',
   },

   CPU_MIGR_PER_INST => {
      name => "CPU migrations per instruction",
      events => ['instructions', 'cpu-migrations'],
      value => 'sum_1/sum_0',
   },

   CTX_SWITCH_PER_INST => {
      name => "CPU migrations per instruction",
      events => ['instructions', 'context-switches'],
      value => 'sum_1/sum_0',
   },
);

sub get_processed_events {
    return %parse_options_intel;
}

1;
