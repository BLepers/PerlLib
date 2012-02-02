use strict;
use warnings;
use Data::Dumper;
use Switch;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;
use Graphics::GnuplotIF qw(GnuplotIF);

package File::MiniProf::Results::Plot;
sub get_plot {
   my ($info, $parse_options, $opt, $title) = @_;
   my $plot = Graphics::GnuplotIF->new(persist=>1);
   #$plot->gnuplot_set_title( $title );
   $plot->gnuplot_set_xlabel("time (s)");
   $plot->gnuplot_set_ylabel($title);
   
   $plot->gnuplot_set_style( "lines lt 1 lw 1" );      
   $plot->gnuplot_set_yrange( @{$parse_options->{$info->{name}}->{gnuplot_range}} ) if ($parse_options->{$info->{name}}->{gnuplot_range});

   if($opt->{gnuplot_file}) {
      if($opt->{gnuplot_file} =~ m/png/) {
         $plot->gnuplot_hardcopy( $title.'.'.$opt->{gnuplot_file}, 'png' );
      } elsif($opt->{gnuplot_file} =~ m/pdf/) {
      } else {
         die "Unknown file extension for gnuplot output (file $opt->{gnuplot_file})";
      }
   }
   return $plot;
}

1;
