#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Utils;

package File::Specweb;

my $SPEC_FILE_NAME = qr/Spec2005([^_]*)_(.*)_(\d+)procs_(.*)_((?:sci\d+|\d+.\d+.\d+.\d+))_(.*)_(\d+)clients/;

sub spec_sort_ws {
   if(!($File::Utils::a =~ m/$SPEC_FILE_NAME/)) { return 1; };
   if(!($File::Utils::b =~ m/$SPEC_FILE_NAME/)) { return -1; };

   (my $unused1, my $name1, my $nbprocs1, my $irq1, my $server1, my $besim1, my $nbcl1)= ($File::Utils::a =~ m/$SPEC_FILE_NAME/);
   (my $unused2, my $name2, my $nbprocs2, my $irq2, my $server2, my $besim2, my $nbcl2)= ($File::Utils::b =~ m/$SPEC_FILE_NAME/);

   if($name1 ne $name2) { return $name1 cmp $name2; }
   if($nbprocs1 != $nbprocs2) { return $nbprocs1 - $nbprocs2; }
   if($nbcl1 != $nbcl2) { return $nbcl1 - $nbcl2; }
   if($irq1 ne $irq2) { return $irq1 cmp $irq2; }
   if($besim1 ne $besim2) { return $besim1 cmp $besim2; }
   (my $php1) = ($File::Utils::a =~ m/(\d+)php/); $php1 //= 8000;
   (my $php2) = ($File::Utils::b =~ m/(\d+)php/); $php2 //= 8000;
   if($php1 != $php2) { return $php1 - $php2; }
   return $File::Utils::a->{filename} cmp $File::Utils::b->{filename};
}

sub spec_sort_client {
   if(!($File::Utils::a =~ m/$SPEC_FILE_NAME/)) { return 1; };
   if(!($File::Utils::b =~ m/$SPEC_FILE_NAME/)) { return -1; };

   (my $unused1, my $name1, my $nbprocs1, my $irq1, my $server1, my $besim1, my $nbcl1)= ($File::Utils::a =~ m/$SPEC_FILE_NAME/);
   (my $unused2, my $name2, my $nbprocs2, my $irq2, my $server2, my $besim2, my $nbcl2)= ($File::Utils::b =~ m/$SPEC_FILE_NAME/);

   if($nbprocs1 != $nbprocs2) { return $nbprocs1 - $nbprocs2; }
   if($nbcl1 != $nbcl2) { return $nbcl1 - $nbcl2; }
   if($name1 ne $name2) { return $name1 cmp $name2; }
   if($irq1 ne $irq2) { return $irq1 cmp $irq2; }
   if($besim1 ne $besim2) { return $besim1 cmp $besim2; }
   (my $php1) = ($File::Utils::a  =~ m/(\d+)php/); $php1 //= 8000;
   (my $php2) = ($File::Utils::b  =~ m/(\d+)php/); $php2 //= 8000;
   if($php1 != $php2) { return $php1 - $php2; }
   return $File::Utils::a->{filename} cmp $File::Utils::b->{filename};
}

sub spec_sort_op {
   if(!($File::Utils::a =~ m/$SPEC_FILE_NAME/)) { return 1; };
   if(!($File::Utils::b =~ m/$SPEC_FILE_NAME/)) { return -1; };

   (my $op1) = ($File::Utils::a =~ m/op(\d+)/); $op1 //= 8000;
   (my $op2) = ($File::Utils::b =~ m/op(\d+)/); $op2 //= 8000;
   if($op1 != $op2) { return $op1 - $op2; }


   (my $unused1, my $name1, my $nbprocs1, my $irq1, my $server1, my $besim1, my $nbcl1)= ($File::Utils::a =~ m/$SPEC_FILE_NAME/);
   (my $unused2, my $name2, my $nbprocs2, my $irq2, my $server2, my $besim2, my $nbcl2)= ($File::Utils::b =~ m/$SPEC_FILE_NAME/);

   if($name1 ne $name2) { return $name1 cmp $name2; }
   if($nbprocs1 != $nbprocs2) { return $nbprocs1 - $nbprocs2; }
   if($nbcl1 != $nbcl2) { return $nbcl1 - $nbcl2; }
   if($irq1 ne $irq2) { return $irq1 cmp $irq2; }
   if($besim1 ne $besim2) { return $besim1 cmp $besim2; }
   (my $php1) = ($File::Utils::a =~ m/(\d+)php/); $php1 //= 8000;
   (my $php2) = ($File::Utils::b =~ m/(\d+)php/); $php2 //= 8000;
   if($php1 != $php2) { return $php1 - $php2; }
   return $File::Utils::a->{filename} cmp $File::Utils::b->{filename};
}

sub spec_get_info {
   my $self = $_[0];
   
   (my $bench_type, my $descr, my $nbprocs, my $irq, my $server, my $besim, my $nbcl) = ($self->{filename} =~ m/$SPEC_FILE_NAME/);
   ($nbprocs) =~ ($self->{filename} =~ m/(\d+)procs/) if(!defined $nbprocs);
   ($nbcl) =~ ($self->{filename} =~ m/(\d+)clients/) if(!defined $nbprocs);
   (my $op) = ($self->{filename} =~ m/op(\d+)/);
   (my $php) = ($self->{filename} =~ m/(\d+)php/);

   die "File ".$self->{filename}." has no sessions in its name" if(!defined $nbcl);

   $self->{spec_metadata}->{nbprocs} = $nbprocs;
   $self->{spec_metadata}->{sessions} = $nbcl;
   $self->{spec_metadata}->{sessions_per_core} = $nbprocs?($nbcl/$nbprocs):0;
   $self->{spec_metadata}->{irq} = $irq;
   $self->{spec_metadata}->{besim} = $besim;
   $self->{spec_metadata}->{op} = (defined $op)?("op$op"):undef;
   $self->{spec_metadata}->{php} = (defined $php)?($php."php"):undef;
   $self->{spec_metadata}->{descr} = $descr;
   return $self->{spec_metadata};
}

sub spec_file_to_other_file {
   my ($file, $new_ext) = @_;
   my $run_file = $file;
   if($file->{complete_filename} !~ m/$new_ext$/) {
      my $filename = $file->{complete_filename};
      $filename =~ s/\.[^\.]*$/\.$new_ext/;
      $run_file = $file->{base_dir}->get_file($filename);
      return $run_file if(defined $run_file);
      $run_file = $file->{base_dir}->get_file($file->{complete_filename}.'.'.$new_ext);
      #print "FILE : $new_ext ->".$file->{complete_filename}.$new_ext."\n";
      return $run_file;
   } else {
      return $file;
   }
}

sub spec_get_results {
   my $self = $_[0];

   my $run_file = spec_file_to_other_file($self, "hwc");
   return undef if(!defined $run_file);
   return $run_file->{spec_metadata} if(defined($run_file->{spec_metadata}->{good}));

   $run_file->spec_get_info;
   while (my $line = <$run_file>) {
      if($line =~ m/^Sessions/) {
         (my $session, my $requests) = ($line =~ m/(\d+); Total requests: (\d+)/);
         if($run_file->{spec_metadata}->{sessions} != $session) {
            die "Name mismatch: file ".$run_file->{filename}." is supposed to contain ".$run_file->{spec_metadata}->{sessions}." but found ".$session." in file";
         }
         $run_file->{spec_metadata}->{requests} = $requests;
      } elsif($line =~ m/^TIME_GOOD/) {
         ($run_file->{spec_metadata}->{good}, $run_file->{spec_metadata}->{tolerable}, $run_file->{spec_metadata}->{errors}) = ($line =~ m/(\d+\.\d+)%; TIME_TOLERABLE: (\d+\.\d+)%; Total errors: (\d+)/);
         $run_file->{spec_metadata}->{percent_errors} = $run_file->{spec_metadata}->{requests}?($run_file->{spec_metadata}->{errors}/$run_file->{spec_metadata}->{requests}):undef;
      }
   }
   return $run_file->{spec_metadata};
}

sub spec_get_throughtput {
   my ($self) = @_;

   my $run_file = spec_file_to_other_file($self, "dev");
   return undef if(!defined $run_file);
   return $run_file->{sar_dev} if(defined($run_file->{sar_dev}));

   $run_file->{sar_min_time_to_consider} = 360;
   $run_file->{sar_max_time_to_consider} = -180;
   return $run_file->sar_parse_dev;
}

sub spec_get_cpu {
   my ($self) = @_;

   my $run_file = spec_file_to_other_file($self, "cpu");
   return undef if(!defined $run_file);
   return $run_file->{sar_cpu} if(defined($run_file->{sar_cpu}));

   $run_file->{sar_min_time_to_consider} = 360;
   $run_file->{sar_max_time_to_consider} = -180;
   return $run_file->sar_parse_cpu;
}

sub is_valid_run {
   my $self = $_[0];
   if(!defined($self->{spec_metadata}->{requests})) {
      $self->spec_get_results;
   }
   return (($self->{spec_metadata}->{tolerable}//0) >= 99.0) && (($self->{spec_metadata}->{good}//0) >= 95.0);
}
1;
