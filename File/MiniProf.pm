#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Switch;
use FindBin;
use lib "$FindBin::Bin";
use Math::BigInt;
use File::Utils;
use File::MiniProf::AMD;
use File::MiniProf::Intel;
use File::MiniProf::Results::Avg;
use File::MiniProf::Results::HT;
use File::MiniProf::Results::Core;
use File::MiniProf::Results::DRAM;
use File::MiniProf::Results::Latency;
use File::MiniProf::Results::TLB;
use File::MiniProf::Results::Imbalance;

package File::MiniProf;
use Exporter 'import';
our @EXPORT_OK = qw(miniprof_merge);

=head
Usage:
   $file->miniprof_parse(%opt);

   %opt :
      gnuplot => 1            : Activate a gnuplot output (default 0)
      gnuplot_max_cpu => x    : Limit the gnuplot output to CPUs [0..x[ (default : all CPUs are plotted)


Returns:
{
   events {          #List of available events in the file.
      $Event number in the file => {
         name        => $Event name,
         hwc_value   => $Event performance counter value,
      }
   }
   avail_info [      #List of things we were able to do with these events. Each 'thing' is a hash:
      {
         name => $Name of the thing (e.g. IPC)
         usable_events {      #Events used to do this thing.
            $Event name => $Event number in the file
         }
         results {
            $Core number => $Value of the thing  (e.g 0 => 0.30)
         }
      }
   ]
   analysed {
      Contains average, sum & count of events available in the file, for each core.
   }
   raw {
      Contains the raw values, as read in the file. Should never be useful (use analysed).
   }
=cut

my %parse_options = File::MiniProf::AMD::get_processed_events();
#my %parse_options = File::MiniProf::Intel::get_processed_events();

sub _local_dram_fun {
   my ($self, $core, $local_dram_fun) = @_;


   if(defined $self->{miniprof}->{memory_mapping}) {
      my %mapping = %{$self->{miniprof}->{memory_mapping}};
      my $local_dram = -1;
      for my $d (keys %mapping) {
         for my $c (@{$mapping{$d}}) {
            if($c == $core) {
               $local_dram = $d;
               last;
            }
         }

         last if ($local_dram != -1);
      }

      die "Did not find any die for core $core ($self)\n" if ($local_dram == -1);
      return $local_dram;
   }
   elsif (defined $local_dram_fun) {
      return &{$local_dram_fun} ($core);
   }
   else {
      print "I don't know what's the local DRAM of core $core. Exiting...\n";
      exit;
   }
}

sub _nb_nodes {
   my ($self) = @_;
   return 0 if(!defined $self->{miniprof}->{memory_mapping});
   return scalar(keys %{$self->{miniprof}->{memory_mapping}})
}

sub _find_matching_evt {
   my ($self, $known_evt, $subevent) = @_;

   my $fail = 0;
   my %matches = ();

   my $event_array;
   if(defined $subevent) {
      $event_array = $parse_options{$known_evt}->{events}->[$subevent];
   } else {
      $event_array = $parse_options{$known_evt}->{events};
   }

   for my $ev (@{$event_array}) {
      my $match = 0;

      my $fail_on_match = ($ev =~ m/^!/);
      my ($core_restriction) = ($ev =~ m/#(.*)$/);

      my $evt = $ev;
      $evt =~ s/^!//;
      $evt =~ s/#.*//;

      my $evt_hex = $evt;
      #For HWC events like '76', we also consider '400076' as a valid match
      #(The extra 40000 was sometimes added in Miniprof scripts to explicitly start counters)
      if($evt_hex =~ m/^[0-9a-fA-F]+$/) {
         $evt_hex = Math::BigInt->new('0x'.$evt_hex);
         if($evt_hex & 0x400000) {
            $evt_hex -= 0x400000;
         } else {
            $evt_hex += 0x400000;
         }
         $evt_hex = "".$evt_hex->as_hex;
         $evt_hex =~ s/^0x//;
      }

      for my $avail_evt (keys %{$self->{miniprof}->{events}}) {
         if(($self->{miniprof}->{events}->{$avail_evt}->{name} =~ m/^$evt$/)
            || ($self->{miniprof}->{events}->{$avail_evt}->{hwc_value} =~ m/^$evt$/i)
            || ($self->{miniprof}->{events}->{$avail_evt}->{hwc_value} =~ m/^$evt_hex$/i)) {
            if(defined $core_restriction) {
               $match = $self->{miniprof}->{events}->{$avail_evt}->{availability}->{$core_restriction};
            } else {
               $match = 1;
            }
            if($match && !$fail_on_match) {
               $matches{$ev} = $avail_evt;
            }
            last if($match);
         }
      }

      if(($match && $fail_on_match) || (!$match && !$fail_on_match)) {
         $fail = 1;
         last;
      }
   }
   if(!$fail) {
      push(@{$self->{miniprof}->{avail_info}}, {
            name => $known_evt,
            subevent => $subevent,
            usable_events => \%matches,
      });
   }

   return $fail;
}

sub _find_something_to_do {
   my ($self) = @_;
   if(!defined($self->{miniprof}->{events})) {
      die "No event found in $self";
   }

   for my $known_evt (keys %parse_options) {
      if(ref($parse_options{$known_evt}->{events}->[0]) eq 'ARRAY') {
         my $nb_subevents = scalar(@{$parse_options{$known_evt}->{events}});
         for (my $subevent = 0; $subevent < $nb_subevents; $subevent++) {
            last if(! $self->_find_matching_evt($known_evt, $subevent));
         }
      } else {
         $self->_find_matching_evt($known_evt);
      }
   }
   if(!defined($self->{miniprof}->{avail_info})) {
      die "Found nothing to do with events [".join(", ", map($_->{name}, (values %{$self->{miniprof}->{events}})))."] ($self)";
   }
}

sub _scripted_value_to_event {
   my ($self, $scripted_val, $info) = @_;
   my $event_name;

   if(!defined $info->{subevent}) {
      $event_name = $parse_options{$info->{name}}->{events}->[$scripted_val];
   } else {
      $event_name = $parse_options{$info->{name}}->{events}->[$info->{subevent}]->[$scripted_val];
   }
   return $info->{usable_events}->{$event_name};
}

sub _nb_events {
   my ($self, $info) = @_;
   if(!defined $info->{subevent}) {
      return scalar(@{$parse_options{$info->{name}}->{events}});
   } else {
      return scalar(@{$parse_options{$info->{name}}->{events}->[$info->{subevent}]});
   }
}

sub _do_info {
   my ($self, $info, %opt) = @_;
   return if(!defined($parse_options{$info->{name}}->{value}));

   my $fun = $parse_options{$info->{name}}->{value};
   if(ref($fun) eq 'ARRAY') {
      die 'Value field of event is an array; expected a string' if(!defined $info->{subevent});
      $fun = $fun->[$info->{subevent}];
   }

   switch($fun) {
      case 'sum_1/sum_0' {
         File::MiniProf::Results::Avg::sum_odd_div_sum_even_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'sum_0/sum_all' {
         File::MiniProf::Results::Avg::sum_0_div_sum_all_per_core($self, $info, \%parse_options, \%opt);
      }
      case '(sum_0+sum_1)/sum_2' {
         File::MiniProf::Results::Avg::sum_0_sum_1_div_sum_2_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'sum_1/sum_0-global' {
         File::MiniProf::Results::Avg::sum_1_div_sum_0_global($self, $info, \%parse_options, \%opt);
      }
      case '(sum_1-sum_2)/sum_0' {
         File::MiniProf::Results::Avg::sum_1_sum_2_div_sum_0_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'sum_odd/sum_even' {
         File::MiniProf::Results::Avg::sum_odd_div_sum_even_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'ht_link' {
         File::MiniProf::Results::HT::ht_link($self, $info, \%parse_options, \%opt);
      }
      case 'per_core_sum' {
         File::MiniProf::Results::Core::per_core_sum($self, $info, \%parse_options, \%opt);
      }
      case 'locality_per_node' {
         File::MiniProf::Results::DRAM::local_dram_usage($self, $info, \%parse_options, \%opt);
      }
      case 'latencies' {
         File::MiniProf::Results::Latency::sum($self, $info, \%parse_options, \%opt);
      }
      case 'tlb_cost' {
         File::MiniProf::Results::TLB::cost($self, $info, \%parse_options, \%opt);
      }
      case 'sum_all' {
         File::MiniProf::Results::Avg::sum_all_per_core($self, $info, \%parse_options, \%opt);
      }
      case 'imbalance' {
         File::MiniProf::Results::Imbalance::imbalance($self, $info, \%parse_options, \%opt);
      }
      else {
         die $parse_options{$info->{name}}->{value}." function not implemented yet!";
      }
   }
}

sub _miniprof_parse_text {
   my ($self, %opt) = @_;
   return if (defined $self->{miniprof}->{_already_parsed});

   $self->{miniprof}->{events_alias} = [];

   my $freq;
   while (my $line = <$self>) {
      #print $line;
      if($line =~ m/#Event (\d+): ([^\s]+) \((\w+)\)/) {
         my ($_event, $_name, $_hwc) = ($1, $2, $3, 0);

         if((!defined $opt{do_not_merge_events}
               || $opt{do_not_merge_events} == 0) &&
            ($line =~ m/Configured core\(s\): (\d+)/)) {
            my $core = $1;
            my $final_event = $_event;
            for my $ev (keys(%{$self->{miniprof}->{events}})) {
               if($self->{miniprof}->{events}->{$ev}->{hwc_value} eq $_hwc
                  && !($core ~~ @{$self->{miniprof}->{events}->{$ev}->{cores}})) {
                  $final_event = $ev;
                  last;
               }
            }
            $self->{miniprof}->{events}->{$final_event}->{name} //= $_name;
            $self->{miniprof}->{events}->{$final_event}->{hwc_value} //= $_hwc;
            push(@{$self->{miniprof}->{events}->{$final_event}->{cores}}, int($core));
            @{$self->{miniprof}->{events}->{$final_event}->{cores}} = sort {$a <=> $b} @{$self->{miniprof}->{events}->{$final_event}->{cores}};

            my %nodes;
            for my $node (keys %{$self->{miniprof}->{memory_mapping}}) {
               for my $c (@{$self->{miniprof}->{memory_mapping}->{$node}}) {
                  if($c ~~ @{$self->{miniprof}->{events}->{$final_event}->{cores}}) {
                     $nodes{$node} = 1;
                     last;
                  }
               }
            }
            $self->{miniprof}->{events}->{$final_event}->{availability}->{allnodes} = scalar(keys %nodes) == scalar(keys %{$self->{miniprof}->{memory_mapping}})?1:0;
            $self->{miniprof}->{events}->{$final_event}->{availability}->{allcores} = (@{$self->{miniprof}->{events}->{$final_event}->{cores}} ~~ @{$self->{miniprof}->{cores}})?1:0;

            $self->{miniprof}->{events_alias}->[$_event] = $final_event;
         } else {
            $self->{miniprof}->{events}->{$_event}->{name} = $_name;
            $self->{miniprof}->{events}->{$_event}->{hwc_value} = $_hwc;
            $self->{miniprof}->{events}->{$_event}->{cores} = $self->{miniprof}->{cores};
            $self->{miniprof}->{events}->{$_event}->{availability}->{allnodes} = 1;
            $self->{miniprof}->{events}->{$_event}->{availability}->{allcores} = 1;
            $self->{miniprof}->{events_alias}->[$_event] = $_event;
         }
      }
      elsif ($line =~ m/#Clock speed: (\d+)/) {
         $self->{miniprof}->{freq} = $1;
         $freq = $1;
      }
      elsif ($line =~ m/#Node\s+(\d+)\s+:\s+(.*)/) {
         my @cores;
         my $cores_s = $2;
         my $node = $1;
         while($cores_s =~ m/(\d+)/g){
            #print "Find core $1 for node $node\n";
            push @cores, int($1);
         }
         push(@{$self->{miniprof}->{cores}}, @cores);
         $self->{miniprof}->{memory_mapping}->{$node} = \@cores;
         $freq = $1;
      }

      last if($line =~ m/#\s*Event\s+Core/);
      next if($line =~ m/^#/);
      next if($line =~ m/^signal/);
   }


   my $first_time;
   my $last_time;
   my $line_no = 0;
   my $nsamples = 0;
   my %filtered = ();
   my @events_alias = @{$self->{miniprof}->{events_alias}};

   while (my $line = <$self>) {
      $line_no++;

      next if($line =~ m/^#/);
      next if($line =~ m/^signal/);

      $line =~ s/^\s*//; # Remove the initial spaces if any

      my @content = split(/\s+/, $line);
      (my $event, my $core, my $time, my $value) = @content;

      if(!defined $event || !defined $core || !defined $time || !defined $value){
         print "[$self] Unknown/incomplete line (file: ".$self->{filename}.", line $line_no): $line\n";
         next;
      }

      $event = $events_alias[$event];

      my $logical_time;
      my $percentage_running;

      if(scalar(@content) == 6) {
         $percentage_running = $content[4];
         $logical_time = $content[5];
         $nsamples = $logical_time if($logical_time > $nsamples);
      }
      elsif (scalar(@content) == 4) { ## Old miniprof format
         $percentage_running = 1;
         $logical_time = -1;
         $nsamples = 1;
      }
      else {
         print "[$self] Unknown/incomplete line (file: ".$self->{filename}.", line $line_no): $line\n";
         next;
      }

      if(defined $filtered{$logical_time}) {
         next;
      }

      if($logical_time >= 0 && (!defined $opt{skip_multiplexing_fix} || !$opt{skip_multiplexing_fix})) {
         if($percentage_running > 0) {
            $value /= $percentage_running;
         }
         elsif($percentage_running <= 0) {
            #print "[WARNING] Ignoring, the counter did not run (file ".$self->{filename}.", line $line_no): $line";

            ## Prevent future value to be added -- For all events (because when they are scheduled together that's for a reason usually)
            $filtered{$logical_time} = "removed";

            ## Remove values that may have been already added
            for my $c (keys %{$self->{miniprof}->{raw}}) {
               for my $e (keys %{$self->{miniprof}->{raw}->{$c}}) {
                  if (defined $self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}) {
                     my @array_lt = @{$self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}};

                     if(($#array_lt >= 0) && ($array_lt[$#array_lt] == $logical_time)) {
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{val}});
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{time}});
                        pop(@{$self->{miniprof}->{raw}->{$c}->{$e}->{logical_time}});
                     }
                  }
                  else {
                     print "BUG !\n";
                     print main::Dumper($self->{miniprof}->{raw}->{$c}->{$e});
                     exit;
                  }
               }
            }
         }
      }

      $first_time //= $time;
      $last_time = $time;
      $time = ($time-$first_time)/$freq;

      #TODO: ignore time below a defined threshold
      #print "$opt{miniprof_mintime}\t$opt{miniprof_maxtime}\n";

      if( ((defined $opt{miniprof_mintime}) && $time < $opt{miniprof_mintime})
         ||
         ((defined $opt{miniprof_maxtime}) && $time > $opt{miniprof_maxtime})){

         next;
      }

      #print main::Dumper($opt{cores});

      if((!defined $opt{cores}) || ($core ~~ @{$opt{cores}})){
         push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{val}}, $value);
         push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{time}}, $time);
         push(@{$self->{miniprof}->{raw}->{$core}->{$event}->{logical_time}}, $logical_time);
      }
   }


   if($nsamples && scalar(keys %filtered)/$nsamples > 0.1) {
      printf "#[WARNING] Ignoring %d entries (%.1f %%, file = %s)\n", scalar(keys %filtered), scalar(keys %filtered) * 100./$nsamples, $self->{filename};
   }

   if(!$nsamples) {
      printf "#[WARNING] No samples found in file %s\n", $self->{filename};
   }

   $self->{miniprof}->{rdt_duration} = $last_time - $first_time if($last_time && $first_time);
   $self->{miniprof}->{_already_parsed} = 1;
}

sub _preanalyse_events {
   my ($self) = @_;
   return if(defined $self->{miniprof}->{_already_analysed});

   for my $evt (keys %{$self->{miniprof}->{events}}) {
      for my $core (keys %{$self->{miniprof}->{raw}}) {
         #print "Event $evt, core $core : ".(scalar(@{$self->{miniprof}->{raw}->{$core}->{$evt}->{time}}))." entries\n";

         my @analyse = _miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $evt);
         $self->{miniprof}->{analysed}->{$core}->{$self->{miniprof}->{events}->{$evt}->{name}} = {
            average => $analyse[0],
            sum => $analyse[1],
            count => $analyse[2],
         };
         $self->{miniprof}->{analysed}->{$core}->{$self->{miniprof}->{events}->{$evt}->{hwc_value}} = {
            average => $analyse[0],
            sum => $analyse[1],
            count => $analyse[2],
         };
      }
   }
   $self->{miniprof}->{_already_analysed} = 1;
}

sub miniprof_parse {
   my ($self, %opt) = @_;

   $self->_miniprof_parse_text(%opt);
   $self->_preanalyse_events;

   #print main::Dumper($self->{miniprof}->{events});
   for my $e (keys %{$self->{miniprof}->{events}}) {
      if(defined $self->{miniprof}->{events}->{$e}->{name}) {
         my $ev_name = "$self->{miniprof}->{events}->{$e}->{name}";
         $parse_options{$ev_name}->{name} = $ev_name;
         $parse_options{$ev_name}->{events} = [$self->{miniprof}->{events}->{$e}->{hwc_value}];
         $parse_options{$ev_name}->{value} = 'per_core_sum';
         $parse_options{$ev_name}->{gnuplot} = 0;
      }
      else {
         print "Event $self->{miniprof}->{events}->{$e}->{hwc_value} not recognized\n";
      }
   }

   $self->_find_something_to_do;
   for my $evt (@{$self->{miniprof}->{avail_info}}) {
      $self->_do_info($evt, %opt);
   }

   return $self->{miniprof};
}

sub _miniprof_get_average_and_sum {
   my ($array_ref, $index) = @_;
   return @{$array_ref->{$index.'_analysed'}} if defined $array_ref->{$index.'_analysed'};

   my $sum = 0;
   my $count = 0;
   for my $val (@{$array_ref->{$index}->{val}}) {
      $sum += $val;
      $count++;
   }
   my @ret;
   if($count != 0) {
     @ret = ($sum / $count, $sum, $count);
   } else {
      @ret = (0, $sum, $count);
   }
   $array_ref->{$index.'_analysed'} = \@ret;
   return @ret;
}

sub miniprof_find_info {
   my ($miniprof_results, $name) = @_;
   for my $res (@$miniprof_results) {
      for my $avail_info (@{$res->{avail_info}}) {
         if($avail_info->{name} eq $name) {
            return $avail_info->{results};
         }
      }
   }
}

sub miniprof_merge {
   my ($files, %opt) = @_;

   my $miniprof_files;
   for my $f (@$files) {
      if(ref(\$f) eq 'SCALAR') {
         push(@$miniprof_files, File::CachedFile::new($f));
      } else {
         push(@$miniprof_files, $f);
      }
   }
   for my $f (@$miniprof_files) {
      $f->_miniprof_parse_text(%opt);
   }

   my $first_file = $miniprof_files->[0];
   my $file = File::CachedFile::new('virtual-'.join("-", @$files));
   $file->{miniprof}->{_already_parsed} = 1;
   $file->{miniprof}->{freq} = $first_file->{miniprof}->{freq};
   $file->{miniprof}->{rdt_duration} = $first_file->{miniprof}->{rdt_duration};
   $file->{miniprof}->{memory_mapping} = $first_file->{miniprof}->{memory_mapping};
   $file->{miniprof}->{cores} = $first_file->{miniprof}->{cores};

   my %final_events;
   my $max_samples = 0;
   my $events_count = 0;

   for my $f (@$miniprof_files) {
      for my $ev (keys %{$f->{miniprof}->{events}}) {
         $file->{miniprof}->{events}->{$events_count} = $f->{miniprof}->{events}->{$ev};
         $final_events{"$f"}->{$ev} = $events_count;
         $events_count++;
      }
      for my $core (keys %{$f->{miniprof}->{raw}}) {
         for my $fev (keys %{$f->{miniprof}->{raw}->{$core}}) {
            my $count = scalar(@{$f->{miniprof}->{raw}->{$core}->{$fev}->{val}});
            $max_samples = $count if($max_samples < $count);
         }
      }
   }

   for my $f (@$miniprof_files) {
      for my $core (keys %{$f->{miniprof}->{raw}}) {
         for my $fev (keys %{$f->{miniprof}->{raw}->{$core}}) {
            last if(!defined $f->{miniprof}->{raw}->{$core}->{$fev});

            my $final_ev = $final_events{"$f"}->{$fev};
            for (my $i = 0; $i < $max_samples; $i++) {
               push(@{$file->{miniprof}->{raw}->{$core}->{$final_ev}->{val}},
                  $f->{miniprof}->{raw}->{$core}->{$fev}->{val}->[$i] // 0);
               push(@{$file->{miniprof}->{raw}->{$core}->{$final_ev}->{time}},
                  $f->{miniprof}->{raw}->{$core}->{$fev}->{time}->[$i] // 0);
               push(@{$file->{miniprof}->{raw}->{$core}->{$final_ev}->{logical_time}}, $i);
            }
         }
      }
   }

   $file->_preanalyse_events;

   return $file;
}
