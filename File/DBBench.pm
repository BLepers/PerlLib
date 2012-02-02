#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;

use Statistics::Basic qw(:all);

package File::DBBench;

my $DBBENCH_FILE_NAME = qr/DBBench_.*_(\d+)cores_(\d+)tables(?:_(\d+)rows)?(?:_(\d+)columns)?_(\d+)clients(?:_(select|update)_)?/i;

sub dbbench_get_info {
	my $self = $_[0];
	( my $nbcores, my $nbtables, my $nbrows, my $nbcolumns, my $nbclients, my $req_type) = ( $self->{filename} =~ m/$DBBENCH_FILE_NAME/ );

	( my $iteration ) = ( $self->{filename} =~ m/_iteration(\d+)/ );

	$self->{dbbench_metadata}->{nbcores}   = $nbcores;
	$self->{dbbench_metadata}->{nbclients} = $nbclients;
	$self->{dbbench_metadata}->{nbtables}  = $nbtables;
	$self->{dbbench_metadata}->{nbrows}    = $nbrows;
	$self->{dbbench_metadata}->{nbcolumns} = $nbcolumns;
	$self->{dbbench_metadata}->{req_type} = $req_type;

	$self->{dbbench_metadata}->{iteration_no} = $iteration;

	if ( $self->{filename} =~ m/_jvmop\d+|_dbop\d+/i ) {
		my @lines = $self->get_lines;
		for my $line (@lines) {
			if ( $line =~ m/JVM opts :(.*)/ ) {
				$self->{dbbench_metadata}->{vm_opts} = $1;
			}
			if ( $line =~ m/DB opts :(.*)/ ) {
				$self->{dbbench_metadata}->{db_opts} = $1;
			}
			
			if(defined $self->{dbbench_metadata}->{db_opts} && defined $self->{dbbench_metadata}->{vm_opts}){
			   last;
			}
		}
	}
	
	if ( $self->{filename} =~ m// ) {
		my @lines = $self->get_lines;
		for my $line (@lines) {

		}
	}

	return $self->{dbbench_metadata};
}

sub dbbench_get_results {
	my $self = $_[0];
	if ( $self->{filename} =~ m/_jvmop\d+$|_dbop\d+$|clients$|/i ) {
		my @lines = $self->get_lines;
		for my $line (@lines) {
			if ( $line =~ m/Number of (.*)\/s :\s+(.*)\s+\(stddev (\d+\.\d+)\s+%\)/ ) {
				$self->{dbbench_results}->{$1}->{value}  = $2;
				$self->{dbbench_results}->{$1}->{stddev} = $3;
			}
		}
	}

	return $self->{dbbench_results};
}

sub dbbench_get_sar {
	my $self                     = $_[0];
	my $truncate_x_first_seconds = $_[1];

	if ( !defined $truncate_x_first_seconds ) {
		$truncate_x_first_seconds = 35;
	}

	if ( $self->{filename} =~ m/.cpu$/ || $self->{filename} =~ m/.dev$/ ) {
		return;
	}

	( my $server ) = ( $self->{filename} =~ m/DBBench_\d+_\d+_(.*)_\d+cores/ );

	my @to_parse = ( 'cpu', 'dev' );

	for my $tp (@to_parse) {
		## Get usage
		my $ino = 0;
		my @sar_results;
		for ( ; ; ) {
			my $sar_file = $self->{complete_filename} . "_iteration$ino.$server.$tp";
			my $run_file = $self->{base_dir}->get_file($sar_file);
			last if !defined $run_file;

			$run_file->{sar_min_time_to_consider} = $truncate_x_first_seconds;
			$run_file->{sar_max_time_to_consider} = -$truncate_x_first_seconds;
			$sar_results[$ino] = $run_file->sar_parse()->{usage};

			$ino++;
		}

		if ( scalar @sar_results ) {
			$self->{dbbench_sar}->{$tp}->{value}  = Statistics::Basic::mean(@sar_results);
			$self->{dbbench_sar}->{$tp}->{stddev} = Statistics::Basic::stddev(@sar_results);
		}

	}

	return $self->{dbbench_sar};
}

sub dbbench_sort_cores {
	if ( !( $File::Utils::a =~ m/$DBBENCH_FILE_NAME/ ) ) { return 1; }
	if ( !( $File::Utils::b =~ m/$DBBENCH_FILE_NAME/ ) ) { return -1; }

	( my $nbcores1, my $nbtables1, my $nbrows1, my $nbcolumns1, my $nbcl1 ) = ( $File::Utils::a =~ m/$DBBENCH_FILE_NAME/ );
	( my $nbcores2, my $nbtables2, my $nbrows2, my $nbcolumns2, my $nbcl2 ) = ( $File::Utils::b =~ m/$DBBENCH_FILE_NAME/ );

	if ( $nbcores1 != $nbcores2 ) { return $nbcores1 - $nbcores2; }
	if ( $nbcl1 != $nbcl2 )       { return $nbcl1 - $nbcl2; }

	if ( $nbtables1 != $nbtables2 )   { return $nbtables1 - $nbtables2; }
	if ( $nbrows1 != $nbrows2 )       { return $nbrows1 - $nbrows2; }
	if ( $nbcolumns1 != $nbcolumns2 ) { return $nbcolumns1 - $nbcolumns2; }

	return $File::Utils::a->{filename} cmp $File::Utils::b->{filename};
}

1;
