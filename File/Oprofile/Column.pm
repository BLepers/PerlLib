#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Switch;
use Data::Dumper;
use lib "$FindBin::Bin";

package Oprofile::Column;

sub new {
   my $self = {};
   bless $self;
   $self->{type} = 'oprofile_column';
   return $self;
}

sub apply_function_on_items {
   my $self = shift @_;
   my $func = shift @_;

   my $total_samples = 0;
   for my $id (keys %{$self->{values}}) {
      $self->{values}->{$id} = $func->($self->{values}->{$id}, @_);
      $total_samples += $self->{values}->{$id}->{samples};
   }
   $self->{samples} = $total_samples;
}

sub apply_function_on_samples {
   my $self = shift @_;
   my $func = shift @_;
   for my $id (keys %{$self->{values}}) {
      $self->{values}->{$id}->{'samples'} = $func->($self->{values}->{$id}->{'samples'}, @_);
   }
   for my $id (keys %{$self->{trends}}) {
      $self->{trends}->{$id}->{'samples'} = $func->($self->{trends}->{$id}->{'samples'}, @_);
   }
   $self->{samples} = $func->($self->{samples}, @_);
}

sub push_val {
   my ($self, $sample, $percent , $func) = @_;
   my $id = $func->{'app'}.'-'.$func->{'func'};
   if($percent =~ m/(\d+\.\d+)e-(\d+)/) {
      $percent = $1*(10**(-$2));
   }

   #Per func
   $self->{values}->{$id}->{'app'} = $func->{'app'};
   $self->{values}->{$id}->{'func'} = $func->{'func'};
   $self->{values}->{$id}->{'samples'} += $sample;
   $self->{values}->{$id}->{'percent'} += $percent;

   #Trends
   $self->{trends}->{$func->{'app'}}->{'samples'} += $sample;
   $self->{trends}->{$func->{'app'}}->{'percent'} += $percent;
   $self->{trends}->{$func->{'app'}}->{'app'} = $func->{'app'};

   #Total
   $self->{samples} += $sample;
   $self->{percents} += $percent;
}

sub find {
   my ($self, $item) = @_;
   return $self->{values}->{$item->{'app'}.'-'.$item->{'func'}};
}

sub top {
   my $self = $_[0];
   my $threshold = $_[1] || 10;
   my $trends = $_[2];

   my $res;
   my $i = 0;
   if(defined($trends) && $trends) {
      for my $id (sort {
         $self->{trends}->{$b}->{'samples'} <=> $self->{trends}->{$a}->{'samples'}
         } keys %{$self->{trends}}) {
         last if($i++ == $threshold);
         my $val = $self->{trends}->{$id};
         push(@$res, $val);
      }
   } else {
      for my $id (sort {
         $self->{values}->{$b}->{'samples'} <=> $self->{values}->{$a}->{'samples'}
         } keys %{$self->{values}}) {
         last if($i++ == $threshold);
         my $val = $self->{values}->{$id};
         push(@$res, $val);
      }
   }
   return $res;
}

sub compare {
   my $self = $_[0];
   my $sample = $_[1];
   my $col = Oprofile::Column::new();
   $col->{event} = $self->{event};
   $col->{cpu} = $self->{cpu};

   for my $id (keys  %{$self->{values}}) {
      if(defined($sample->{values}->{$id})) {
         $col->push_val($self->{values}->{$id}->{'samples'} - $sample->{values}->{$id}->{'samples'}, 
            $self->{values}->{$id}->{'percent'} - $sample->{values}->{$id}->{'percent'}, 
            { 'app' => $self->{values}->{$id}->{'app'}, 'func' => $self->{values}->{$id}->{'func'} });
      } else {
         $col->push_val($self->{values}->{$id}->{'samples'}, 
            $self->{values}->{$id}->{'percent'} ,
            { 'app' => $self->{values}->{$id}->{'app'}, 'func' => $self->{values}->{$id}->{'func'} });
      }
   }
   for my $id (keys  %{$sample->{values}}) {
      if(!defined($col->{values}->{$id})) {
         $col->push_val(-$sample->{values}->{$id}->{'samples'}, 
            - $sample->{values}->{$id}->{'percent'} ,
            { 'app' => $sample->{values}->{$id}->{'app'}, 'func' => $sample->{values}->{$id}->{'func'} });
      }
   }
   return $col;
}

1;
