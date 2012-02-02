#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Switch;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use List::Util qw(sum);

package File::BProf;
=head
=cut


sub bprof_get_info {
   my ($self, %opt) = @_;
   our @bprof_info_samples = ();
   while (my $line = <$self>) {
      if($line =~ m/^#Event (\d+): ([^s]+) \((\w+)\), count (\d+) \(Exclude Kernel: (\w+); Exclude User: (\w+)\)/) {
         $self->{bprof}->{events}->[$1]->{number} = $1; 
         $self->{bprof}->{events}->[$1]->{name} = $2; 
         $self->{bprof}->{events}->[$1]->{raw} = $3; 
         $self->{bprof}->{events}->[$1]->{count} = $4; 
         $self->{bprof}->{events}->[$1]->{monitor_kernel} = ($5 eq "no"); 
         $self->{bprof}->{events}->[$1]->{monitor_user} = ($6 eq "no"); 
      } elsif($line =~ m/^#RDT - Total duration of the bench (\d+) \((\d+) -> (\d+)\)/) {
         $self->{bprof}->{duration}->{rdt} = $1;
      } elsif($line =~ m/^#SAMPLES - Total duration of the bench (\d+) \((\d+) -> (\d+)\)/) {
         $self->{bprof}->{duration}->{sample_timing} = $1; #Unknown value
      } elsif($line =~ m/^#TOTAL SAMPLES OF EVT (\d+)( (\d+)(?{ push(@bprof_info_samples, $^N); }))+/) {
         $self->{bprof}->{monitored_event}->{number} = $1;
         $self->{bprof}->{monitored_event}->{name} = $self->{bprof}->{events}->[$1]->{name};
         $self->{bprof}->{monitored_event}->{total_samples} = List::Util::sum(@bprof_info_samples);
         $self->{bprof}->{samples}->[$1] = \@bprof_info_samples;
         last;
      } 
   }
   for (my $i = 0; $i < scalar @{$self->{bprof}->{samples}->[$self->{bprof}->{monitored_event}->{number}]}; $i++) {
      push(@{$self->{bprof}->{monitored_event}->{active_cores}}, $i) if($self->{bprof}->{samples}->[$self->{bprof}->{monitored_event}->{number}]->[$i]);
   }
   return if !defined($self->{bprof}->{monitored_event}->{active_cores});

   $self->{bprof}->{HumanReadableDescription} = "Dump of event ". $self->{bprof}->{monitored_event}->{name} ." on core(s) [".join(",",@{$self->{bprof}->{monitored_event}->{active_cores}})."]"; 
      
   if(!defined($opt{parse}) || $opt{parse}) {
      $self->_bprof_get_content(%opt);
   }
   return $self->{bprof};
}

sub _bprof_get_content {
   my ($self, %opt) = @_;
   my ($last_samples, $last_percent, $last_lib, $last_function);
   my ($status);

   while (my $line = <$self>) {
      if(($line =~ m/^\s+(\d+)\s+(\d+\.?\d+)%\s+([^\s]+)\s+([^\s]+)/)) {
         ($last_samples, $last_percent, $last_lib, $last_function) = ($1,$2,$3,$4);
         $self->{bprof}->{monitored_event}->{samples} += $last_samples;
      } elsif($line =~ m/^\s+App repartition/) {
         $status = 0;
      } elsif($line =~ m/^\s+Top functions/) {
         $status = 1;
      } elsif($line =~ m/^\s+Callchain/) {
         $status = 2;
      } elsif(($status == 0) && ($line =~ m/--\s*(\d+\.?\d+)%\s*--\s*([^\s]+)/)) {
         $self->{bprof}->{apps}->{$2}->{samples} += $last_samples*$1/100.;
      } elsif(($status == 1) && ($line =~ m/--\s*(\d+\.?\d+)%\s*--\s*([^\s]+)/)) {
         $self->{bprof}->{functions}->{$2}->{samples} += $last_samples*$1/100.;
         push(@{$self->{bprof}->{top_callers}->{$last_function}}, {
               name => $2,
               percent =>  $1/100.,
               samples =>  $last_samples*$1/100.,
            });
      }
   }

   for my $app (keys %{$self->{bprof}->{apps}}) {
      $self->{bprof}->{apps}->{$app}->{percent} = $self->{bprof}->{apps}->{$app}->{samples} / $self->{bprof}->{monitored_event}->{samples};
   }
}

sub bprof_get_top_callers {
   my ($self, $func) = @_;
   if(ref($func) eq "ARRAY") {
      my @ret;
      my %seen_func;
      for my $f (@$func) {
         if(defined($seen_func{$f})) {
            $ret[$seen_func{$f}]->{percent} += $f->{percent};
            $ret[$seen_func{$f}]->{samples} += $f->{samples};
         } else {
            push(@ret, {
                  name => $f->{name},
                  percent => $f->{percent},
                  samples => $f->{samples},
               });
         }
      }
      return sort { $a->{percent} <=> $b->{percent} } @ret;
   } else {
      return $self->{bprof}->{top_callers}->{$func};
   }
}

sub bprof_get_percent_of_total_samples_originating_from {
   my ($self, $func) = @_;
   return $self->{bprof}->{functions}->{$func}->{samples}/$self->{bprof}->{monitored_event}->{samples};
}

1;
