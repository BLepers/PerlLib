#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use threads;
use threads::shared;

package ClusterWrapper;
use Curses;
use Curses::UI;
use Curses::UI::ClusterWin;
use IO::Select;
use constant {
   MAX_NODES => 100,
   MAIN_PROCESS => "MAIN PROCESS",
   DISPLAY_MAIN => 1,
};

$ENV{PERL_SIGNALS} = "unsafe"; #Live dangerously

our $validator = sub { return $_[0] !~ /(Error|FAILED|Timeout|not responding|broken|Broken)/; };
my ($cui, $cui_thr, %pipes, %textboxes, $last_nb_processes, $last_sizes, %saved_texts, %process_files, %pipe_to_process);
my %process_to_pipe : shared = ();
my @processes : shared = ();
my @shown_processes : shared = ();

#Initialize parent -> son pipes
sub init_pipes {
   for (my $i = 0; $i < MAX_NODES; $i++) {
      pipe($pipes{$i}->{FROM_CHILD}, $pipes{$i}->{TO_PARENT});
      $pipes{$i}->{FROM_CHILD}->autoflush(1);
      $pipes{$i}->{TO_PARENT}->autoflush(1);
   }
   push(@shown_processes, 'ALL');
   open(STDERR, "> wrapper.log");
   #Even the main process has a view.
   bind_pipe(MAIN_PROCESS, DISPLAY_MAIN);
}
sub bind_pipe {
   my ($process, $display) = @_;
   lock(@processes);
   my $pipe_num = $process_to_pipe{$process};
   if(!defined $pipe_num) {
      my $last_pipe = scalar keys %process_to_pipe;
      $pipe_num = $process_to_pipe{$process} = $last_pipe;
      push(@processes, $process);
   }
   display_add_process($process) if $display;
   select($pipes{$pipe_num}->{TO_PARENT});
   select->autoflush(1);
}
sub display_add_process {
   my ($process) = @_;
   lock(@processes);
   for my $p (@shown_processes) {
      return if $p eq $process;
   }
   push(@shown_processes, $process);
}
sub display_remove_process {
   my ($process) = @_;
   lock(@processes);
   my @new_a;
   for my $p (@shown_processes) {
      push(@new_a, $p) if($p ne $process);
   }
   @shown_processes = @new_a;
}

sub write_log {
   my ($pipe, $line) = @_;
   my $file = $process_files{$pipe_to_process{$pipe}};
   if(!$file) {
      open($file, ">/tmp/".$pipe_to_process{$pipe}.".log") or return;
      $file->autoflush(1);
      $process_files{$pipe_to_process{$pipe}} = $file;
   }
   print $file $line;
}

sub check_views {
   lock(@processes);
   $last_nb_processes //= 0;
   $last_sizes //= [ 0, 0 ];
   my $changed = 0;
   my $w = $cui->getobj('w0');

   if((scalar(@shown_processes) != $w->nb_editors) ||
      ($last_sizes->[0] != $w->canvaswidth) ||
      ($last_sizes->[1] != $w->canvasheight)) {
      $last_nb_processes = scalar(@shown_processes);
      $last_sizes->[0] = $w->canvaswidth;
      $last_sizes->[1] = $w->canvasheight;
      $changed = 1;

      $w->clear_editors;
      for my $p (@shown_processes) {
         $w->add_editor($p, $last_nb_processes);
      }
      $w->layout;
      $w->draw;
   }

   my %present;
   for my $p (@shown_processes) {
      next if $p eq 'ALL';
      $present{$p} = 1;
      $pipe_to_process{ $pipes{$process_to_pipe{$p}}->{FROM_CHILD} } = $p;
      update_textbox('te'.$p, [$process_to_pipe{$p}], $changed);
   }
   
   my @absent;
   for my $p (@processes) {
      next if $present{$p};
      $pipe_to_process{ $pipes{$process_to_pipe{$p}}->{FROM_CHILD} } = $p;
      push(@absent, $process_to_pipe{$p});
   }
   update_textbox('teALL', \@absent, $changed);
}

sub validate_line {
   return $validator->($_[0]);
}

#View: update the current textarea.
sub update_textbox {
   my ($name, $pipe, $changed) = @_;
   my $text_area = $cui->getobj('w0')->getobj($name);
   my ($max, $need_scrolldown);

   my $s = IO::Select->new();
   for my $p (@$pipe) {
      my $handle = $pipes{$p}->{FROM_CHILD};
      $s->add($handle);
   }

   $max = @{$text_area->{-scr_lines}} - $text_area->canvasheight;
   $need_scrolldown = $max == $text_area->{-yscrpos};
   $need_scrolldown = 1;

   for my $p (@$pipe) {
      my $handle = $pipes{$p}->{FROM_CHILD};
      my $rin = '';
      vec($rin,fileno($handle),1) = 1;
      my ($nfound,$timeleft) = select($rin, undef, undef, 0);
      if($nfound > 0) {
         $changed = 1;
         my $line = '';
         sysread($handle, $line, 10000);
         $text_area->text($text_area->text().$line);
         if(!validate_line($line)) {
            $text_area->{-bfg} = "red";
            $text_area->{-tfg} = "red";
            $text_area->{-sfg} = "red";
         }
         write_log($handle, $line);
      }
   }

   if($changed) {
      if($need_scrolldown || $max <= 0) {
         $max = @{$text_area->{-scr_lines}} - $text_area->canvasheight;
         if($max >= 0) {
            $text_area->{-yscrpos} = $max;
            $text_area->{-ypos} = $text_area->{-yscrpos};
         }
      }  
   }
   $text_area->draw;
}

#View: init.
sub create_cui {
   bind_pipe(MAIN_PROCESS);
   $SIG{'KILL'} = sub { threads->exit(); }; 	#So that we can exit properly
   $cui = new Curses::UI (-color_support => 1, -clear_on_exit => 1);
   $cui->set_binding(sub { 
         endwin;
         print "cC received... forwarding signal...\n";
         kill 2, $$;
      }, "\cC");

   my $w0 = $cui->add(
      'w0', 'ClusterWin',
   );
   $cui->set_timer(
      'output_timer',
      \&check_views, 0.5
   );
   $cui->enable_timer('output_timer');
      
   $cui->mainloop;
}
sub create_view {
	$cui_thr = threads->create(sub { create_cui; });
}
sub destroy_view {
   if(defined $cui_thr) {
      $cui_thr->kill('KILL')->detach(); #To make sure that curses is not updating anything after endwin
      endwin;
   }
}

my $pid = fork();
if (not defined $pid) {
   print "resources not available.\n";
} elsif ($pid == 0) {
   #Child
} else {
      waitpid($pid,0);
      system "reset";
      system "cat ./wrapper.log";
      exit(0);
}

#$SIG{INT} = sub {
#   print "Exit !\n";
#   exit(0);
#};

init_pipes;
create_view;
END {
   destroy_view;
}
1;
