#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use Graphics::GnuplotIF qw(GnuplotIF);

package File::Slg;
=head
Usage:
   $file->slg_parse;

Returns:
   A hashmap 'clients_values' with an entry for each number of clients tested. Common fields are :
   {
      nbreq    => number of requests per second
      mbits    => throughput in Mbit/s
      ct       => connection time
      rt       => response time
      crt      => connection+response time
      avgtime  => average total time
      errors   => nb errors
   }
   Each of these field has a corresponding field_dev for the stddev.
   
   A hashmap 'option' is also available.
   A list 'clients' contains each of the keys of 'clients_values'.

=cut


my $verbose;

sub _slg_parse_options {
   my ($self, $line) = @_;
   my %opts = %{$self->{slg}->{options}} if (defined($self->{slg}->{options}));

   if ($line =~ /^\*\s+/) { #/proc value
      my ($opt, $val) = $line =~ /^\*\s+(\S+)\s+(.+)$/;
      $opts{proc}->{$opt} = $val;
   }
   elsif ($line =~ /^\s+\-\s/) { #slg option
      my ($opt, $val) = $line =~ /^\s+\-\s([^:]+)(:?.*)$/;
      if (!defined($val) || $val eq "") {
         chomp($opt);
         $val = "activated";
      }
      else {
         $val =~ s/^:\s*//;
      }
      $opts{slg}->{$opt} = $val;
   }
   else {
      #DEBUG
      print STDERR "(SLG optsions) skipping line : $line\n" if ($verbose);
   }
   $self->{slg}->{options} = \%opts;
}

sub _slg_parse_values {
   my ($self, $line) = @_;
   my %vals;
   my ($nbclients, $nbreq, $nbreq_dev, $mbits, $mbits_dev, $ct, $ct_dev, $rt, $rt_dev, $crt, $crt_dev, $avgtime, $avgtime_dev, $errors, $errors_dev);
   #  nbC	     req/s       sdev	       Mbits/s       sdev	  CT (µs)       sdev	  RT (µs)       sdev	 CRT (µs)       sdev	tavgTotalTime (µs)     stddev	    errors     stddev
   if ($line =~ m/\s*(\S+)\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%/) {
      ($nbclients, $nbreq, $nbreq_dev, $mbits, $mbits_dev, $ct, $ct_dev, $rt, $rt_dev, $crt, $crt_dev, $avgtime, $avgtime_dev, $errors, $errors_dev) = ($line =~ m/\s*(\S+)\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%/);
      $vals{nbreq} = $nbreq;
      $vals{nbreq_dev} = $nbreq_dev;
      $vals{mbits} = $mbits;
      $vals{mbits_dev} = $mbits_dev;
      if ($ct !~ /nan/) {
         $vals{ct} = $ct;
         $vals{ct_dev} = $ct_dev;
      }
      if ($rt !~ /nan/) {
         $vals{rt} = $rt;
         $vals{rt_dev} = $rt_dev;
      }
      if ($crt !~ /nan/) {
         $vals{crt} = $crt;
         $vals{crt_dev} = $crt_dev;
      }
      if ($avgtime !~ /nan/) {
         $vals{avgtime} = $avgtime;
         $vals{avgtime_dev} = $avgtime_dev;
      }
      $vals{errors} = $errors;
      $vals{errors_dev} = $errors_dev;
   }
   else {
      print STDERR "Error parsing values. Ignoring line : $line\n";
   }
   $self->{slg}->{clients_values}->{$nbclients} = \%vals;
}

sub slg_parse_output {
   my ($self, $opt_ptr) = @_;

   while (my $line = <$self>) {
      #  nbC	     req/s       sdev	       Mbits/s       sdev	  CT (µs)       sdev	  RT (µs)       sdev	 CRT (µs)       sdev	tavgTotalTime (µs)     stddev	    errors     stddev
      if ($line =~ m/\s*(\S+)\s+(\S+)\s+(\S+)%\s+(\S+)\s+(\S+)%/) {
         $self->_slg_parse_values($line);
      } else {
         next if $line =~ m/^\s*$/;
         $self->_slg_parse_options($line);
      }
   }
   
   my @clients_keys = sort {$a <=> $b} keys %{$self->{slg}->{clients_values}};
   $self->{slg}->{clients} = \@clients_keys;

   if((defined $opt_ptr) && $opt_ptr->{gnuplot} && scalar (@{$self->{slg}->{clients}}) > 0) {
      my (@x, @yth, @yreq);
      for my $cli ( @{$self->{slg}->{clients}}) {
         push(@x,$cli);
         push(@yth,$self->{slg}->{clients_values}->{$cli}->{mbits});
         push(@yreq,$self->{slg}->{clients_values}->{$cli}->{nbreq});
      }
      my $filename = $self->{filename};
      $filename =~ s/.+\///;
      $filename =~ s/_rate-\d+//;
      my @gnuplot_xy;
      if ($opt_ptr->{plot_mbits} ) {
         push(@gnuplot_xy, \@x); #x
         push(@gnuplot_xy, \@yth); #y
         my $thplot = Graphics::GnuplotIF->new(persist=>1);
         $thplot->gnuplot_set_title( "$filename" );
         $thplot->gnuplot_set_xlabel( "NB clients" );
         $thplot->gnuplot_set_ylabel( "Mbits/sec" );
         $thplot->gnuplot_set_yrange( 0,10000);
         $thplot->gnuplot_set_style( "linespoints" );
         $thplot->gnuplot_plot_many( @gnuplot_xy );
      }

      @gnuplot_xy = ();
      push(@gnuplot_xy, \@x); #x
      push(@gnuplot_xy, \@yreq); #y
      my $reqplot = Graphics::GnuplotIF->new(persist=>1);
      $reqplot->gnuplot_set_title( "$filename" );
      $reqplot->gnuplot_set_xlabel( "NB clients" );
      $reqplot->gnuplot_set_ylabel( "Nb Requests/sec" );
      $reqplot->gnuplot_set_yrange( 0,100000);
      $reqplot->gnuplot_set_style( "linespoints" );
      $reqplot->gnuplot_plot_many( @gnuplot_xy );
   }

   return $self->{slg};
}



sub slg_parse {
   my ($self, $opt) = @_;
   $verbose = 0;
   $verbose = 1 if((defined $opt) && $opt->{verbose});

   return $self->slg_parse_output($opt);
}
1;
