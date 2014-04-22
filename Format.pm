#!/usr/bin/perl
package separator;
=head
A simple separator for format
=cut

sub new {
   my $self = {};
   bless $self;
   $self->{content} = $_[0];
   return $self;
}

package subtitle;
=head
A simple subtitle for format
=cut

sub new {
   my $self = {};
   bless $self;
   $self->{content} = $_[0];
   $self->{opt} = $_[1] // {};
   return $self;
}

package Format;
use strict;
use warnings;
use Switch;
use Carp;
use Data::Dumper;
use POSIX qw(ceil floor);
use Tie::IxHash;


=head
Format class: ultimate dumper.

Usage :
my $f = format::new;
   $f->add_values(%)             Add a line and create columns if they don't exist
                                 It is possible to specify the order of columns in they name : 0-name will be the first column and will be displayed as "name"
                                 E.g., $f->add_values({ 'title1' => 'test', 'title2' => 0.6 });

   $f->add_partial_values(%)     Same as add_values but doesn't fill previously unexisting columns with empty values
   $f->add_partial_values_on_last_line(%)     Same but does fill unexisting columns to only add stuff on the last line. 
                                              Difference with add_values is that add_values fills unknown values in the line with undefs.

   $f->set_format(%)             Specifies formating rules for the columns
                                 Possible values : 'left', 'right', 'center' or anything recognized by printf. Default is 'center'.
                                 E.g., $f->set_format({ 'title1' => '[%s]', 'title2' => 'right' });
   $f->set_default_format($)     ...

   $f->set_validator(%)          Specifies a validator for the columns (default none)

   $f->set_undef_char($)         Specifies what will be printed for undefined values

   $f->set_separation_char($)    Specifies the separator between titles and values. Default is '-' and displays:
                                 Title 1  Title2
                                 -------  ------
                                   val     val

   $f->add_separation_line($)    Add a separation line. It is possible to specify a character to print.

   $f->add_subtitle($)           Add a subtitle, crossing all lines. E.g:
                                 -------  ------
                                   val     val
                                 [Subtitle] ----
                                   val     val

   $f->sort_on($,&)              Sort the lines of the array.
                                 E.g., $f->sort_on('toto');
                                 E.g., $f->sort_on('toto', sub { $a->[1] cmp $b->[1] });

   $f->print;
=cut

sub new {
   my $self = {};
   bless $self;

   $self->{undef_char} = '-';
   $self->{separation_char} = '-';
   $self->{nb_lines} = 0;

   $self->{left_align_class} = 'left';
   $self->{center_align_class} = 'center';
   $self->{right_align_class} = 'right';
   $self->{default_format} = 'center';

   tie my %cols, "Tie::IxHash";
   $self->{cols} = \%cols;
   if( -t STDOUT ) {
      $self->{term_output} = 1;
   } else {
      $self->{term_output} = 0;
   }

   return $self;
}

sub set_format {
   my ($self, $obj) = @_;
   if (ref($obj) eq "HASH") {
      my $ordered_keys = get_values_from_user_input(keys %$obj);
      for my $v (@$ordered_keys) {
         my $k = $v->{final};
         if(!defined($self->{cols}->{$k}->{vals})) {
            $self->create_empty_col($v);
         }
         if(ref($obj->{$v->{initial}}) eq "CODE") {
            $self->{cols}->{$k}->{class} = $obj->{$v->{initial}};
         } else {
            switch($obj->{$v->{initial}}) {
               case 'left' {
                  $self->{cols}->{$k}->{class} = $self->{left_align_class};
               } case 'right' {
                  $self->{cols}->{$k}->{class} = $self->{right_align_class};
               } case 'center' {
                  $self->{cols}->{$k}->{class} = $self->{center_align_class};
               } else {
                  $self->{cols}->{$k}->{class} = $obj->{$v->{initial}};
               }
            }
         }
      }
   } else {
      confess "Don't know what to do with passed object of type ".ref($obj)." ";
   }
}

sub set_validator {
   my ($self, $obj) = @_;
    if (ref($obj) eq "HASH") {
      my $ordered_keys = get_values_from_user_input(keys %$obj);
      for my $v (@$ordered_keys) {
         my $k = $v->{final};
         if(!defined($self->{cols}->{$k}->{vals})) {
            $self->create_empty_col($v);
         }
         if(ref($obj->{$v->{initial}}) ne "CODE") {
            confess "A validator must be a function ";
         }
         $self->{cols}->{$k}->{validator} = $obj->{$v->{initial}};
      }
   } else {
      confess "Don't know what to do with passed object of type ".ref($obj)." ";
   }
}

#Parse user input to order the hashmap given in parameter.
#Format recognized: x-name where x is the display order.
sub get_values_from_user_input {
   my @vals = sort { 
      if($a =~ m/^(\d+)(\*?)-/) {
         my $val = $1;
         if($b =~ m/^(\d+)(\*?)-/) {
            return $val <=> $1;
         } else {
            return -1;
         }
      } else {
         return 1;
      }
   } @_;
   my $ret;
   my $i = 0;
   for my $val (@vals) {
      $ret->[$i]->{initial} = $val;
      $val =~ m/^(\d*)(\*?)-?((?:.|\n)*)$/;
      $ret->[$i]->{final} = $3;
      $ret->[$i]->{stared} = ($2 eq "*");
      $i++;
   }
   return $ret;
}

sub create_empty_col {
   my ($self, $obj, $nblines) = @_;
   for(my $i = 0; $i < ($nblines//$self->{nb_lines}); $i++) {
      push(@{$self->{cols}->{$obj->{final}}->{vals}}, undef);
   }
   $self->{cols}->{$obj->{final}}->{title_validator} = $obj->{stared}?(sub { return 1; }):undef;
}

sub fill_column {
   my ($self, $obj, $nblines) = @_;
   $self->create_empty_col($obj, $nblines-scalar(@{$self->{cols}->{$obj->{final}}->{vals}}));
}


sub add_values {
   my ($self, $obj) = @_;
   confess "What am I supposed to add? " if(!defined($obj));
   if (ref($obj) eq "HASH") {
      my $ordered_keys = get_values_from_user_input(keys %$obj);
      for my $v (@$ordered_keys) {
         my $k = $v->{final};
         if(!defined($self->{cols}->{$k}->{vals})) {
            $self->create_empty_col($v);
         } else {
            $self->fill_column($v, $self->{nb_lines});
         }
         push(@{$self->{cols}->{$k}->{vals}}, $obj->{$v->{initial}});
      }
      $self->{nb_lines}++;
   } else {
      confess "Don't know what to do with passed object of type ".ref($obj)." ";
   }
}

sub add_partial_values {
   my ($self, $obj) = @_;
   confess "What am I supposed to add? " if(!defined($obj));
   if (ref($obj) eq "HASH") {
      my $max = 0;
      my $ordered_keys = get_values_from_user_input(keys %$obj);
      for my $v (@$ordered_keys) {
         my $k = $v->{final};
         push(@{$self->{cols}->{$k}->{vals}}, $obj->{$v->{initial}});
         my $size = scalar @{$self->{cols}->{$k}->{vals}};
         $max = $size if($max < $size);
      }
      $self->{nb_lines} = $max if($max > $self->{nb_lines});
   } else {
      confess "Don't know what to do with passed object of type ".ref($obj)." ";
   }
}

sub add_partial_values_on_last_line {
   my ($self, $obj) = @_;
   confess "What am I supposed to add? " if(!defined($obj));
   if (ref($obj) eq "HASH") {
      my $max = 0;
      my $ordered_keys = get_values_from_user_input(keys %$obj);
      for my $v (@$ordered_keys) {
         my $k = $v->{final};
         if(!defined($self->{cols}->{$k}->{vals})) {
            $self->create_empty_col($v, $self->{nb_lines}-1);
         } else {
            $self->fill_column($v, $self->{nb_lines}-1);
         }
         push(@{$self->{cols}->{$k}->{vals}}, $obj->{$v->{initial}});
         my $size = scalar @{$self->{cols}->{$k}->{vals}};
         $max = $size if($max < $size);
      }
      $self->{nb_lines} = $max if($max > $self->{nb_lines});
   } else {
      confess "Don't know what to do with passed object of type ".ref($obj)." ";
   }
}

sub sort_on {
   my ($self, $obj, $sort) = @_;
   $sort //= sub { $a->[1] <=> $b->[1] };

   my $key = get_values_from_user_input(($obj));
   my $k = $key->[0]->{final};
   if(!defined($self->{cols}->{$k}->{vals})) {
      confess "Column $obj does not exists\n";
   } else {
      my @vals;
      for (my $i = 0; $i < scalar(@{$self->{cols}->{$k}->{vals}}); $i++) {
         push(@vals, [$i, $self->{cols}->{$k}->{vals}->[$i]]);
      }

      tie my %cols, "Tie::IxHash";
      my @svals = sort $sort @vals;
      for my $val (@svals) {
         for my $col (keys %{$self->{cols}}) {
            push(@{$cols{$col}->{vals}}, $self->{cols}->{$col}->{vals}->[$val->[0]]);
         }
      }
      $self->{cols} = \%cols;
   }
}

sub add_separation_line {
   my ($self, $separator) = @_;
   push(@{$self->{special_vals}->[$self->{nb_lines}]}, separator::new($separator));
}

sub add_subtitle {
   my ($self, $title, $opt) = @_;
   if(!defined($title)) {
      $self->add_separation_line;
   } else {
      push(@{$self->{special_vals}->[$self->{nb_lines}]}, subtitle::new($title, $opt));
   }
}


sub set_undef_char {
   my ($self, $obj) = @_;
   $self->{undef_char} = $obj;
}

sub set_separation_char {
   my ($self, $obj) = @_;
   $self->{separation_char} = $obj;
}

sub set_default_format {
   my ($self, $obj) = @_;
   $self->{default_format} = $obj;
}
   

#Return the variable formated according to the user format
sub get_formated_var {
   my ($self, $var, $format) = @_;
   $format //= $self->{default_format};

   return $self->{undef_char} if(!defined($var));
   my $str;
   if(ref($var) eq "separator" || ref($var) eq "subtitle") {
      return $var->{content} // "";
   } elsif(ref($format) eq "CODE") {
      $str = $format->($var);
   } else {
      switch($format) {
         case 'left' {
            $str = $var;
         } case 'right' {
            $str = $var;
         } case 'center' {
            $str = $var;
         } else {
            $str = sprintf($format, $var);
         }
      }
   }
   $str =~ s/\t/    /g;
   return $str;
}

#Given a user input and its format, return the width of the variable
#Multine aware.
sub print_var_len {
   my ($self, $val, $format) = @_;

   if(ref($val) eq "separator") {
      return 0;
   }
   if(ref($val) eq "subtitle") {
      return 0;
   }

   return $val->total_len if(ref($val) eq "Format");

   my @values = split(/\n/, $self->get_formated_var($val, $format));
   my $max = 0;
   for my $v (@values) {
      my $l = length($v);
      $max = $l if($l > $max);
   }
   return $max;
}

#Given a user input and its format, return the height of the variable
sub print_var_height {
   my ($self, $val, $format) = @_;
   if(!defined($val)) {
      return 1;
   } elsif(ref($val) eq "separator") {
      return 1;
   } elsif(ref($val) eq "subtitle") {
      return 1;
   } elsif(ref($val) eq "Format") {
      return $val->total_height;
   } else {
      my @values = split(/\n/, $self->get_formated_var($val, $format));
      #print scalar(@values).Dumper(@values)."\n";
      return scalar @values;
   }
}

#Print one subline of a variable (ie. if the variable is 10 lines 'tall', print the correct value if $line < 10
#and a blank line of $max_len otherwise).
sub print_var {
   my ($self, $val, $format, $max_len, $line, $validator) = @_;
   $format //= $self->{default_format};
  
   my $isvalid = undef;
   if(defined($validator) && $self->{term_output}) {
      $isvalid = $validator->($val);
   }

   if(!defined($val)) {
      $val = $self->{undef_char};
      $format = 'center';
   }

   if(ref($val) eq "separator") {
      $val = ($val->{content}//$self->{separation_char})x$max_len;
      $format = $self->{default_format};
   }

   if(ref($val) eq "Format") {
      $val->{term_output} = $self->{term_output};
      $val = $val->print_line($line);
      $line = 0;
   }

   my $str = $self->get_formated_var($val, $format);
   unless($format eq 'left' || $format eq 'right' || $format eq 'center') {
      $format = $self->{default_format};
   }

   my @values = split(/\n/, $str);
   my $ret;
   if($line > $#values) {
      $ret = sprintf "%s", (" "x($max_len+2));
   } else {
      my $line_without_special_char = $values[$line];
      $line_without_special_char =~ s/\033\[[\d;]+m//g;
      my $l = $max_len - length($line_without_special_char);
      switch($format) {
         case 'left' {
            $ret = sprintf "%*s%s%*s",
               1, "",
               $values[$line],
               $l+1, "";
         } case 'center' {
            $ret = sprintf "%*s%s%*s",
               floor($l/2)+1, "",
               $values[$line],
               ceil($l/2)+1, "";
         } case 'right' {
            $ret = sprintf "%*s%s%*s",
               $l+1, "",
               $values[$line],
               1, "";
         } 
      }
   }
   if(defined($isvalid) && $isvalid) {
      $ret = "\033[32m".$ret."\033[00m";
   } elsif(defined($isvalid)) {
      $ret = "\033[31m".$ret."\033[00m";
   }
   return $ret;
}

sub print_html {
   my ($self) = @_;
   $self->{term_output} = 1;
   my $total_len = $self->total_len;
   my $total_height = $self->total_height;
   my $i = 0;
   print "<html><body STYLE=\"font-family: \'Monospace\'\">";
   for(;;) {
     my $line = $self->print_line($i++);
     last if $line eq "";
     $line =~ s/ /&nbsp;/g;
     $line =~ s/\033\[31m/<font color=\'red\'>/g;
     $line =~ s/\033\[1;30m/<font color=\'gray\'>/g;
     $line =~ s/\033\[32m/<font color=\'green\'>/g;
     $line =~ s/\033\[00m/<\/font>/g;
     print $line;
     print "<br>";
     print "\n";
   }
   print "</body></html>";
}

sub print {
   my ($self, $color) = @_;
   $self->{term_output} = 1 if (defined($color)); #possibility to force color output
   my $total_len = $self->total_len;
   my $total_height = $self->total_height;
   my $i = 0;
   for(;;) {
     my $line = $self->print_line($i++);
     last if $line eq "";
     print $line;
     print "\n";
   }
}


#Total width and total height. Used for recursive printing to know the size of a format and by a format to
#know the max width of its content.
sub total_len {
   my ($self) = @_;
   my $total = 0;
   for my $col (keys %{$self->{cols}}) {
      $self->{cols}->{$col}->{max_length} = $self->print_var_len($col, 'center');
      for my $val (@{$self->{cols}->{$col}->{vals}}) {
         my $l = $self->print_var_len($val, $self->{cols}->{$col}->{class});
         $self->{cols}->{$col}->{max_length} = $l if($self->{cols}->{$col}->{max_length} < $l);
      }
      $total += $self->{cols}->{$col}->{max_length} + 2;
   }
   $self->{total_len} = $total - 2;
   return $self->{total_len};
}

sub total_height {
   my ($self) = @_;
   my $total = 0;
   $total++ if(defined($self->{separation_char}));

   my $max = 0;
   for my $col (keys %{$self->{cols}}) {
      my $h = $self->print_var_height($col, 'center');
      $max = $h if($h > $max);
   }
   $self->{title_height} = $max;
   $total += $max;

   for (my $i = 0; $i < $self->{nb_lines}; $i++) {
      $max = 0;
      for my $col (keys %{$self->{cols}}) {
         my $h = $self->print_var_height($self->{cols}->{$col}->{vals}->[$i], $self->{cols}->{$col}->{class});
         $max = $h if($h > $max);
      }
      $self->{lines_height}->[$i] = $max;
      $total += $max;
   }

   for (my $i = 0; $i < $self->{nb_lines}; $i++) {
      next if(!defined $self->{special_vals}->[$i]);
      for my $sep (@{$self->{special_vals}->[$i]}) {
         $total += $self->print_var_height($sep);
      }
   }
   return $total;
}

#Printing a subline of a scalar is easy. Printing a subline of a format is not => special function to do that.
sub print_line {
   my ($self, $line) = @_;
   my $str = "";
   if($line < $self->{title_height}) {
      for my $col (keys %{$self->{cols}}) {
         my $class = $self->{cols}->{$col}->{class};
         $class = $self->{center_align_class} if(!defined($class) || ($class ne $self->{left_align_class} && $class ne $self->{right_align_class}));
         $str.= $self->print_var($col, $class, $self->{cols}->{$col}->{max_length}, $line, $self->{cols}->{$col}->{title_validator});
      }
   } elsif($line == $self->{title_height} && defined($self->{separation_char})) {
      for my $col (keys %{$self->{cols}}) {
         #$str.= $self->print_var($self->{separation_char}x($self->{cols}->{$col}->{max_length}), 'right', $self->{cols}->{$col}->{max_length}, 0);
         $str.= $self->print_var($self->{separation_char}x($self->{cols}->{$col}->{max_length}), 'right', $self->{cols}->{$col}->{max_length}, 0);
      }
   } else {
      $line -= $self->{title_height};
      $line -- if(defined($self->{separation_char}));

      return "" if !defined $self->{lines_height};

      my ($i, $seen_separators, $print_separator) = (0,0,0);
      while(1) {
         while(defined($self->{special_vals}->[$i]) && ($seen_separators < scalar(@{$self->{special_vals}->[$i]}))) {
            if($line == 0) {
               $print_separator = 1;
               last;
            }
            $line--;
            $seen_separators++;
         }
         last if($line == 0);
         last if($line < $self->{lines_height}->[$i]);
         $seen_separators = 0;

         $line -= $self->{lines_height}->[$i];
         $i++;
         return "" if($i >= $self->{nb_lines});
      }
      
      if($print_separator) {
         my $sep = $self->{special_vals}->[$i]->[$seen_separators];
         if(ref($sep) eq "subtitle") {
            my $separator = $sep->{opt}->{full_line}?"-":" ";
            if(!$sep->{opt}->{align} || $sep->{opt}->{align} eq 'left') {
               $str.= ' '.$sep->{content}.$separator;
               my $actual_len = length($str);
               my $total_len = 0;
               my $nb_col = scalar (keys %{$self->{cols}});
               my $num = 0;
               for my $col (keys %{$self->{cols}}) {
                  $num++;
                  $actual_len -= ($self->{cols}->{$col}->{max_length} + 2);
                  if($actual_len < 0) {
                     $str.= ('-'x(-$actual_len-2));
                     $str.= $separator.$separator if($num != $nb_col);
                     $actual_len = 0;
                  }
               }
               $str =~ s/\s+$//;
               if($self->{term_output}) {
                  $str = "\033[1;30m".$str."\033[00m";
               }
            } elsif ($sep->{opt}->{align} eq 'center') {
               my $content = " ".$sep->{content}." ";
               my $l = $self->{total_len} - length($content);
               $str .= sprintf "%s%s%s", $separator x(floor($l/2)), 
                  $content,
                  $separator x(ceil($l/2));
            } else {
               confess "Not done";
            }
         } elsif(ref($sep) eq "separator") {
            my $char = $sep->{content} // $self->{separation_char};
            for my $col (keys %{$self->{cols}}) {
               $str.= " ".(($char)x($self->{cols}->{$col}->{max_length}))." ";
            }
         }
      } else {
         for my $col (keys %{$self->{cols}}) {
            $str.= $self->print_var($self->{cols}->{$col}->{vals}->[$i], $self->{cols}->{$col}->{class},  $self->{cols}->{$col}->{max_length}, $line, $self->{cols}->{$col}->{validator});
         }
      }
   }
   
   if(defined $self->{debug}) {
      print "($str)\n";
   }
   return $str;
}

1;

