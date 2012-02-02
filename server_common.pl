use Switch;
use File::Basename;
use Sys::Hostname;

use IPC::Run qw( start finish run timeout );

my $REBOOT_AND_RETRY = "###REBOOT###";
my $ERROR            = "###ERROR###";


my @proc_order;
my $hostname = hostname;

if($hostname =~ m/chinqchint-\d+\.lille\.grid5000\.fr|edel-\d+\.grenoble\.grid5000\.fr/){
   @proc_order       = ( 7, 6, 5, 4, 3, 2, 1, 0 );
} elsif ($hostname =~ m/sci100/) {
   @proc_order       = ( 15, 11, 7, 3, 14, 10, 6, 2, 13, 9, 5, 1, 12, 8, 4, 0 );
} else {
   print $ERROR." Unknown server ...\n";
   exit -1;
}


sub su_do {
   my $cmd = $_[0];
   print "sudo: $cmd\n";
   system "echo \"$cmd\" | sudo -s";
}

# get nb cpu online
sub get_nb_online_cpu {
   #assume always cpu0 online
   my $nb_online_cpu = 1;

   my $cpu_file_name = "/sys/devices/system/cpu/cpu1/online";
   my $current_cpu   = 1;

   while ( -e $cpu_file_name ) {
      my $online = `sudo cat $cpu_file_name`;

      if ( $online == 1 ) {
         $nb_online_cpu++;
      }
      $current_cpu++;
      $cpu_file_name = "/sys/devices/system/cpu/cpu" . $current_cpu . "/online";
   }

   return $nb_online_cpu;
}

sub change_nb_active_proc {
   my $nb_procs = $_[0];
   
   if ( $nb_procs > get_nb_online_cpu() ) {
      print $REBOOT_AND_RETRY;
      exit(-1);
   }

   print "Changing nb_procs ($nb_procs)... ";
   my $max_proc = scalar(@proc_order);
   for my $proc (@proc_order) {
      last if ( $max_proc == $nb_procs );
      $max_proc--;
      su_do("echo 0 > /sys/devices/system/cpu/cpu$proc/online");
   }

   print "done.";
   return 0;
}

sub change_irqs {
   if ( !-e "/opt/script_irq/nic_irq_tool.pl" ) {
      print $ERROR. ": script nic_irq_tool.pl is not installed!\n";
      exit(-1);
   }

   my $irq = $_[0];
   print "Switching IRQs ($irq)... ";
   my $the_output = `sudo /opt/script_irq/nic_irq_tool.pl -s $irq`;
   if ( $the_output =~ m/Unknown/ ) {
      print $ERROR. ": unknows IRQ option $irq !\n";
      exit(-1);
   }
   print "done.";
   return "";
}