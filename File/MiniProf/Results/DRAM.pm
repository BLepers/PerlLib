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

package File::MiniProf::Results::DRAM;
use File::MiniProf;

#[ 'CPU_DRAM_Node0', 'CPU_DRAM_Node1', 'CPU_DRAM_Node2', 'CPU_DRAM_Node3' ],
sub local_dram_usage {
    my ( $self, $info, $parse_options, $opt ) = @_;

    my $global_sum_local;
    my $global_sum_all;
    my @accesses_to_node;

    my $nb_nodes = File::MiniProf::_nb_nodes($self);

    if(scalar(keys %{$info->{usable_events}}) != $nb_nodes) {
        if(!defined $opt->{suppress_warnings} || !$opt->{suppress_warnings}) {
            print "[WARN] Cannot calculate LAR: function called with ".scalar(keys %{$info->{usable_events}})." events but system has $nb_nodes nodes\n";
        }
        return;
    }

    my @events = map { $self->_scripted_value_to_event( $_, $info ) } ( 0 .. ($nb_nodes-1) );
    for my $core ( sort { $a <=> $b } keys %{ $self->{miniprof}->{raw} } ) {
        my $sum_all = 0;
        for my $dram ( 0 .. ($nb_nodes-1) ) {
            my ( $avg, $sum, $count ) = File::MiniProf::_miniprof_get_average_and_sum( $self->{miniprof}->{raw}->{$core}, $events[$dram] );

            $sum_all += $sum;
        }

        my $local_dram = File::MiniProf::_local_dram_fun($self, $core, $opt->{local_dram_fun});

        my ( $avg, $sum, $count ) = File::MiniProf::_miniprof_get_average_and_sum( $self->{miniprof}->{raw}->{$core}, $events[$local_dram] );

        if($sum_all > 0) {
            $info->{results}->{$core}->{'local access ratio'} = $sum/$sum_all;
            $info->{results}->{'NODE'.$self->_local_dram_fun($core)}->{'local access ratio'} = $sum/$sum_all;
        }


        for my $dram (0..($nb_nodes-1)) {
            my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[$dram] );
            next if ($sum_all == 0);
            if($sum_all == 0){
                $info->{results}->{$core}->{'percent_access_to_'.$dram} = 0;
            }
            else{
                $info->{results}->{$core}->{'percent_access_to_'.$dram} = $sum/$sum_all;
            }
            $accesses_to_node[$dram] += $sum;
        }

        $global_sum_all += $sum_all;
        $global_sum_local += $sum;
    }

    if($global_sum_all > 0) {
        $info->{results}->{GLOBAL}->{'local access ratio'} = $global_sum_local/$global_sum_all;
    } else {
        $info->{results}->{GLOBAL}->{'local access ratio'} = 'No sample';
    }

    my ($max_access, $most_loaded_node) = (0,0);
    for my $dram (0..($nb_nodes-1)) {
        $info->{results}->{GLOBAL}->{'access to '.$dram} = $accesses_to_node[$dram];
        if($accesses_to_node[$dram] && $accesses_to_node[$dram] > $max_access) {
            $max_access = $accesses_to_node[$dram];
            $most_loaded_node = $dram;
        }
    }
    $info->{results}->{GLOBAL}->{'number of memory accesses'} = $global_sum_all;
    $info->{results}->{GLOBAL}->{'most loaded node'} = $most_loaded_node;
    if($global_sum_all) {
        $info->{results}->{GLOBAL}->{'% of accesses to most loaded node'} = $max_access / $global_sum_all;
    } else {
        $info->{results}->{GLOBAL}->{'% of accesses to most loaded node'} = 'No sample';
    }


    if ( $opt->{gnuplot} ) {
        my $plot = File::MiniProf::Results::Plot::get_plot( $info, $parse_options, $opt, $parse_options->{ $info->{name} }->{name} );
        my @plota;

        my $random_core = ( keys %{ $self->{miniprof}->{raw} } )[0];
        for my $k ( 0 .. ($nb_nodes-1) ) {
            my @vals = ();
            for ( my $i = 0 ; $i < scalar( @{ $self->{miniprof}->{raw}->{$random_core}->{ $events[0] }->{val} } ) ; $i++ ) {
                my $val_local = 0;
                my $val_dist = 0;
                for my $core ( keys %{ $self->{miniprof}->{raw} } ) {
                    my $local_dram = File::MiniProf::_local_dram_fun($self, $core, $opt->{local_dram_fun});
                    if($k == $local_dram) {
                        $val_local += $self->{miniprof}->{raw}->{$core}->{ $events[$k] }->{val}->[$i];
                    } else {
                        $val_dist += $self->{miniprof}->{raw}->{$core}->{ $events[$k] }->{val}->[$i];
                    }
                }
                my $avg = ( $val_local + $val_dist ) ? ( $val_local / ($val_local + $val_dist) ) : 0;
                push( @vals, $avg );
            }
            push( @plota, \@vals );
        }

        $plot->gnuplot_set_plot_titles( map( "Locality of node $_", ( 0 .. ($nb_nodes-1) ) ) );
        $plot->gnuplot_plot_xy( $self->{miniprof}->{raw}->{0}->{ $events[0] }->{time}, @plota );
    }

    if ( $opt->{gnuplot} ) {
        my $plot = File::MiniProf::Results::Plot::get_plot( $info, $parse_options, $opt, 'DRAM Accesses to Nodes');
        my @plota;

        my $random_core = ( keys %{ $self->{miniprof}->{raw} } )[0];
        for my $k ( 0 .. ($nb_nodes-1) ) {
            my @vals = ();
            for ( my $i = 0 ; $i < scalar( @{ $self->{miniprof}->{raw}->{$random_core}->{ $events[0] }->{val} } ) ; $i++ ) {
                my $val = 0;
                for my $core ( keys %{ $self->{miniprof}->{raw} } ) {
                    $val += $self->{miniprof}->{raw}->{$core}->{ $events[$k] }->{val}->[$i];
                }
                push( @vals, $val );
            }
            push( @plota, \@vals );
        }

        $plot->gnuplot_set_plot_titles( map( "To node $_", ( 0 .. ($nb_nodes-1) ) ) );
        $plot->gnuplot_plot_xy( $self->{miniprof}->{raw}->{0}->{ $events[0] }->{time}, @plota );
    }

    if($opt->{gnuplot} && $parse_options->{$info->{name}}->{gnuplot_per_core}) {
        my $random_core = ( keys %{ $self->{miniprof}->{raw} } )[0];
        for my $k ( 0 .. ($nb_nodes-1) ) {
            my $plot = File::MiniProf::Results::Plot::get_plot( $info, $parse_options, $opt, 'DRAM Accesses to Node'.$k);
            my @plota;
            my @vals = ();
            for ( my $i = 0 ; $i < scalar( @{ $self->{miniprof}->{raw}->{$random_core}->{ $events[0] }->{val} } ) ; $i++ ) {
                my $val = 0;
                for my $core ( keys %{ $self->{miniprof}->{raw} } ) {
                    $val += $self->{miniprof}->{raw}->{$core}->{ $events[$k] }->{val}->[$i];
                }
                push( @vals, $val );
            }
            push( @plota, \@vals );
            $plot->gnuplot_set_plot_titles( map( "To node $_", ( 0 .. ($nb_nodes-1) ) ) );
            $plot->gnuplot_plot_xy( $self->{miniprof}->{raw}->{0}->{ $events[0] }->{time}, @plota );
        }
    }
}

#"uncore_cbox_0-0435-01", "uncore_cbox_1-0435-01", "uncore_cbox_2-0435-01", "uncore_cbox_3-0435-01", "uncore_cbox_4-0435-01", "uncore_cbox_5-0435-01", "uncore_cbox_0-0435-02", "uncore_cbox    _1-0435-02", "uncore_cbox_2-0435-02", "uncore_cbox_3-0435-02", "uncore_cbox_4-0435-02", "uncore_cbox_5-0435-02"

sub mask_to_id {
    my $hex_value = $_[0];
    my $i;
    for($i = 0; ; $i++) {
        last if(hex(1 << $i) == $hex_value);
    }

    return $i;
}

sub uncore_dram {
    my ( $self, $info, $parse_options, $opt ) = @_;

    my $global_sum_local;
    my $global_sum_all;
    my @accesses_to_node;
    my @accesses_by_node;
    my @lar_of_node;

    my $nb_nodes = File::MiniProf::_nb_nodes($self);

    # print main::Dumper($info->{usable_events});
    # print main::Dumper($self->{miniprof}->{raw});
    # print main::Dumper(keys $self->{miniprof}->{raw});

    for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
        for my $ev_name (keys $info->{usable_events}) {
            my $ev_no = $info->{usable_events}->{$ev_name};
            my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $ev_no);

            my ($nid_str) = ($ev_name =~ m/uncore_cbox_\d+-[0-9a-f]+-([0-9a-f]+)/);
            die if !defined $nid_str;

            my $nid = mask_to_id(hex($nid_str));
            my $local_dram = File::MiniProf::_local_dram_fun($self, $core, $opt->{local_dram_fun});
            die if $nid >= $nb_nodes || $nid < 0;

            print "[$core, $local_dram] $nid : $sum\n";
            $accesses_to_node[$nid] += $sum;
            $accesses_by_node[$local_dram] += $sum;

            $global_sum_all += $sum;

            if($local_dram == $nid) {
                $global_sum_local += $sum;
                $lar_of_node[$nid] += $sum;
            }
        }
    }

    print "$self : ".($global_sum_local * 100/$global_sum_all)." %\n";
    print main::Dumper(\@accesses_to_node);
    print main::Dumper(\@accesses_by_node);
    print main::Dumper(\@lar_of_node);
}

1;
