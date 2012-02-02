#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Switch;
use Data::Dumper;
use lib "$FindBin::Bin";
use File::Utils;
use File::Oprofile::Checker;
use File::Oprofile::Column;
use Carp::Always;

package File::Oprofile;
our @ISA = qw(File::Oprofile::Checker);

=head1 Oprofile ultimate parser : oprofile

Usage: $op = oprofile->new(/path/to/file);

$op   -> { type }          $  = 'oprofile'
      -> { file }          $  = '/path/to/file'

      -> { per_cpu }       $  = 1 if the oprofile file is a per cpu dump ; 0 if not
      -> { nb_cpus }       $  = number of cpus which performed the dump if per_cpu == 1; 0 otherwise
      -> { cpus }          \@ = array of cpus in the order they appear in the file if per_cpu == 1; undef otherwise
      -> { dies }          \@ = same as cpus but with dies (/!\ deducted from @cpus without any analysis of the real topology)

      -> { nb_events }     $  = number of events contained in the file
      -> { events }        \@ = array of events contained in the file
      -> { events_metadata } -> { $event } -> { 'event' }   $  = real name of $event
                                           -> { 'mask'  }   $  = unitmask of $event
                                           -> { 'count' }   $  = sampling frequency of $event
      -> { total_samples } $  = total number of samples found in the file (use with care as is sums the _samples_ and not samples*count)
      -> { nb_errors }     $  = total number of missed samples

      -> { estimated_freq }$  = frequency of the cpu as read from the file

      -> top(filter, [threshold, 'trend'])
            Get the top functions (or image names if 'trend' is specified) of:
                  - A specific cpu if filter is a number (0 = cpu0) or 'cpuX'       [per_cpu file only]
                  - A specific die if filter is 'dieX'                              [per_cpu file only]
                  - The global file if filter is 'all'                              [per_cpu file only]
                  - A specific event is filter is an event contained in @events     [returns 'all' in a per_cpu file]
            Return an array of 'items' (see bellow)

      -> samples(filter)
            Return an full 'oprofile_column' of samples matching filter.
            Same options as top for filter

      -> compare(oprofile | oprofile_column )
            * Compare $op with another $op' return a full oprofile object with all attributes specified
         or * Compare whatever makes sense with oprofile_column (same event, same cpu, ...) and return the corresponding oprofile_column

      -> safe_get_item(filter, item)
            Get the item of $op corresponding to the item passed as parameter.
            ie.:  $item = $op1->top('cpu0')->[0];
                  $op2->safe_get_item('cpu0', $item); #Same item as the one in op1 or an empty item
            Returns an 'item'
               
      -> apply_function_on_samples(func)
            Applies func on all 'items' of the file



      Optional:
      -> { times }         \@ = times (in second) contained in the file. Taken from lines containing `date` output




=head2 Oprofile ultimate parser : 'item'
An item represents a specific sample entry in the oprofile file.

$item -> { 'samples'}      
         { 'percent' }
         { 'app' }
         { 'func' }



=head3 Oprofile ultimate parser : 'oprofile_column'
Represents a column of an oprofile file or an agregate of columns.

$column ->  { type }    $  = 'oprofile_column'
            { samples } $  = total number of samples in the column
            { percents }$  = sum of all percents

            { values }  \% = hashmap of items
            { trends }  \% = hashmap of items

         -> top([threshold, 'trend'])
            Same as oprofile->top but no need to filter

         -> compare(oprofile_column)
            Same as oprofile->compare but cannot take a file in parameter

         -> find(item)
            Find an item matching item...

         -> apply_function_on_samples(func)
            Same as oprofile->apply_function_on_samples
=cut

#TODO : make sure samples' count are taken into account for the comparison

my %cpu_die = ( 
   0 => 0, 4 => 0, 8 => 0, 12 => 0,
   1 => 3, 5 => 3, 9 => 3, 13 => 3,
   2 => 2, 6 => 2, 10 => 2, 14 => 2,
   3 => 1, 7 => 1, 11 => 1, 15 => 1, 
);
my %Explainations = (
   'MEMORY_CONTROLLER_REQUEST:01' => 'Write requests',
   'MEMORY_CONTROLLER_REQUEST:02' => 'Read requests',
   'MEMORY_CONTROLLER_REQUEST:08' => '32B Writes',
   'MEMORY_CONTROLLER_REQUEST:10' => '64B Writes',
   'CPU_DRAM_REQUEST_TO_NODE:01' => 'R/W to Node 0',
   'CPU_DRAM_REQUEST_TO_NODE:02' => 'R/W to Node 1',
   'CPU_DRAM_REQUEST_TO_NODE:04' => 'R/W to Node 2',
   'CPU_DRAM_REQUEST_TO_NODE:08' => 'R/W to Node 3',
   'IO_DRAM_REQUEST_TO_NODE:01' => 'R/W to Node 0',
   'IO_DRAM_REQUEST_TO_NODE:02' => 'R/W to Node 1',
   'IO_DRAM_REQUEST_TO_NODE:04' => 'R/W to Node 2',
   'IO_DRAM_REQUEST_TO_NODE:08' => 'R/W to Node 3',
   'CPU_IO_REQUESTS_TO_MEMORY:a2' => 'IO->Mem Local',
   'CPU_IO_REQUESTS_TO_MEMORY:92' => 'IO->Mem Distant',
   'CPU_IO_REQUESTS_TO_MEMORY:a8' => 'CPU->Mem Local',
   'CPU_IO_REQUESTS_TO_MEMORY:98' => 'CPU->Mem Distant',
);

my $errno;

sub new {
   my $self = {};
   bless $self;
   my $ret = $self->initialize($_[0]);
   if($ret) {
      return;
   } else {
      return $self;
   }
}

sub initialize {
   my ($self, $file) = @_;
   $self->{type} = 'oprofile';
   $self->{file} = $file;
   $self->{per_cpu} = 0;
   $self->{nb_cpus} = 0;

   die "Wrong usage of class oprofile: use oprofile->new(file)" if(!defined($file));
   if(ref($file) ne "File::CachedFile") {
      $self->{file} = File::CachedFile::new($file);
   }
   return $self->parse_file();
}

sub parse_file {
   my ($self) = @_;
   my @lines = $self->{file}->get_lines;
   $self->{lines} = \@lines;
   if($self->parse_header()) {
      return 1;
   }
   if($self->parse_content()) {
      return 1;
   }
   if($self->parse_footer()) {
      return 1;
   }
   return 0;
}

sub get_dies {
   my ($self) = @_;
   if(defined($self->{dies})) {
      return $self->{dies};
   }

   my %dies;
   for my $cpu (@{$self->{cpus}}) {
      $dies{$self->cpu_to_die($cpu)} = 1;
   }
   my @arr = sort { $a <=> $b } keys %dies;
   return \@arr;
}

sub cpu_to_die {
   my ($self, $cpu) = @_;
   return $cpu_die{$cpu};
}

sub parse_header {
   my ($self) = @_;
   my $line;
   while($line = shift @{$self->{lines}}) {
      last if($line =~ m/samples/);
      if($line =~ m/^Counted ([\w\.]+) events .* mask of (0x\w+) .* count (\d+)/) {
         my $evt = $1.':'.$2;
         push(@{$self->{events}}, $evt);
         $self->{events_metadata}->{$evt}->{'event'} = $1;
         $self->{events_metadata}->{$evt}->{'mask'} = $2;
         $self->{events_metadata}->{$evt}->{'count'} = $3;
      } elsif($line =~ m/Samples on CPU (\d+)/) {
         push(@{$self->{cpus}}, $1);
         $self->{per_cpu} = 1;
         $self->{nb_cpus}++;
      } elsif($line =~ m/CES?T/) {
         (my $day, my $hour, my $min, my $sec) = ($line =~ m/^\w+ \w+ (\d+) (\d+):(\d+):(\d+)/);
         my $time = $day*24*60*60+$hour*60*60+$min*60+$sec;
         push(@{$self->{times}}, $time);
      } elsif($line =~ m/speed (\d+\.\d+) MHz/) {
         $self->{estimated_freq} = $1;
      }
   }
   
   if(!defined($self->{events}) || scalar @{$self->{events}} <= 0) {
      $errno = "No event found in file";
      return 1;
   } else {
      $self->{nb_events} = @{$self->{events}};
      if($self->{nb_events} == 1 && !$self->{per_cpu}) { 
         #Oprofile does not add a "Sample on CPU 0" when there is only one CPU.
         push(@{$self->{cpus}}, 0);
         $self->{per_cpu} = 1;
         $self->{nb_cpus}++;
      }
   }
   if(scalar @{$self->{events}} >= 2 && $self->{per_cpu} >= 1) {
      $errno = "Found a per cpu profile file with multiple events";
      return 1;
   }

   my $nb_samples = () = ($line =~ m/samples/g);
   my $nb_names = () = ($line =~ m/name/g);
   if($nb_samples != $self->{nb_cpus} && $nb_samples != $self->{nb_events}) {
      $errno = "The number of sample columns ($nb_samples) does not match the number of events (".$self->{nb_events}.") or cpus (".$self->{nb_cpus}.")";
      return 1;
   }
   $self->{nb_columns} = $nb_samples;
   $self->{nb_names} = $nb_names;
   if($nb_names != 3 && $nb_names != 2 && $nb_names != 1) {
      die "Unknown name format : nb_names=$nb_names\n";
   }

   for(my $i = 0; $i < $self->{nb_columns}; $i++) {
      my $col = Oprofile::Column::new;
      if($self->{per_cpu}) {
         $col->{cpu} = $self->{cpus}->[$i];
         $col->{event} = $self->{events}->[0];
      } else {
         $col->{cpu} = 'all';
         $col->{event} = $self->{events}->[$i];
      }
      push(@{$self->{columns}}, $col);
   }
   if($self->{per_cpu}) {
      $self->{dies} = $self->get_dies(); 

      my $col = Oprofile::Column::new;
      $col->{cpu} = 'all';
      $col->{event} = $self->{events}->[0];
      push(@{$self->{columns}}, $col);

      for(my $i = 0; $i < 4; $i++) {
         $col = Oprofile::Column::new;
         $col->{cpu} = 'die'.$i;
         $col->{event} = $self->{events}->[0];
         push(@{$self->{columns}}, $col);
      }
   } 
   return 0;
}

sub parse_content {
   my ($self) = @_;

   my $line;
   while($line = shift @{$self->{lines}}) {
      if($line =~ m/(^\d+)/) {
         my @tab = ($line =~ m/\d+\s+(?:\d+\.\d+(?:e-\d+)?|0)/g);
         if(scalar @tab != $self->{nb_columns} && scalar @tab != 0) {
            print "[WARNING] Strange line: $line";
            next;
         }
         my $names_str = $';
         #A named symbol may be /dev/abc_def-gh+ij.01234@toto (stuff) which translates into:
         # MATCH=(?: 1 | 2 ) so that parenthesis are not taken for $1 (we want to $1 to be the first match of /g)
         # 1: any character listed below
         # 2: space( because we only want to match spaces before parenthesis
         # the full regexp is (MATCH)+(?: \(.*\) )? to match function names containing parenthesis (and maybe arguments) when possible
         my @names = ($names_str =~ m/(?:[\w\.\d\-\_\@\/\+\)\~\:\,\*]|\(no symbols\))+(?:\(.*\))?/g);
         if(scalar @names != $self->{nb_names}) {
            if($names_str =~ m/(vdso|heap|anon)/ ) {
               @names = ($1, $1);
            } elsif($names_str =~ m/libjvm.so/) {
               @names = ("libjvm.so", "libjvm.so");
            } else {
               die "Strange name pattern : $names_str ($line) TAB=|@tab| ".$self->{nb_names}."\n";
            }
         }
         shift @names if($#names == 2);
         my $func_desc = {
            'app' => $names[0],
            'func' => $names[1],
         };
         $func_desc->{func} = $names[0] if ($#names == 0);
         $func_desc->{app} = "" if ($#names == 0);
         for(my $i = 0; $i < $self->{nb_columns}; $i++) {
            (my $sample, my $percent) = ($tab[$i] =~ m/(\d+)\s+(\d+\.\d+(?:e-\d+)?|0)/g);
            $self->{columns}->[$i]->push_val($sample, $percent, $func_desc);
         }
         #Sum everything in last column when using per_cpu
         if($self->{per_cpu}) {
            for(my $i = 0; $i < $self->{nb_columns}; $i++) {
               (my $sample, my $percent) = ($tab[$i] =~ m/(\d+)\s+(\d+\.\d+(?:e-\d+)?|0)/g);
               $self->{columns}->[$self->{nb_columns}]->push_val($sample, $percent, $func_desc);         #all
               $self->{columns}->[$self->{nb_columns}+1+$self->cpu_to_die($self->{cpus}->[$i])]->push_val($sample, $percent, $func_desc);  #die
            }
         }
      } elsif($line =~ m/CES?T/) {
         push(@{$self->{lines}}, $line);
         last;
      }
   }
   for(my $i = 0; $i < $self->{nb_columns}; $i++) {
      $self->{total_samples} +=  $self->{columns}->[$i]->{samples};
   }

   return 0;
}

sub parse_footer {
   my ($self) = @_;
   my $line;
   $self->{nb_errors} = 0;
   while($line = shift @{$self->{lines}}) {
      if($line =~ m/CES?T/) {
         (my $day, my $hour, my $min, my $sec) = ($line =~ m/^\w+ \w+ (\d+) (\d+):(\d+):(\d+)/);
         my $time = $day*24*60*60+$hour*60*60+$min*60+$sec;
         push(@{$self->{times}}, $time);
      } elsif($line =~ m/NBERRORS/) {
         if($line =~ m/sudo/) {
            $line = shift @{$self->{lines}};
         }
         ($self->{nb_errors}) = ($line =~ m/(\d+)/);
      }
   }
   if($self->{nb_errors} > 0) {
      printf "[WARNING %s] Missed %d samples/%d (%d%%)!\n", $self->{file}, $self->{nb_errors},  ($self->{total_samples}+$self->{nb_errors}), $self->{nb_errors} / ($self->{total_samples}+$self->{nb_errors})*100.;
   }
   return 0;
}

sub try_to_guess_column {
   my $self = $_[0];
   my $filter = $_[1];
   if(!defined($filter)) {
      die "No filter ?";
   }

   my $column = -1;
   if($filter =~ m/^cpu(\d+)$/ || $filter =~ m/^(\d+)$/) {
      if(!$self->{per_cpu}) {
         $errno = "Trying to specify a cpu filter on a global file ?!";
         return -1;
      }
      my $cpu = $1;
      for (my $i = 0; $i < $self->{nb_cpus}; $i++) {
         if($cpu == $self->{cpus}->[$i]) {
            $column = $i;
            last;
         }
      }
   } elsif($filter =~ m/^die(\d+)$/) {
      if(!$self->{per_cpu}) {
         $errno = "Trying to specify a die filter on a global file ?!";
         return -1;
      }
      my $die = $1;
      if($die > 3 || $die < 0) {
         $errno = "Die $die does not exist !";
         return -1;
      }
      $column = $self->{nb_cpus} + 1 + $die;
      if(!defined($self->{columns}->[$column]->{values})) {
         $errno = "No sample for die $die found";
         return -1;
      }
   } elsif($filter eq "all") {
      if(!$self->{per_cpu}) {
         $errno = "Please specify event on a global file";
         return -1;
      }
      $column = $self->{nb_cpus}; #all
   } else {
      for (my $i = 0; $i < $self->{nb_events}; $i++) {
         if($filter eq $self->{events}->[$i]) {
            $column = $i;
            last;
         }
      }
      if($self->{per_cpu} && $column != -1) {
         $column = $self->{nb_cpus}; #all
      }
   }
   return $column;
}

sub top {
   my ($self, $filter, $thres, $trends) = @_;
   $thres = 10 if(!defined($thres));
   my $column = $self->try_to_guess_column($filter);
   return if($column == -1);

   return $self->{columns}->[$column]->top($thres, $trends);
}

sub samples {
   my ($self, $filter ) = @_;
   my $column = $self->try_to_guess_column($filter);
   return if($column == -1);
   return $self->{columns}->[$column];
}

#Compare two columns or two files. Return a column or a file depending on the input.
#Usage : $prof->compare($another_prof or $another_prof->samples('filter'));
sub compare {
   my ($self, $sample, $filter) = @_;

   if(!defined($sample->{type})) {
      die 'No type found for $sample. See comments.';
   }
   if($sample->{type} eq 'Oprofile::Column') {
      return $self->compare_sample($sample, $filter);
   } elsif($sample->{type} eq 'oprofile') {
      return $self->compare_file($sample);
   } else {
      die 'Unknown $sample->{type}';
   }
}

sub compare_sample {
   my ($self, $sample, $filter) = @_;
   if(!defined($sample)) {
      die "You fougeaxed (sample is null)";
   }

   my $column;
   if(!defined($filter)) {
      #Check that we can compare the sample column with our own events
      my $evt = $sample->{event};
      $column = $self->try_to_guess_column($evt);
      if($column == -1) {
         $errno = "$evt does not exist in current bench";
         return;
      }
      if($sample->{cpu} ne 'all') {
         if(!$self->{per_cpu})  {
            $errno = "Comparing a per cpu sample with a global file is not allowed";
            return;
         } else {
            $column = $self->try_to_guess_column($sample->{cpu});
            if($column == -1) {
               $errno = "CPU ".$sample->{cpu}." does not exist in current file";
               return;
            }
         }
      }
   } else {
      $column = $self->try_to_guess_column($filter);
      if($column == -1) {
         $errno = "Wrong filter specified in comparison. Make sure you know what you do. ($errno)";
         return;
      }
   }

   #Actual comparison
   my $own_sample = $self->{columns}->[$column];
   return $own_sample->compare($sample);
}

sub compare_file {
   my ($self, $file) = @_;
   my $ret= {};
   bless $ret;

   $ret->{nb_cpus} = 0;
   if($self->{per_cpu} && $file->{per_cpu}) {
      $ret->{per_cpu} = 1;
   } else {
      $ret->{per_cpu} = 0;
   }

   #We iterate on $file and not $self to be consistent with the other compare functions
   for my $col (@{$file->{columns}}) {
      my $new_col = $self->compare($col);
      if(defined($new_col)) {
         push(@{$ret->{columns}}, $new_col);
         $ret->{nb_columns}++;

         my $add_evt = 1;
         if(defined($ret->{events})) {
            for my $evt (@{$ret->{events}}) {
               if($evt eq $col->{event}) {
                  $add_evt = 0;
                  last;
               }
            }
         }
         if($add_evt) {
            $ret->{nb_events}++;
            push(@{$ret->{events}}, $col->{event});
            $ret->{events_metadata}->{$col->{event}} = $self->{events_metadata}->{$col->{event}};
         }
         if($col->{cpu} =~ /^(\d+)$/) {
            push(@{$ret->{cpus}}, $1);
            $ret->{nb_cpus}++;
         }
      }
   }
   if(defined($ret->{cpus})) {
      $ret->{dies} = $ret->get_dies(); 
   }
   return $ret;
}

sub get_events {
   my ($self) = @_;
   return $self->{events};
}

sub get_errno {
   return $errno;
}

sub apply_function_on_samples {
   my $self = shift @_;
   my $func = shift @_;
   for my $col (@{$self->{columns}}) {
      $col->apply_function_on_samples($func, @_);
   }
}

sub get_item {
   my ($self, $filter, $item) = @_;
   my $samples = $self->samples($filter);
   return if(!defined($samples));
   return $samples->find($item);
}

sub safe_get_item {
   my ($self, $filter, $item) = @_;
   my $res = $self->get_item($filter, $item);
   if(!defined($res)) {
      $res = {
         'samples' => 0,
         'percent' => 0,
         'app' => $item->{'app'},
         'func' => $item->{'func'},
      };
   } else {
      $res = {
         'samples' => $res->{samples},
         'percent' => $res->{percent},
         'app' => $res->{'app'},
         'func' => $res->{'func'},
      }
   }
   return $res;
}

1;
