#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Switch;
use File::Utils;
use Graphics::GnuplotIF qw(GnuplotIF);
use File::MiniProf::Results::Plot;

package File::MiniProf::Results::Avg;
use File::MiniProf;

sub sum_0_sum_1_div_sum_2_per_core {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;
   my @gnuplot_xy;
   if($opt->{gnuplot}) {
      $plot = File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name});
   }

   my $event_0 = $self->_scripted_value_to_event(0, $info);
   my $event_1 = $self->_scripted_value_to_event(1, $info);
   my $event_2 = $self->_scripted_value_to_event(2, $info);

   my $glob_sum_0 = 0;
   my $glob_sum_1 = 0;
   my $glob_sum_2 = 0;

   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my ($avg0, $sum0, $count0) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_0 );
      my ($avg1, $sum1, $count1) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_1 );
      my ($avg2, $sum2, $count2) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_2 );

      $glob_sum_0 += $sum0; 
      $glob_sum_1 += $sum1; 
      $glob_sum_2 += $sum2; 

      if($sum2 != 0) {
         $info->{results}->{$core} = ($sum0+$sum1)/($sum2);
      }

      if($opt->{gnuplot}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            my @vals = ();
            for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$event_0}->{val}}); $i++) {
               my $val_0 = $self->{miniprof}->{raw}->{$core}->{$event_0}->{val}->[$i];
               my $val_1 = $self->{miniprof}->{raw}->{$core}->{$event_1}->{val}->[$i];
               my $avg = ($val_1)?($val_0/($val_0+$val_1)):0;
               push(@vals, $avg);
            }
            push(@gnuplot_xy, $self->{miniprof}->{raw}->{$core}->{$event_0}->{time}); #x
            push(@gnuplot_xy, \@vals); #y
         }
      }
   }

   if($glob_sum_2){
      $info->{results}->{ALL} = ($glob_sum_0 + $glob_sum_1) / ($glob_sum_2);
   }
   else {
      $info->{results}->{ALL} = "No samples";
   }

   if($opt->{gnuplot}) {      
      $plot->gnuplot_set_plot_titles(map("Core $_", sort {$a <=> $b} keys(%{$self->{miniprof}->{raw}})));
      $plot->gnuplot_plot_many( @gnuplot_xy );
   }
}


sub sum_0_div_sum_all_per_core {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;
   my @gnuplot_xy;
   if($opt->{gnuplot}) {
      $plot = File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name});
   }

   my $event_0 = $self->_scripted_value_to_event(0, $info);
   my $event_1 = $self->_scripted_value_to_event(1, $info);

   my $glob_sum_0 = 0;
   my $glob_sum_1 = 0;

   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my ($avg0, $sum0, $count0) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_0 );
      my ($avg1, $sum1, $count1) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_1 );

      $glob_sum_0 += $sum0; 
      $glob_sum_1 += $sum1; 

      if($sum0 + $sum1 != 0) {
         $info->{results}->{$core} = $sum0/($sum0+$sum1);
      }

      if($opt->{gnuplot}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            my @vals = ();
            for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$event_0}->{val}}); $i++) {
               my $val_0 = $self->{miniprof}->{raw}->{$core}->{$event_0}->{val}->[$i];
               my $val_1 = $self->{miniprof}->{raw}->{$core}->{$event_1}->{val}->[$i];
               my $avg = ($val_1)?($val_0/($val_0+$val_1)):0;
               push(@vals, $avg);
            }
            push(@gnuplot_xy, $self->{miniprof}->{raw}->{$core}->{$event_0}->{time}); #x
            push(@gnuplot_xy, \@vals); #y
         }
      }
   }

   if($glob_sum_0){
      $info->{results}->{ALL} = $glob_sum_0 / ($glob_sum_0 + $glob_sum_1);
   }
   else {
      $info->{results}->{ALL} = "No samples";
   }

   if($opt->{gnuplot}) {      
      $plot->gnuplot_set_plot_titles(map("Core $_", sort {$a <=> $b} keys(%{$self->{miniprof}->{raw}})));
      $plot->gnuplot_plot_many( @gnuplot_xy );
   }
}

sub sum_1_div_sum_0_per_core {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;
   my @gnuplot_xy;

   if($opt->{gnuplot}) {
      $plot = File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name});
   }

   my $event_0 = $self->_scripted_value_to_event(0, $info);
   my $event_1 = $self->_scripted_value_to_event(1, $info);

   my $glob_sum_0 = 0;
   my $glob_sum_1 = 0;

   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my ($avg0, $sum0, $count0) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_0 );
      my ($avg1, $sum1, $count1) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_1 );

      $glob_sum_0 += $sum0; 
      $glob_sum_1 += $sum1; 

      if($avg0 != 0) {
         $info->{results}->{$core} = $sum1/$sum0;
      }

      if($opt->{gnuplot}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            my @vals = ();
            for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$event_0}->{val}}); $i++) {
               my $val_0 = $self->{miniprof}->{raw}->{$core}->{$event_0}->{val}->[$i];
               my $val_1 = $self->{miniprof}->{raw}->{$core}->{$event_1}->{val}->[$i];
               my $avg = ($val_1 && $val_0)?($val_1/$val_0):0;
               push(@vals, $avg);
            }
            push(@gnuplot_xy, $self->{miniprof}->{raw}->{$core}->{$event_0}->{time}); #x
            push(@gnuplot_xy, \@vals); #y
         }
      }
   }

   if($glob_sum_0){
      $info->{results}->{ALL} = $glob_sum_1 / $glob_sum_0;
   }
   else {
      $info->{results}->{ALL} = "No samples";
   }

   if($opt->{gnuplot}) {      
      $plot->gnuplot_set_plot_titles(map("Core $_", sort {$a <=> $b} keys(%{$self->{miniprof}->{raw}})));
      $plot->gnuplot_plot_many( @gnuplot_xy );
   }
}

sub sum_1_sum_2_div_sum_0_per_core {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;
   my @gnuplot_xy;
   if($opt->{gnuplot}) {
      $plot = File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name});
   }

   my $event_0 = $self->_scripted_value_to_event(0, $info);
   my $event_1 = $self->_scripted_value_to_event(1, $info);
   my $event_2 = $self->_scripted_value_to_event(2, $info);

   my $glob_sum_0 = 0;
   my $glob_sum_1 = 0;
   my $glob_sum_2 = 0;

   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my ($avg0, $sum0, $count0) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_0 );
      my ($avg1, $sum1, $count1) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_1 );
      my ($avg2, $sum2, $count2) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_2 );

      $glob_sum_0 += $sum0; 
      $glob_sum_1 += $sum1;
      $glob_sum_2 += $sum2;

      if($avg0 != 0) {
         $info->{results}->{$core} = ($sum1-$sum2)/$sum0;
      }

      if($opt->{gnuplot}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            my @vals = ();
            for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$event_0}->{val}}); $i++) {
               my $val_0 = $self->{miniprof}->{raw}->{$core}->{$event_0}->{val}->[$i];
               my $val_1 = $self->{miniprof}->{raw}->{$core}->{$event_1}->{val}->[$i];
               my $val_2 = $self->{miniprof}->{raw}->{$core}->{$event_2}->{val}->[$i];
               
               my $avg = ($val_1 && $val_0)?(($val_1-$val_2)/$val_0):0;
               push(@vals, $avg);
            }
            push(@gnuplot_xy, $self->{miniprof}->{raw}->{$core}->{$event_0}->{time}); #x
            push(@gnuplot_xy, \@vals); #y
         }
      }
   }

   if($glob_sum_0){
      $info->{results}->{ALL} = ($glob_sum_1-$glob_sum_2) / $glob_sum_0;
   }
   else {
      $info->{results}->{ALL} = "No samples";
   }

   if($opt->{gnuplot}) {      
      $plot->gnuplot_set_plot_titles(map("Core $_", sort {$a <=> $b} keys(%{$self->{miniprof}->{raw}})));
      $plot->gnuplot_plot_many( @gnuplot_xy );
   }
}

sub sum_1_div_sum_0_global {
   my ($self, $info, $parse_options, $opt) = @_;
   my  $plot;
   my @gnuplot_xy;
   if($opt->{gnuplot}) {
      $plot = File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name});
   }

   my $event_0 = $self->_scripted_value_to_event(0, $info);
   my $event_1 = $self->_scripted_value_to_event(1, $info);


   my $sum_evt0;
   my $sum_evt1;
   
   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my ($avg0, $sum0, $count0) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_0 );
      my ($avg1, $sum1, $count1) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event_1 );

      $sum_evt0 += $sum0;
      $sum_evt1 += $sum1;
   }
   
   if(!defined $sum_evt0 || !defined $sum_evt1) {
      printf "Nothing to analyse...\n";
      return undef;
   }
   
   $info->{results}->{ALL} = $sum_evt1 / $sum_evt0;

   if($opt->{gnuplot}) {
      if(!defined($opt->{gnuplot_max_cpu}))  {
         my @vals = ();
         for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{0}->{$event_0}->{val}}); $i++) {
            my $gnu_sum_evt0 = 0;
            my $gnu_sum_evt1 = 0;
            for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
               my $val_0 = $self->{miniprof}->{raw}->{$core}->{$event_0}->{val}->[$i];
               my $val_1 = $self->{miniprof}->{raw}->{$core}->{$event_1}->{val}->[$i];
               $gnu_sum_evt0 += $val_0 if(defined $val_0);
               $gnu_sum_evt1 += $val_1 if(defined $val_1);
            }
            push(@vals, $gnu_sum_evt0?$gnu_sum_evt1/$gnu_sum_evt0:0);
         }
         push(@gnuplot_xy, $self->{miniprof}->{raw}->{0}->{$event_0}->{time}); #x
         push(@gnuplot_xy, \@vals); #y
      }
   }

   if($opt->{gnuplot}) {   
      $plot->gnuplot_set_plot_titles(map("Global", sort {$a <=> $b} keys(%{$self->{miniprof}->{raw}})));
      $plot->gnuplot_plot_many( @gnuplot_xy );
   }
}

1;
