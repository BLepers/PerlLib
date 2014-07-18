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
        events => [ 'L2_accesses', 'L2_misses' ],
        value => 'sum_1/sum_0',
        gnuplot_range => [ 0, 1 ],
    },

    L2_MISS_INST => {
        name => 'L2 Misses per Retired Instruction',
        events => [ 'instructions', 'L2_misses' ],
        value => 'sum_1/sum_0',
    },

    L2_ACCESS_INST => {
        name => 'L2 Accesses per Retired Instruction',
        events => [ 'instructions', 'L2_accesses' ],
        value => 'sum_1/sum_0',
    },

    L3_MISS_RATIO => {
        name => 'L3 Miss Ratio',
        events => [ 'L3_accesses', 'L3_misses' ],
        value => 'sum_1/sum_0',
        gnuplot_range => [ 0, 1 ],
    },

    L3_MISS_INST => {
        name => 'L3 Misses per Retired Instruction',
        events => [ 'instructions', 'L3_misses' ],
        value => 'sum_1/sum_0',
    },

    L3_ACCESS_INST => {
        name => 'L3 Accesses per Retired Instruction',
        events => [ 'instructions', 'L3_accesses' ],
        value => 'sum_1/sum_0',
    },

    ## Memory related events
    MEMORY_TOTAL_BW => {
        name => "Total memory bandwidth (read + write) (/64)",
        events => ['uncore_imc_0-0f04', 'uncore_imc_1-0f04', 'uncore_imc_2-0f04', 'uncore_imc_3-0f04'],
        value => 'sum_all',
    },
    MEMORY_READ_BW => {
        name => "Memory bandwidth (read) (/64)",
        events => ['uncore_imc_0-0304', 'uncore_imc_1-0304', 'uncore_imc_2-0304', 'uncore_imc_3-0304'],
        value => 'sum_all',
    },
    MEMORY_WRITE_BW => {
        name => "Memory bandwidth (write) (/64)",
        events => ['uncore_imc_0-0c04', 'uncore_imc_1-0c04', 'uncore_imc_2-0c04', 'uncore_imc_3-0c04'],
        value => 'sum_all',
    },

    LLC_MISS_LATENCY => {
        name => "Memory access latencies",
        events => ['uncore_cbox_0-0335', 'uncore_cbox_0-0336', 'uncore_cbox_1-0335', 'uncore_cbox_1-0336', 'uncore_cbox_2-0335', 'uncore_cbox_2-0336', 'uncore_cbox_3-0335', 'uncore_cbox_3-0336', 'uncore_cbox_4-0335', 'uncore_cbox_4-0336', 'uncore_cbox_5-0335', 'uncore_cbox_5-0336' ],
        value => 'sum_odd/sum_even',
    },

    CPU_DRAM_UNCORE => {
        name => 'CPU to DRAM and locality',
        events => [
            [ "uncore_cbox_0-4a35-01", "uncore_cbox_1-4a35-01", "uncore_cbox_2-4a35-01", "uncore_cbox_3-4a35-01", "uncore_cbox_4-4a35-01", "uncore_cbox_5-4a35-01", "uncore_cbox_0-4a35-02", "uncore_cbox_1-4a35-02", "uncore_cbox_2-4a35-02", "uncore_cbox_3-4a35-02", "uncore_cbox_4-4a35-02", "uncore_cbox_5-4a35-02" ],
        ],
        value => 'uncore_dram',
    },

    DRAM_LAR => {
        name => '% of local DRAM accesses',
        events => [ 'LLC_miss_local_dram', 'LLC_miss_remote_dram' ],
        value => 'sum_0/sum_all',
    },

    DRAM_LAR_WITH_L2_PF => {
        name => '% of local DRAM accesses (including L2 prefetcher)',
        events => [ 'LLC_miss_local_dram',  'L2_PF_local_dram', 'LLC_miss_remote_dram', 'L2_PF_remote_dram' ],
        value => '(sum_0+sum_1)/sum_all',
    },

    ## TLB related
    DTLB_MISS_INST => {
        name => "Number of TLB misses per retired instruction",
        events => ['instructions', 'TLB_misses'],
        value => 'sum_1/sum_0',
    },

    DTLB_MISS_LATENCY_PERCENT => {
        name => "Average TLB miss latency (% of total time)",
        events => ['cpu-cycles', 'TLB_latency'],
        value => 'sum_1/sum_0',
    },

    DTLB_MISS_LATENCY => {
        name => "Average TLB miss latency",
        events => ['TLB_misses', 'TLB_latency'],
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
