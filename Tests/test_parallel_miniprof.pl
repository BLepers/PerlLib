#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../PerlLib";
use Format;
use File::Utils;
use File::Sar;
use Data::Dumper;
use threads;
use threads::shared;
$Data::Dumper::Maxdepth = 5;


=cut
Powerful miniprof parser.
Usage: ./test_parallel_miniprof.pl <files>

$file_to_basename:
   Transforms a file name into a "bench name".
   E.g., app.ipc => app
   Used to regroup all miniprof files of a common app into the same array.

%events:
   'DisplayOrder-Name of the Event *as it appears in Miniprof.pm*[-Optional precision in the name]' => sub { return what-you-want }

   * The optional precision can be used to print multiple information out of the same miniprof file (e.g., the local access ratio and the number of memory access can be deduced from the same file).
   * The function will be called with 1 argument: the 'results' field of the 'avail_info' you requested. See test_miniprof.pl on a file to dump the parsed content of a Miniprof file.

=cut

my $quiet = 0;
my $nb_cores = `grep "^processor"  /proc/cpuinfo | wc -l`;
my $file_to_basename = sub {
   my $res = $_[0];
   $res =~ s/\.[^\.]+$//;
   return $res;
};
my %events = (
    '0-TLB_COST' => sub { return $_[0] ? $_[0]->{GLOBAL} : undef },
    '1-READ_LATENCY_GLOB' => sub { return $_[0] ? $_[0]->{ALL} : undef }, 
    '2-L1TLB_MISS_PER_INSTR' => sub { return $_[0] ? $_[0]->{ALL} : undef },
    '3-L2TLB_MISS_PER_INSTR' => sub { return $_[0] ? $_[0]->{ALL} : undef },
    '4-L1_MISS_INST' => sub { return $_[0] ? $_[0]->{ALL} : undef },
    '5-L2_MISS_INST_JEREMY' => sub { return $_[0] ? $_[0]->{ALL} : undef },
    '6-L3_MISS_INST_JEREMY' => sub { return $_[0] ? $_[0]->{ALL} : undef }, 
    '7-IPC' => sub { return $_[0] ? $_[0]->{ALL} : undef },
    '8-INSTRUCTIONS' => sub { return $_[0] ? $_[0]->{GLOBAL}->{Instructions0} : undef },
    '9-CYCLES' => sub { return $_[0] ? $_[0]->{GLOBAL}->{Cycles0} : undef },
    '10-LOCAL_DRAM_RATIO2-#MemAccess' => sub { return $_[0] ? $_[0]->{GLOBAL}->{'number of memory accesses'} : undef },
    '11-LOCAL_DRAM_RATIO2-LAR' => sub { return $_[0] ? $_[0]->{GLOBAL}->{'local access ratio'} : undef },
    '12-LOCAL_DRAM_RATIO2-%ToMostLoaded' => sub { return $_[0] ? $_[0]->{GLOBAL}->{'% of accesses to most loaded node'} : undef },
);


my %results;
my @files : shared;
my @threads;

@files = @ARGV;
chomp($nb_cores);

print "#Parsing with $nb_cores cores\n" if(!$quiet);

sub worker {
   my %_results;

   while(1) {
      my $f = undef;
      {
         lock(@files);
         if($#files >= 0) {
            $f = shift(@files);
         }
         print "$#files files remaining\n" if(!$quiet);
      }
      last if(!defined $f);

      my $basename = $file_to_basename->($f);
      my $file = File::CachedFile::new($f);
      eval {
         my $result = $file->miniprof_parse();
         $result->{raw} = undef;
         $result->{analysed} = undef;
         push(@{$_results{$basename}}, shared_clone($result));
      };
   }

   return shared_clone(\%_results);
}

for my $core (0..($nb_cores-1)) {
   push(@threads, threads->create('worker'));
}
for my $core (0..($nb_cores-1)) {
   my $res = $threads[$core]->join();
   for my $basename (keys %$res) {
      for my $run (@{$res->{$basename}}) {
         push(@{$results{$basename}}, $run);
      }
   }
}

my $format = Format::new;
for my $f(sort keys %results) {
   my $bench = $f; 

   $format->add_partial_values_on_last_line(
      { 'Bench' => $bench }
   );

   for my $ev (sort { 
		my ($c) = ($a =~ m/^(\d+)-/);
		my ($d) = ($b =~ m/^(\d+)-/);
		return $c - $d;
	} keys %events) {
      my $real_ev = $ev; $real_ev =~ s/^\d+-//; $real_ev =~ s/-.*?$//;
      my $val = File::MiniProf::miniprof_find_info($results{$f}, $real_ev);
      $format->add_partial_values_on_last_line(
         {$ev => $events{$ev}->($val) }
      );
   }
}

$format->print;
