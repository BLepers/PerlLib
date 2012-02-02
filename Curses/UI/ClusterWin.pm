package Curses::UI::ClusterWin;
use strict;
use warnings;
use Data::Dumper;
use Curses;
use Curses::UI::Window;  

use vars qw($VERSION @ISA);
$VERSION = '0.01';
@ISA = qw(Curses::UI::Window);

sub new () {
   my $class = shift;
   my %args = (
      @_,
   );

   my $this = $class->SUPER::new( %args );
   return $this;
}

sub layout () {
   my $this = shift;
   $this->SUPER::layout;
   return $this;
}

sub draw(;$) {
   my $this = shift;
   my $no_doupdate = shift || 0;
   $this->SUPER::draw($no_doupdate);
   if($Curses::UI::screen_too_small) {
      $this->clear_editors;
      $Curses::UI::screen_too_small = 0;
      $this->SUPER::draw($no_doupdate);
   }
   return $this;
}

sub nb_editors {
   my $this = shift;
   return (defined $this->{shown_processes})?(scalar(@${$this->{shown_processes}})):(0);
}

sub clear_editors {
   my $this = shift;
   for my $p (@${$this->{shown_processes}}) {
      my $text_edit = $this->getobj('te'.$p);
      if(defined $text_edit) {
         $this->{saved_texts}->{$p} = $text_edit->text;
         $this->delete('te'.$p);
      }
   }
   $this->{shown_processes} = undef;
}

sub add_editor {
   my $this = shift;
   my $p = shift;
   my $total = shift;
   push(@${$this->{shown_processes}}, $p);
   my $i = scalar(@${$this->{shown_processes}}) -1;
   $this->add(
      'te'.$p, 'TextEditor',
      -title => $p,
      -border => 1,
      -titlereverse => 0,
      -vscrollbar => 1,
      -hscrollbar => 1,
      -wrapping => 1,
      -readonly => 1,
      -width => $this->canvaswidth/$total - 2,
      -x => $this->canvaswidth/$total*$i,
      -text => $this->{saved_texts}->{$p},
   );
}
