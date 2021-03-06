#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use Graphics::GnuplotIF qw(GnuplotIF);

package File::Sar;
=head
Usage:
   $file->sar_parse;

Returns:
   Depends on what is found in the file. Common fields are:
   {
      average   => average of the _values_ found in the file (e.g. MB/s for dev, idleness for CPU).
      usage     => %of utilization of the ressource (e.g. 100 = NIC is overloaded, CPU is fully LOADED, ...).
      min
      max       => Same metric as average but min and max values.
      min_usage
      max_usage => Same metric as usage but min and max.
   }

   More data is available in ->{dev} or ->{cpu} or ... depending on the analysed file.
   Pre-parsed values are available in ->{raw}.
=cut

my %device_capabilites = (
    #"net" => 940, ## 1Gb/s
    "net" => 9900, ## 10Gb/s
    "disk" => 170000, ## iops
);

sub _sar_to_time {
   my ($line, $first_time, $last_time) = @_;
   (my $hour, my $min, my $sec, my $am) = ($line =~ m/^(\d+):(\d+):(\d+) (AM|PM)/);
   if ( !defined($am) ) {
      $am = "AM";
      ($hour, $min, $sec) = ($line =~ m/^(\d+):(\d+):(\d+)/);
      print $line if (!defined($hour));
   }
   my $time = $hour*60*60 + $min*60 + $sec;
   $time += 12*60*60 if($am eq "PM");

   $first_time = $time if($first_time == 0);
   $last_time = $time - $first_time;
   if($last_time < 0) {
      #For some reason the date is sometimes displayed with an "AM" instead of a PM. (ie 12:00AM ... 01:00AM). We correct that.
      $first_time -= 12*60*60;
      $last_time = $time - $first_time;
      if ($last_time < 0) {   #we also sometimes need to correct 24H difference (going from 23h59 to 00:01)
         $first_time -= 12*60*60;
         $last_time = $time - $first_time;
      }
   } elsif ($last_time > 40000) {
      $first_time += 12*60*60;
      $last_time = $time - $first_time;
   }
   return ($first_time, $last_time);
}

sub _sar_get_average_from_relevant_data {
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

sub _sar_get_global_average {
   my ($hash_ref, $field) = @_;
   $field //= 'average';
   my $sum = 0;
   my $count = 0;
   my $max = 0;
   my $min = -1;
   for my $key (keys %$hash_ref) {
      $sum += $hash_ref->{$key}->{$field};
      $count++;
      $max = $hash_ref->{$key}->{$field} if($hash_ref->{$key}->{$field} > $max);
      $min = $hash_ref->{$key}->{$field} if($hash_ref->{$key}->{$field} < $min || $min == -1);
   }

   if($count != 0) {
      return ($sum / $count, $min, $max);
   } else {
      return (0, $min, $max);
   }
}

sub _sar_sanity_check {
   my ($self) = @_;
   if(!defined $self->{sar_min_time_to_consider}) {
      $self->{sar_min_time_to_consider} = 0;
   }
   if(!defined $self->{sar_max_time_to_consider}) {
      $self->{sar_max_time_to_consider} = 100000;
   }
}

sub plot_to_file{
    my ($opt, $plot, $fn) = @_;
    return if (!defined $opt->{gnuplot_file});

    if($opt->{gnuplot_file} eq "png"){
        $plot->gnuplot_hardcopy( $fn.".png", 'png', 'size 1280,960' );
    }
    else {
        $plot->gnuplot_hardcopy( $fn.".".$opt->{gnuplot_file}, $opt->{gnuplot_file} );
    }
}

sub sar_parse_dev {
   my ($self, $opt) = @_;
   $self->_sar_sanity_check;
   my $max_per_nics = eval { $opt->{max_per_nics} } // $device_capabilites{net};

   my $first_time = 0;
   my $last_time = 0;
   my %times = ();
   my %eths = ();
   my %global = ();
   while (my $line = <$self>) {
      #11:59:01 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s
      #11:59:03 AM     eth12      0.00      0.00      0.00      0.00      0.00      0.00      0.00
      last if($line =~ m/^Average/);
      if($line =~ m/IFACE/) {
         ($first_time, $last_time) = _sar_to_time($line, $first_time, $last_time);
      } elsif($line =~ m/(eth|em)\d+/) {
         next if $line =~ m/rename/;
         (my $eth, my $rxB, my $txB) = ($line =~ m/([eth|em].*?)\s+\d+\.\d+\s+\d+\.\d+\s+(\d+\.\d+)\s+(\d+\.\d+)/);

         $times{$last_time}->{$eth}->{tx} = $txB;
         $times{$last_time}->{$eth}->{rx} = $rxB;
         $times{$last_time}->{GLOBAL}->{tx} += $txB;
         $times{$last_time}->{GLOBAL}->{rx} += $rxB;

         $eths{$eth}->{tx}->{$last_time} = $txB;
         $eths{$eth}->{rx}->{$last_time} = $rxB;
         $global{tx}->{$last_time} += $txB;
         $global{rx}->{$last_time} += $rxB;
      }
   }

   $self->{sar_dev}->{length} = $last_time;
   $self->{sar_dev}->{nb_eths} = scalar keys %eths;
   $self->{sar_dev}->{raw}->{times} = \%times;
   $self->{sar_dev}->{raw}->{eth} = \%eths;
   $self->{sar_max_time_to_consider} = $last_time + $self->{sar_max_time_to_consider} if($self->{sar_max_time_to_consider} < 0);


   for my $eth (keys %{$self->{sar_dev}->{raw}->{eth}}) {
      for my $x (keys %{$self->{sar_dev}->{raw}->{eth}->{$eth}}) {
         my ($average, $sum, $count) = _sar_get_average_from_relevant_data($eths{$eth}->{$x}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});
         $self->{sar_dev}->{eth}->{$eth}->{$x}->{average} = $average * 8 / 1024;
         $self->{sar_dev}->{eth}->{$eth}->{$x}->{usage} = $self->{sar_dev}->{eth}->{$eth}->{$x}->{average} * 100 / $max_per_nics;
         #$self->{sar_dev}->{eth}->{$eth}->{$x}->{sum} = int($sum * 8 / 1024);
         #$self->{sar_dev}->{eth}->{$eth}->{$x}->{count} = $count;

         if((defined $opt) && $opt->{gnuplot} && $self->{sar_dev}->{eth}->{$eth}->{$x}->{average} > 0) {
            my @_times = sort keys %{$self->{sar_dev}->{raw}->{eth}->{$eth}->{$x}};
            my @_values = map { $self->{sar_dev}->{raw}->{eth}->{$eth}->{$x}->{$_} } @_times;

            my @gnuplot_xy;
            push(@gnuplot_xy, \@_times); #x
            push(@gnuplot_xy, \@_values); #y

            my $plot = Graphics::GnuplotIF->new(persist=>1);
            $plot->gnuplot_set_title( "$eth -- $x" );

            if($opt->{gnuplot_file}){
                plot_to_file($opt, $plot, $self->{filename}.".$eth.$x");
            }

            $plot->gnuplot_set_style( "points" );
            $plot->gnuplot_plot_many( @gnuplot_xy );
         }
      }
   }

   for my $x (keys %global) {
      my ($average, $sum, $count) = _sar_get_average_from_relevant_data($global{$x}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});

      my $x_avg = $average * 8 / 1024;
      my $x_usage = $average * 100 / $max_per_nics;

      if((defined $opt) && $opt->{gnuplot} && $average > 0) {
         my @_times = sort keys %{$global{$x}};
         my @_values = map { $global{$x}->{$_} } @_times;

         my @gnuplot_xy;
         push(@gnuplot_xy, \@_times); #x
         push(@gnuplot_xy, \@_values); #y

         my $plot = Graphics::GnuplotIF->new(persist=>1);
         $plot->gnuplot_set_title( "GLOBAL -- $x" );

         if($opt->{gnuplot_file}){
            plot_to_file($opt, $plot, $self->{filename}.".global.$x");
         }

         $plot->gnuplot_set_style( "points" );
         $plot->gnuplot_plot_many( @gnuplot_xy );
      }
   }

   ## TODO- Not compatible with the new layout
   #my ($average, $min, $max) = _sar_get_global_average($self->{sar_dev}->{eth});
   #$self->{sar_dev}->{average} = int($average);
   #$self->{sar_dev}->{usage} = int(100*$average/$max_per_nics*100)/100;
   #$self->{sar_dev}->{min} = int($min);
   #$self->{sar_dev}->{min_usage} = int(100*$min/$max_per_nics*100)/100;
   #$self->{sar_dev}->{max} = int($max);
   #$self->{sar_dev}->{max_usage} = int(100*$max/$max_per_nics*100)/100;

   return $self->{sar_dev};
}

sub sar_parse_disk {
   my ($self, $opt) = @_;
   my $max_iops_per_disk = eval { $opt->{max_iops_per_disk} } // $device_capabilites{disk};
   $self->_sar_sanity_check;

   my $first_time = 0;
   my $last_time = 0;
   my %times = ();
   my %disk  = ();
   while (my $line = <$self>) {
      next if ($line =~ /Linux/);
      #02:02:29          DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util
      #02:02:30       dev8-0     27.00   1792.00      0.00     66.37      0.10      4.44      2.96      8.00
      #02:02:30      dev8-16    221.00  28696.00      0.00    129.85      0.59      2.67      2.04     45.00

      if($line =~ m/tps/) {
         ($first_time, $last_time) = _sar_to_time($line, $first_time, $last_time);
      } elsif($line =~ m/\d\d:\d\d:\d\d/ && $line !~ m/tps/) {
         #(my $dev, my $tps, my $rd_sec, my $wr_sec) = ($line =~ m/(dev\d+-\d+|sd.|scd.|md.)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)/);
         (my $dev, my $tps, my $rd_sec, my $wr_sec) = ($line =~ m/(dev\d+-\d+|sd.|scd.|md\d+)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)/);

        next if !($dev =~ m/md\d+/);

         if (!defined($wr_sec)) {
            $line =~ s/\n$//;
            print "[$self] Undefined line : ".$line."\n";
            next;
         }

         ($first_time, $last_time) = _sar_to_time($line, $first_time, $last_time);


         $times{$last_time}->{$dev}->{rd_sec} = $rd_sec;
         $times{$last_time}->{$dev}->{wr_sec} = $wr_sec;
         $times{$last_time}->{$dev}->{tps} = $tps;

         $disk{$dev}->{rd_sec}->{$last_time} = $rd_sec;
         $disk{$dev}->{wr_sec}->{$last_time} = $wr_sec;
         $disk{$dev}->{tps}->{$last_time} = $tps;
      }
   }

   $self->{sar_disk}->{length} = $last_time;
   $self->{sar_disk}->{raw}->{times} = \%times;
   $self->{sar_disk}->{raw}->{disk} = \%disk;
   $self->{sar_max_time_to_consider} = $last_time + $self->{sar_max_time_to_consider} if($self->{sar_max_time_to_consider} < 0);

   for my $d (keys %{$self->{sar_disk}->{raw}->{disk}}) {
      my ($rd_sec_average, $rd_sec_sum, $rd_sec_count, $rd_sec_min, $rd_sec_max) =
        _sar_get_average_from_relevant_data($disk{$d}->{rd_sec}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});
      my ($wr_sec_average, $wr_sec_sum, $wr_sec_count, $wr_sec_min, $wr_sec_max) =
        _sar_get_average_from_relevant_data($disk{$d}->{wr_sec}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});

      my ($tps_average, $tps_sum, $tps_count, $tps_min, $tps_max) = _sar_get_average_from_relevant_data($disk{$d}->{tps}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});

      $self->{sar_disk}->{$d}->{rd_sec_average} = $rd_sec_average;
      $self->{sar_disk}->{$d}->{rd_sec_min} = $rd_sec_min;
      $self->{sar_disk}->{$d}->{rd_sec_max} = $rd_sec_max;
      $self->{sar_disk}->{$d}->{wr_sec_average} = $wr_sec_average;
      $self->{sar_disk}->{$d}->{wr_sec_min} = $wr_sec_min;
      $self->{sar_disk}->{$d}->{wr_sec_max} = $wr_sec_max;

      $self->{sar_disk}->{$d}->{tps_average} = $tps_average;
      $self->{sar_disk}->{$d}->{tps_min} = $tps_min;
      $self->{sar_disk}->{$d}->{tps_max} = $tps_max;
      $self->{sar_disk}->{$d}->{usage} = $tps_average * 100. / $max_iops_per_disk;

      if((defined $opt) && $opt->{gnuplot}) {
         for my $op (keys %{$self->{sar_disk}->{raw}->{disk}->{$d}}){
            my @_times = sort keys %{$self->{sar_disk}->{raw}->{disk}->{$d}->{$op}};
            my @_values;
            if($op eq "tps") {
                @_values = map { $self->{sar_disk}->{raw}->{disk}->{$d}->{$op}->{$_} } @_times;
            }
            else {
                @_values = map { $self->{sar_disk}->{raw}->{disk}->{$d}->{$op}->{$_} * 512 / (1024*1024) } @_times;
            }

            my @gnuplot_xy;
            push(@gnuplot_xy, \@_times); #x
            push(@gnuplot_xy, \@_values); #y

            my $plot = Graphics::GnuplotIF->new(persist=>1);
            $plot->gnuplot_set_title( "Disk $d" );
            $plot->gnuplot_set_xlabel("Time (s)");

            if($op eq "tps") {
                $plot->gnuplot_set_ylabel("$op");
            }
            else {
                $plot->gnuplot_set_ylabel("$op (MB/s)");
            }

            if($opt->{gnuplot_file}){
                plot_to_file($opt, $plot, $self->{filename}.".$d.$op");
            }

            $plot->gnuplot_set_style( "points" );
            $plot->gnuplot_plot_many( @gnuplot_xy );
         }
      }
   }
   return $self->{sar_disk};
}

sub _gnuplot_mem {
   my $self = $_[0];
   my $opt = $_[1];
   my @gnuplot_xy = @{$_[2]};
   my $ext = $_[3];

   my $plot = Graphics::GnuplotIF->new(persist=>1);
   $plot->gnuplot_set_xlabel("Time (s)");
   $plot->gnuplot_set_ylabel( "Memory used (MB)" );

   $plot->gnuplot_set_style( "points" );

   if($opt->{gnuplot_file}){
        plot_to_file($opt, $plot, $self->{filename}.".$ext");
   }

   $plot->gnuplot_set_plot_titles($ext);
   $plot->gnuplot_plot_many( @gnuplot_xy );
}

sub sar_parse_mem {
   my ($self, $opt) = @_;
   $self->_sar_sanity_check;

   my $first_time = 0;
   my $last_time = 0;
   my %times = ();
   my %memusage = ();
   while (my $line = <$self>) {
      next if ($line =~ /Linux/);
      #12:10:14    kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit
      #12:10:15      3735536   4462072     54.43     46424   3393628   9269432     76.55
      if($line =~ m/kbmemfree/) {
         ($first_time, $last_time) = _sar_to_time($line, $first_time, $last_time);
      } elsif($line =~ m/\d\d:\d\d:\d\d/ && $line !~ m/kbmemfree/) {
         (my $memfree, my $memused, my $percent_memused, my $buffers, my $cached, my $commit, my $percent_commit) = ($line =~ m/^\d+:\d+:\d+\s+(?:[AP]M\s+)?(\d+)\s+(\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+(?:\.\d+)?)\s*/);

         if (!defined($percent_memused)) {
            $line =~ s/\n$//;
            print "[$self] Undefined line : ".$line."\n";
            next;
         }

         ($first_time, $last_time) = _sar_to_time($line, $first_time, $last_time);

         $memusage{mem}->{usage}->{$last_time} = $percent_memused;
         $memusage{mem}->{MBused}->{$last_time} = $memused / (1024);
         $memusage{mem}->{MBcached}->{$last_time} = $cached / (1024);
      }
   }

   $self->{sar_mem}->{length} = $last_time;
   $self->{sar_mem}->{raw} = \%memusage;
   $self->{sar_max_time_to_consider} = $last_time + $self->{sar_max_time_to_consider} if($self->{sar_max_time_to_consider} < 0);

   my ($average, $sum, $count, $min, $max) = _sar_get_average_from_relevant_data($memusage{mem}->{usage}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});
   $self->{sar_mem}->{average} = int($average);
   $self->{sar_mem}->{usage} = int($average);
   $self->{sar_mem}->{min_usage} = int($min);
   $self->{sar_mem}->{max_usage} = int($max);

   ($average, $sum, $count, $min, $max) = _sar_get_average_from_relevant_data($memusage{mem}->{MBused}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});

   $self->{sar_mem}->{min_MBused} = int($min);
   $self->{sar_mem}->{max_MBused} = int($max);
   $self->{sar_mem}->{avg_MBused} = int($average);

   ($average, $sum, $count, $min, $max) = _sar_get_average_from_relevant_data($memusage{mem}->{MBcached}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});

   $self->{sar_mem}->{min_MBcached} = int($min);
   $self->{sar_mem}->{max_MBcached} = int($max);
   $self->{sar_mem}->{avg_MBcached} = int($average);


   if((defined $opt) && $opt->{gnuplot}) {
      my @_times = sort keys %{$self->{sar_mem}->{raw}->{mem}->{MBused}};
      my @_values = map { $self->{sar_mem}->{raw}->{mem}->{MBused}->{$_} } @_times;
      my @_values2 = map { $self->{sar_mem}->{raw}->{mem}->{MBcached}->{$_} } @_times;
      my @_values3 = map { $self->{sar_mem}->{raw}->{mem}->{MBused}->{$_} - $self->{sar_mem}->{raw}->{mem}->{MBcached}->{$_} } @_times;

      ## Total, cached and not cached

      my @gnuplot_xy;
      push(@gnuplot_xy, \@_times); #x
      push(@gnuplot_xy, \@_values); #y

      push(@gnuplot_xy, \@_times); #x
      push(@gnuplot_xy, \@_values2); #y

      push(@gnuplot_xy, \@_times); #x
      push(@gnuplot_xy, \@_values3); #y

      my $plot = Graphics::GnuplotIF->new(persist=>1);
      $plot->gnuplot_set_xlabel("Time (s)");
      $plot->gnuplot_set_ylabel( "Memory used (MB)" );

      $plot->gnuplot_set_style( "points" );

      if($opt->{gnuplot_file}){
          plot_to_file($opt, $plot, $self->{filename});
      }

      $plot->gnuplot_set_plot_titles(("Total", "Cached", "not cached"));
      $plot->gnuplot_plot_many( @gnuplot_xy );

      @gnuplot_xy = ();
      push(@gnuplot_xy, \@_times); #x
      push(@gnuplot_xy, \@_values); #y
      _gnuplot_mem($self, $opt, \@gnuplot_xy, "Total");

      @gnuplot_xy = ();
      push(@gnuplot_xy, \@_times); #x
      push(@gnuplot_xy, \@_values2); #y
      _gnuplot_mem($self, $opt, \@gnuplot_xy, "Cached");

      @gnuplot_xy = ();
      push(@gnuplot_xy, \@_times); #x
      push(@gnuplot_xy, \@_values3); #y
      _gnuplot_mem($self, $opt, \@gnuplot_xy, "NotCached");

   }

   return $self->{sar_mem};
}

sub sar_parse_cpu {
   my ($self, $opt) = @_;
   $self->_sar_sanity_check;

   my $first_time = 0;
   my $last_time = 0;
   my %times = ();
   my %cpus = ();
   while (my $line = <$self>) {
      next if ($line =~ /Linux/);
      last if($line =~ m/^Average/);
      if($line =~ m/CPU/) {
         ($first_time, $last_time) = _sar_to_time($line, $first_time, $last_time);
      } elsif($line =~ m/\d\d:\d\d:\d\d/ && $line !~ m/all|CPU/) {
         (my $proc, my $user, my $nice, my $sys, my $iowait, my $steal, my $idle) = ($line =~ m/(\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)$/);
         if (!defined($proc)) {
            $line =~ s/\n$//;
            print "[$self] Undefined line : ".$line."\n";
            next;
         }
         if($user + $nice + $sys + $iowait + $steal + $idle == 0) {
            $idle = 100;
         } else {
            $cpus{$proc}->{always_dead} = 0;
         }
         $cpus{$proc}->{idle}->{$last_time} = $idle;
         $cpus{$proc}->{sys}->{$last_time} = $sys;
         $cpus{$proc}->{user}->{$last_time} = $user;
      }
   }
   for my $cpu (keys %cpus) {
      $cpus{$cpu}->{always_dead} //= 1;
   }

   $self->{sar_cpu}->{length} = $last_time;
   $self->{sar_cpu}->{nb_cpus} = scalar keys %cpus;
   $self->{sar_cpu}->{raw}->{cpu} = \%cpus;
   $self->{sar_max_time_to_consider} = $last_time + $self->{sar_max_time_to_consider} if($self->{sar_max_time_to_consider} < 0);

   my @gnuplot_xy;
   for my $cpu (keys %{$self->{sar_cpu}->{raw}->{cpu}}) {
      next if $cpus{$cpu}->{always_dead};

      my ($average, $sum, $count) = _sar_get_average_from_relevant_data($cpus{$cpu}->{idle}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});
      $self->{sar_cpu}->{cpu}->{$cpu}->{idleness} = int($average);
      $self->{sar_cpu}->{cpu}->{$cpu}->{usage} = int(100-$average);

      ($average, $sum, $count) = _sar_get_average_from_relevant_data($cpus{$cpu}->{sys}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});
      $self->{sar_cpu}->{cpu}->{$cpu}->{sys} = int($average);

      ($average, $sum, $count) = _sar_get_average_from_relevant_data($cpus{$cpu}->{user}, $self->{sar_max_time_to_consider}, $self->{sar_min_time_to_consider});
      $self->{sar_cpu}->{cpu}->{$cpu}->{user} = int($average);

      if((defined $opt) && $opt->{gnuplot}) {
         my @_times = sort keys %{$self->{sar_cpu}->{raw}->{cpu}->{$cpu}->{idle}};
         my @_values = map { $self->{sar_cpu}->{raw}->{cpu}->{$cpu}->{idle}->{$_} } @_times;

         push(@gnuplot_xy, \@_times); #x
         push(@gnuplot_xy, \@_values); #y
      }
   }

   if((defined $opt) && $opt->{gnuplot}) {
         my $plot = Graphics::GnuplotIF->new(persist=>1);
         $plot->gnuplot_set_title( "CPUs" );
         $plot->gnuplot_set_ylabel("Idleness (%)");
         $plot->gnuplot_set_xlabel("Time (s)");
         $plot->gnuplot_set_style( "points" );

         $plot->gnuplot_set_yrange(0, 100);

         if($opt->{gnuplot_file}){
             plot_to_file($opt, $plot, $self->{filename}.".all");
         }

         $plot->gnuplot_plot_many( @gnuplot_xy );
   }

   my ($average, $min, $max) = _sar_get_global_average($self->{sar_cpu}->{cpu}, 'idleness');
   $self->{sar_cpu}->{average_idleness} = int($average);
   $self->{sar_cpu}->{min_idleness} = int($min);
   $self->{sar_cpu}->{max_idleness} = int($max);
   $self->{sar_cpu}->{usage} = int(100-$average);
   $self->{sar_cpu}->{min_usage} = int(100-$max); #min usage = 100 - max idleness
   $self->{sar_cpu}->{max_usage} = int(100-$min);

   ($average, $min, $max) = _sar_get_global_average($self->{sar_cpu}->{cpu}, 'sys');
   $self->{sar_cpu}->{average_sys} = int($average);
   $self->{sar_cpu}->{min_sys} = int($min);
   $self->{sar_cpu}->{max_sys} = int($max);

   ($average, $min, $max) = _sar_get_global_average($self->{sar_cpu}->{cpu}, 'user');
   $self->{sar_cpu}->{average_user} = int($average);
   $self->{sar_cpu}->{min_user} = int($min);
   $self->{sar_cpu}->{max_user} = int($max);

   return $self->{sar_cpu};
}

sub sar_parse {
   my ($self, $opt) = @_;
   $self->{iterator_value} = 0;

   while (my $line = <$self>) {
      if($line =~ m/\d\d:\d\d:\d\d/) {
         $self->{iterator_value} = 0;
         if($line =~ m/CPU/) {
            return $self->sar_parse_cpu($opt);
         } elsif($line =~ m/IFACE/) {
            return $self->sar_parse_dev($opt);
         } elsif($line =~ m/kbmemfree/) {
            return $self->sar_parse_mem($opt);
         } elsif($line =~ m/rd_sec\/s/) {
            return $self->sar_parse_disk($opt);
         }  else {
            print "[$self] Found no suitable way to interpret file\n";
            return undef;
         }
      }
   }
   print "[$self] Not a valid sar file\n";
   return undef;
}
1;
