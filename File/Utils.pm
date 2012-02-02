#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use File::Spec::Functions;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Archive::Tar;
use Exporter;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin";
use File::Specweb;
use File::DBBench;
use File::SWS;
use File::Sar;
use File::Slg;
use File::MiniProf;
use File::BProf;
use File::NumaWatcher;

package File::CachedFile;
our @ISA = qw(File::Specweb File::Sar File::MiniProf File::DBBench File::BProf File::Slg File::SWS File::NumaWatcher);

use overload
   '<>' => \&iterate,
   '""' => \&cast_to_scalar,
   'cmp' => \&cmp_files;

sub new {
   my $self = {};
   bless $self;
   die("No filename specified in File::CachedFile::new") if(!defined $_[0]);
   $self->{filename} = $_[0];
   $self->{base_dir} = $_[1];
   $self->{type} = $_[2];
   $self->{container_file} = $_[3];
   $self->{container_file_name} = $_[4];
   $self->{complete_filename} = $_[5] // $_[0];
   return $self;
}

sub new_virtual {
   my $self = {};
   bless $self;
   $self->{filename} = $_[0];
   $self->{content} = $_[1];
   return $self;
}
sub iterate {
   my $self = $_[0];

   if(!defined($self->{content})) {
      $self->add_content;
   }
   if(wantarray) {
      return @{$self->{content}};
   } else {
      return $self->{content}->[$self->{iterator_value}++];
   }
}

sub get_lines {
   my $self = $_[0];
   my @arr = $self->iterate;
   return @arr;
}

sub add_content {
   my $self = $_[0];
   my @lines;
   if(defined $self->{container_file}) {
      if($self->{type} eq "zip") {
          my $contents = $self->{container_file}->contents($self->{filename});
          @lines = split(/\n/, $contents);
      } elsif($self->{type} eq "bz2") {
          my @tbz_file = $self->{container_file}->get_files( @{[$self->{filename}]} );
          my $contents = $tbz_file[0]->get_content;
          @lines = split(/\n/, $contents);
      } else {
         die "Unknown type";
      }
   } else {
      open(FILE, $self->{filename}) || die("Cannot open file ".$self->{filename});
      @lines = <FILE>;
      close(FILE);
   }
   $self->{content} = \@lines;
}

sub cast_to_scalar {
   my $self = $_[0];
   return $self->{filename};
}

sub cmp_files {
   return $_[0]->{filename} cmp $_[1]->{filename};
}


1;

package File::Utils;

use overload
   '@{}' => \&cast_to_array,
   '""' => \&cast_to_scalar;

sub cast_to_scalar {
   print "??\n";
   return '';
}

sub file_exists {
   (my $self, my $file) = @_;
   return defined($self->{all_files}->{$file});
}

sub get_file {
   (my $self, my $file) = @_;
   return $self->{all_files}->{$file} if(defined $self->{all_files}->{$file});
   
   if(-f $file) {
      $self->{all_files}->{$file} =  File::CachedFile::new($file, $self);
   }  
   return $self->{all_files}->{$file};
}

sub get_files {
   if(wantarray) {
     return values %{new(@_)->{all_files}};
   } else {
      return new(@_);
   }
}

sub filter {
   (my $self, my $filter) = @_;
   my %hash;
   for my $k (keys %{$self->{all_files}}) {
      if($k =~ m/$filter/) {
         $hash{$k} = $self->{all_files}->{$k};
      }
   }
   $self->{files} = \%hash;
   if(wantarray) {
     return values %{$self->{files}};
   } else {
      return $self;
   }
}

sub sortby {
  (my $self, my $func) = @_;
  if(defined $func) {
     return sort $func values %{$self->{files}};
  } else {
     return sort values %{$self->{files}};
  }
}

sub new {
   if(!defined($_[0])) {
      die 'Usage: new("file/dir") or new(@files)';
   }

   my $self = {};
   bless $self;

   for(my $i = 0; defined($_[$i]); $i++) {
      if(-d $_[$i]) {
         $self->add_dir($_[$i]);
      } else {
         $self->add_files($_[$i]);
      }
   }
   return $self;
}

sub add_dir {
   (my $self, my $dir) = @_;
   if(ref($dir) eq "" && -d $dir) {
      opendir(DIR, $dir) || die "Cannot open dir $dir";
      my @files = readdir DIR;
      closedir(DIR);
      for my $f (@files) {
         if(-f File::Spec->catfile($dir,$f)) {
            $self->add_file(File::Spec->catfile($dir,$f));
         }
      }
   }
}

sub add_files {
   my $self = $_[0];
   if(ref($_[1]) eq "ARRAY") {
      for my $f (@{$_[1]}) {
         $self->add_file($f);
      }
   } elsif(ref($_[1]) eq "") {
      $self->add_file($_[1]);
   } else {
      die 'Usage: add_files(@files) or add_files("filename")';
   }
}

sub add_file {
   (my $self, my $filename) = @_;
   if(-f $filename) {
      if($filename =~ m/\.((?:zip|bz2))$/) {
         my $compressed_file;
         my $type = $1;
         my @members;

         if($type eq "zip") {
            my $compressed_file = Archive::Zip->new();
            if($compressed_file->read( $filename ) != Archive::Zip::AZ_OK) {
               die "File $filename is not a valid zip file";
            }
            @members = $compressed_file->memberNames();
         } elsif($type eq "bz2") {
            `pbzip2 -l -d $filename -k 2>/dev/null`;
            if($? != 0) {
               $compressed_file = Archive::Tar->new($filename, Archive::Tar::COMPRESS_BZIP); 
            } else {
               my $bunzipped_file = $filename;
               $bunzipped_file =~ s/\.bz2$//;
               $compressed_file = Archive::Tar->new($bunzipped_file); 
               unlink($bunzipped_file);
            }
            if(!defined($compressed_file)) {
               die "File $filename is not a valid bz2 file";
            } else {
               @members = map { $_->name } $compressed_file->get_files;
            }
         }
         for my $f (@members) {
            $self->{files}->{$compressed_file."/".$f} = File::CachedFile::new($f, $self, $type, $compressed_file, $filename, $compressed_file."/".$f);
            $self->{all_files}->{$compressed_file."/".$f} = $self->{files}->{$compressed_file."/".$f};
         }
      } else {
         $self->{files}->{$filename} = File::CachedFile::new($filename, $self);
         $self->{all_files}->{$filename} = $self->{files}->{$filename};
      }
   } else {
      die "$filename is not a file";
   }
}

sub cast_to_array {
   my $self = $_[0];
   my @ret = values %{$self->{files}};
   return \@ret;
}

1;
