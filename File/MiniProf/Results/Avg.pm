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
use List::Util qw(sum);

sub sum_all_per_core {
   my ($self, $info, $parse_options, $opt) = @_;

   my $nb_events = scalar(keys $info->{usable_events});

   my  $plot;
   my @gnuplot_xy;
   if($opt->{gnuplot}) {
      $plot = File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name});
   }

   my @event = map { $self->_scripted_value_to_event($_, $info) } (0..($nb_events - 1));
   my $glob_sum = 0;

   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my $core_sum = 0;
      for(my $i = 0; $i < $nb_events; $i++) {
         my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event[$i]);
         $glob_sum += $sum;
         $core_sum += $sum;
      }
      
      $info->{results}->{$core} = $core_sum;

      if($opt->{gnuplot}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            my @vals = ();
            for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$event[0]}->{val}}); $i++) {
               my $_sum = 0;
               for(my $j = 0; $j < $nb_events; $j++) {
                  my $val = $self->{miniprof}->{raw}->{$core}->{$event[$j]}->{val}->[$i];
                  $_sum += $val;
               }
               push(@vals, $_sum);
            }
            push(@gnuplot_xy, $self->{miniprof}->{raw}->{$core}->{$event[0]}->{time}); #x
            push(@gnuplot_xy, \@vals); #y
         }
      }
   }

   $info->{results}->{ALL} = $glob_sum;

   if($opt->{gnuplot}) {      
      $plot->gnuplot_set_plot_titles(map("Core $_", sort {$a <=> $b} keys(%{$self->{miniprof}->{raw}})));
      $plot->gnuplot_plot_many( @gnuplot_xy );
   }
}

sub sum_odd_div_sum_even_per_core {
   my ($self, $info, $parse_options, $opt) = @_;

   my $nb_events = scalar(keys $info->{usable_events});
   if($nb_events % 2 != 0) {
      die("Odd number of events $nb_events\n");
      print main::Dumper($info->{usable_events});
   }

   my  $plot;
   my @gnuplot_xy;
   if($opt->{gnuplot}) {
      $plot = File::MiniProf::Results::Plot::get_plot($info, $parse_options, $opt, $parse_options->{$info->{name}}->{name});
   }

   my @event = map { $self->_scripted_value_to_event($_, $info) } (0..($nb_events - 1));
   my ($glob_sum_even, $glob_sum_odd) = (0, 0);

   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my ($odd_sum, $even_sum) = (0, 0);
      for(my $i = 0; $i < $nb_events; $i++) {
         my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $event[$i]);
         if($i % 2 == 0) {
            $glob_sum_even += $sum;
            $even_sum += $sum;
         } else {
            $glob_sum_odd += $sum;
            $odd_sum += $sum;
         }
      }
      
      if($even_sum != 0) {
         $info->{results}->{$core} = $odd_sum / $even_sum;
      }

      if($opt->{gnuplot}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            my @vals = ();
            for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$event[0]}->{val}}); $i++) {
               my ($vodd_sum, $veven_sum) = (0, 0);
               for(my $j = 0; $j < $nb_events; $j++) {
                  my $val = $self->{miniprof}->{raw}->{$core}->{$event[$j]}->{val}->[$i];
                  if($j % 2 == 0) {
                     $veven_sum += $val;
                  } else {
                     $vodd_sum += $val;
                  }
               }
               my $avg = ($veven_sum)?($vodd_sum/$veven_sum):0;
               push(@vals, $avg);
            }
            push(@gnuplot_xy, $self->{miniprof}->{raw}->{$core}->{$event[0]}->{time}); #x
            push(@gnuplot_xy, \@vals); #y
         }
      }
   }

   if($glob_sum_even){
      $info->{results}->{ALL} = ($glob_sum_odd) / ($glob_sum_even);
   }
   else {
      $info->{results}->{ALL} = "No samples";
   }

   if($opt->{gnuplot}) {      
      $plot->gnuplot_set_plot_titles(map("Core $_", sort {$a <=> $b} keys(%{$self->{miniprof}->{raw}})));
      $plot->gnuplot_plot_many( @gnuplot_xy );
   }
}


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
               my $val_2 = $self->{miniprof}->{raw}->{$core}->{$event_2}->{val}->[$i];
               my $avg = ($val_2)?(($val_0+$val_1)/($val_2)):0;
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

   my $nb_events = $self->_nb_events($info) - 1;
   my @events;
   my @global_sum;
   for my $i (0..$nb_events) {
      $events[$i] = $self->_scripted_value_to_event($i, $info);
   }


   for my $core (sort {$a <=> $b} keys %{$self->{miniprof}->{raw}}) {
      my @current_glob_sum;
      for my $i (0..$nb_events) {
         my ($avg, $sum, $count) = File::MiniProf::_miniprof_get_average_and_sum($self->{miniprof}->{raw}->{$core}, $events[$i] );
         $global_sum[$i] += $sum;
         $current_glob_sum[$i] = $sum;
      }

      if(sum(@current_glob_sum) != 0) {
         $info->{results}->{$core} = $current_glob_sum[0]/(sum(@current_glob_sum));
      }

      if($opt->{gnuplot}) {
         if(!defined($opt->{gnuplot_max_cpu}) || $core < $opt->{gnuplot_max_cpu}) {
            my @vals = ();
            for (my $i = 0; $i < scalar (@{$self->{miniprof}->{raw}->{$core}->{$events[0]}->{val}}); $i++) {
               my @vals;
               for my $j (0..$nb_events) {
                  $vals[$j] = $self->{miniprof}->{raw}->{$core}->{$events[$j]}->{val}->[$i];
               }
               my $avg = (sum(@vals))?($vals[0]/(sum(@vals))):0;
               push(@vals, $avg);
            }
            push(@gnuplot_xy, $self->{miniprof}->{raw}->{$core}->{$events[0]}->{time}); #x
            push(@gnuplot_xy, \@vals); #y
         }
      }
   }

   if(sum(@global_sum)){
      $info->{results}->{ALL} = $global_sum[0] / (sum(@global_sum));
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
