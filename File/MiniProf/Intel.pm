#!/usr/bin/perl
use strict;
use warnings;

package File::MiniProf::Intel;

my %parse_options_intel = (
   ## Processed measurements
   IPC => {
      name => 'IPC',
      events => [ 'CPU_CLK_UNHALTED', 'RETIRED_INSTRUCTIONS' ], # cpu clock unhalted, retired instructions
      value => 'sum_1/sum_0', #Numbers are relative to previous events. 1 is RETIRED.
   },

   ## Software events
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
    return %parse_options_intel;
}

1;
