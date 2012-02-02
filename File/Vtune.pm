#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Data::Dumper;
use lib "$FindBin::Bin";
use File::Utils;
use Carp::Always;
use File::Vtune::Column;

package File::Vtune;

=head1 simple vtune parser

Usage: $op = vtune->new(/path/to/file);

$op   -> { type }          $  = 'vtune'
      -> { file }          $  = '/path/to/file'

      -> { nb_events }     $  = number of events contained in the file
      -> { events }        \@ = array of events contained in the file
      -> { events_metadata } -> { $event } -> { 'event' }      $  = real name of $event
                                           -> { 'nb_samples' } $  = total number of samples found in the file for this event (NOT like Oprofile, it counts samples*count)

      Optional:
      -> { times }         \@ = times (in second) contained in the file. Taken from lines containing `date` output



=head2 Vtune simple parser : 'item'
An item represents a specific sample entry in the vtune file.

$item -> { 'samples'}      
         { 'app' }
         { 'func' }



=head3 Vtune simple parser : 'vtune_column'
Represents a column of a vtune file or an agregate of columns.

$column ->  { type }    $  = 'vtune_column'
            { samples } $  = total number of samples in the column
            { cpu }     $  = 'all'
            { event }   $  = corresponding event
            { values }  \% = hashmap of items

         -> find(item)
            Find an item matching item...
=cut

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
   $self->{type} = 'vtune';
   $self->{file} = $file;

   die "Wrong usage of class vtune: use vtune->new(file)" if(!defined($file));
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

sub parse_header {
   my ($self) = @_;
   my $line;
   my @tmp = ();
   $self->{events} = \@tmp;
   while($line = shift @{$self->{lines}}) {
      last if($line =~ m/------------------/);
      if((my $evts_list) = $line =~ m/^Function\s+Module\s+(.+\s+)+/) {
         $evts_list =~ s/ Event Count//g;
         my @evts = split(" ", $evts_list);
         for my $evt (@evts) {
            my ($name, $type) = $evt =~ /(.+):(\w+)/;
            push(@{$self->{events}}, $name);
            $self->{events_metadata}->{$name}->{'event'} = $name;
            $self->{events_metadata}->{$name}->{'type'} = $type;
         }
      }
      elsif ($line =~ /Error/) {
         $errno = $line;
         $errno = "No event found in file" if ($line =~ /Cannot find raw collector data/);
         return 1;
      } elsif($line =~ m/CES?T/) {
         (my $day, my $hour, my $min, my $sec) = ($line =~ m/^\w+ \w+ (\d+) (\d+):(\d+):(\d+)/);
         my $time = $day*24*60*60+$hour*60*60+$min*60+$sec;
         push(@{$self->{times}}, $time);
      } 
   }

   $self->{nb_events} = scalar(@{$self->{events}});
   $self->{nb_columns} = $self->{nb_events} + 2; #func name + module name = 2
   
   for(my $i = 0; $i < $self->{nb_events}; $i++) {
      my $col = Vtune::Column::new;
      $col->{cpu} = 'all';
      $col->{event} = $self->{events}->[$i];
      push(@{$self->{columns}}, $col);
   }
   if(!defined($self->{events}) || scalar @{$self->{events}} <= 0) {
      $errno = "No event found in file";
      return 1;
   } 

   return 0;
}

sub parse_content {
   my ($self) = @_;

   my $line;
   while($line = shift @{$self->{lines}}) {
      if($line =~ m/(\d+$)/) {
         $line =~ s/(\S) (\S)/$1_$2/g; #eliminate single spaces

         my @names = ($line =~ m/(?:[\S]+|\d+)\s+/g);
         if(scalar @names != $self->{nb_columns} && scalar @names != 0) {
            print "[WARNING] Strange line: $line \t\tNAMES=".join(",",@names)."\n";
            next;
         }

         my $func_desc = {
            'func' => $names[0],
            'app' => $names[1],
         };
         for(my $i = 0; $i < $self->{nb_events}; $i++) {
            (my $sample) = ($names[$i+2] =~ m/(\d+)/g);
            $self->{columns}->[$i]->push_val($sample, $func_desc);
         }
      } elsif($line =~ m/CES?T/) {
         push(@{$self->{lines}}, $line);
         last;
      }
   }
   $self->{total_samples} = 0;
   for(my $i = 0; $i < $self->{nb_events}; $i++) {
      $self->{events_metadata}->{$self->{events}->[$i]}->{nb_samples} +=  $self->{columns}->[$i]->{samples};
      $self->{total_samples} += $self->{columns}->[$i]->{samples};
      #print "[WARNING] no sample found for $self->{events}->[$i]\n" if ($self->{columns}->[$i]->{samples} == 0);
   }
   if ($self->{total_samples} == 0) {
      $errno = "No event found in file";
      return 1;
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

sub samples {
   my ($self, $filter ) = @_;
   my $column = $self->try_to_guess_column($filter);
   return if($column == -1);
   return $self->{columns}->[$column];
}

sub get_events {
   my ($self) = @_;
   return $self->{events};
}

sub get_errno {
   return $errno;
}
1;
