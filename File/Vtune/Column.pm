#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Switch;
use Data::Dumper;
use lib "$FindBin::Bin";

package Vtune::Column;

sub new {
   my $self = {};
   bless $self;
   $self->{type} = 'vtune_column';
   $self->{samples} = 0;
   return $self;
}

sub push_val {
   my ($self, $sample, $func) = @_;
   my $id = $func->{'app'}.'-'.$func->{'func'};

   #Per func
   $self->{values}->{$id}->{'app'} = $func->{'app'};
   $self->{values}->{$id}->{'func'} = $func->{'func'};
   $self->{values}->{$id}->{'samples'} += $sample;

   #Total
   $self->{samples} += $sample;
}

sub find {
   my ($self, $item) = @_;
   return $self->{values}->{$item->{'app'}.'-'.$item->{'func'}};
}

1;
