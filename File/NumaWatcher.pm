#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use Graphics::GnuplotIF qw(GnuplotIF);

package File::NumaWatcher;

=head
Usage:
   $file->nw_parse;

Returns:
=cut

sub _get_average_from_relevant_data {
   my ($hash_ref, $max_time_to_consider, $min_time_to_consider) = @_;
   my $sum = 0;
   my $count = 0;
   my $max = 0;
   my $min = -1;
   for my $key (keys %$hash_ref) {
      next if($key > $max_time_to_consider || $key < $min_time_to_consider);
      $sum += $hash_ref->{$key};
      $count++;
      $max = $hash_ref->{$key} if($hash_ref->{$key} > $max);
      $min = $hash_ref->{$key} if($hash_ref->{$key} < $min || $min == -1);
   }
   if($count != 0) {
      return ($sum / $count, $sum, $count, $min, $max);
   } else {
      return (0, $sum, $count, $min, $max);
   }
}

sub _gnuplot_mem {
   my $self = $_[0];
   my $opt = $_[1];
   my @gnuplot_xy = @{$_[2]};
   my $ext = $_[3];
   my @gnuplot_titles = @{$_[4]};
   
   my $plot = Graphics::GnuplotIF->new(persist=>1);
   $plot->gnuplot_set_xlabel("Time (s)");
   $plot->gnuplot_set_ylabel( "Memory $ext (MB)" );
      
   $plot->gnuplot_set_style( "points" );   
      
   if($opt->{gnuplot_file}){
      $plot->gnuplot_hardcopy( $self->{filename}.".$ext.png", 'png' );   
   }
      
   $plot->gnuplot_set_plot_titles(@gnuplot_titles);
   $plot->gnuplot_plot_many( @gnuplot_xy );
}

sub nw_parse {
   my ($self, $opt) = @_;

   my %times = ();
   my %nodes  = ();
   
   my $min_time_to_consider = 0;
   my $max_time_to_consider = 0;
   
   while (my $line = <$self>) {
      next if ($line =~ /Found/);
            
      my ($time, $node, $mem_total, $mem_free, $mem_used) = ($line =~ m/(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);

      die "I did not recognize the line: $line" if !defined $time;
            
      $times{$time}->{$node}->{mem_total} = $mem_total / 1024;
      $times{$time}->{$node}->{mem_free} = $mem_free / 1024;
      $times{$time}->{$node}->{mem_used} = $mem_used / 1024;
      
      $nodes{$node}->{mem_total}->{$time} = $mem_total / 1024;
      $nodes{$node}->{mem_free}->{$time} = $mem_free / 1024;
      $nodes{$node}->{mem_used}->{$time} = $mem_used / 1024;
      
      $max_time_to_consider = $time;
   }
   
   $self->{raw}->{times} = \%times;
   $self->{raw}->{nodes} = \%nodes;

   for my $node (keys %nodes) {
      my ($average, $sum, $count, $min, $max) = _get_average_from_relevant_data($nodes{$node}->{mem_total}, $max_time_to_consider, $min_time_to_consider);
      $self->{nw}->{$node}->{avg_total_mem} = $average;
      $self->{nw}->{$node}->{min_total_mem} = $min;
      $self->{nw}->{$node}->{max_total_mem} = $max;
      
      ($average, $sum, $count, $min, $max) = _get_average_from_relevant_data($nodes{$node}->{mem_free}, $max_time_to_consider, $min_time_to_consider);
      $self->{nw}->{$node}->{avg_free_mem} = $average;
      $self->{nw}->{$node}->{min_free_mem} = $min;
      $self->{nw}->{$node}->{max_free_mem} = $max;
      
      ($average, $sum, $count, $min, $max) = _get_average_from_relevant_data($nodes{$node}->{mem_used}, $max_time_to_consider, $min_time_to_consider);
      $self->{nw}->{$node}->{avg_used_mem} = $average;
      $self->{nw}->{$node}->{min_used_mem} = $min;
      $self->{nw}->{$node}->{max_used_mem} = $max;
   }
   
   if((defined $opt) && $opt->{gnuplot}) {
      my @_times = sort keys %times;
      
      my @gnuplot_xy;
      my @gnuplot_xy2;
      
      my @gnuplot_titles = ();
      for my $node (sort keys %{nodes}) {
         my @_values = map { $self->{raw}->{nodes}->{$node}->{mem_free}->{$_} } @_times;
         my @_values2 = map { $self->{raw}->{nodes}->{$node}->{mem_used}->{$_} } @_times;
         
         push(@gnuplot_xy, \@_times); #x
         push(@gnuplot_xy, \@_values); #y
         
         push(@gnuplot_xy2, \@_times); #x
         push(@gnuplot_xy2, \@_values2); #y
         
         push(@gnuplot_titles, "Node $node");
      }
      
      _gnuplot_mem($self, $opt, \@gnuplot_xy, "free", \@gnuplot_titles);
      _gnuplot_mem($self, $opt, \@gnuplot_xy2, "used", \@gnuplot_titles);            
   }
   
   return $self->{nw};
}

1;
