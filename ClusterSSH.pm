#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use threads ('yield',
    'stack_size' => 64*4096,
    'stringify'
);
use threads::shared;
#use ClusterWrapper;

package ClusterSSHNode;
use Net::SSH qw(ssh issh sshopen2 sshopen3 ssh_cmd);

use overload
'""' => \&cast_to_scalar;

my $debug = 0;
my $SSH_OPTS="-o \"StrictHostKeyChecking=no\"";

$|++;

sub new {
    my $self  = {};
    bless $self;

    $self->{hostname} = $_[0];
    $self->{number}   = $_[1];
    $self->{siblings}   = $_[2];
    return $self;
}

sub cast_to_scalar {
    my $self = $_[0];
    return $self->{hostname};
}

sub run_scriptfile {
    my $self          = $_[0];
    my $to_exec       = $_[1];
    my $env           = $_[2];
    my $opt           = $_[3];

    if ( !-f $to_exec ) {
        return ("[$self] Error file '$to_exec' does not exists\n");
    }

    my $to_file = "/tmp/"
    . File::Basename::basename($to_exec) . "."
    . int(rand(100000000));
    my $cmd = "scp $SSH_OPTS $to_exec $self:$to_file";
    my $ret = `$cmd 2>&1`;

    if ($?) {
        return ("Error returned by scp command ($cmd) on $self : \n$ret\n");
    }

    if($to_file =~ m/.pl./){
        return $self->run_cmd( "perl $to_file", $env, $opt );
    } else {
        return $self->run_cmd( "bash $to_file", $env, $opt );
    }
}

sub run_cmd {
    my $self          = $_[0];
    #syswrite(STDERR, "--> $self\n");

    my $to_exec       = $_[1];
    my $env           = $_[2];
    my $opt           = $_[3] // { };

    eval { ClusterWrapper::bind_pipe($self->{hostname}, $opt->{separate_window}); };

    my $cmd;
    my $ret = "";

    if ( defined($env) || $opt->{env_add_node_info} ) {
        my $envc = "";
        for my $e ( keys %$env ) {
            $envc .= "$e=\'" . $env->{$e} . "\' ";
        }
        if($opt->{env_add_node_info}) {
            $envc .= "NODE_NUM=\'" . $self->{number} . "\' ";
            $envc .= "TOTAL_NODE_NUM=\'" . (scalar(@{$self->{siblings}})) . "\' ";
        }
        $cmd = "env $envc $to_exec";
    } else {
        $cmd = $to_exec;
    }

    my $host = "$self";
    $host =~ s/ //g;

    my $user = defined $opt->{user} ? $opt->{user} : $ENV{USER};

    my $status = sshopen3("$user\@$host", *WRITER, *READER, *READER, $cmd);
    if(!$status) {
        print STDERR "ERROR ssh: $!\n";
        print STDERR "$self -> $cmd\n";
        exit(-1);
    }
    while (<READER>) {
        my $line = $_;
        $ret .= $line;
        if(!$opt->{silent}) {
            if($opt->{separate_window}) {
                print $line;
            } else {
                print "[$self] $line";
            }
        }
    }
    close(READER);
    close(WRITER);

    if ( $? && !$opt->{ignore_errors} ) {
        $ret //= "";
        chomp($ret);
        return ("Error returned by ssh command ($cmd) on node $self : \n$ret\n");
    }

    return ($ret);
}

sub sudo {
    my ($self, $cmd) = @_;
    my $out = $self->run_cmd("sudo ".$cmd);
    if($out =~ /sudo: no tty present and no askpass program specified/) {
        $out = $self->run_cmd($cmd);
    }
    return $out;
}

sub start_profilers {
    my ($self, $sar) = @_;
    $self->{sar} = $sar;

    my $async_thread = threads::async {
        if ( scalar keys %{$self->{sar}} > 0) {
            $self->sudo("killall -q -w sar");
            $self->sudo("rm /tmp/sar*");
        }

        if ( $self->{sar}->{watch_cpu_usage} ) {
            my $sar_cmd = "sar -P ALL 1 3600 > /tmp/sar.cpu";
            my $thr = threads->create( 'ClusterSSHNode::run_cmd', $self, $sar_cmd);
            $thr->detach();
        }
        if ( $self->{sar}->{watch_memory_usage} ) {
            my $sar_cmd = "sar -r 1 3600 > /tmp/sar.mem";
            my $thr = threads->create( 'ClusterSSHNode::run_cmd', $self, $sar_cmd);
            $thr->detach();
        }
        if ( $self->{sar}->{watch_network_usage} ) {
            my $sar_cmd = "sar -n DEV 1 3600 > /tmp/sar.dev";
            my $thr = threads->create( 'ClusterSSHNode::run_cmd', $self, $sar_cmd);
            $thr->detach();
        }
        if ( $self->{sar}->{watch_disk_usage} ) {
            my $sar_cmd = "sar -d 1 3600 > /tmp/sar.disk";
            my $thr = threads->create( 'ClusterSSHNode::run_cmd', $self, $sar_cmd);
            $thr->detach();
        }
    };
    $async_thread->detach();
}

sub stop_profilers {
    my ( $self ) = @_;

    if ( scalar keys %{$self->{sar}} > 0) {
        $self->sudo( "killall -q -w sar" );
    }

    my $cmd = "";
    if ($self->{sar}->{watch_cpu_usage}) {
        $cmd .= "scp $SSH_OPTS -q $self:/tmp/sar.cpu sar.$self.cpu;";
    }
    if ($self->{sar}->{watch_memory_usage}) {
        $cmd .= "scp $SSH_OPTS -q $self:/tmp/sar.mem sar.$self.mem;";
    }
    if ($self->{sar}->{watch_network_usage} ) {
        $cmd .= "scp $SSH_OPTS -q $self:/tmp/sar.dev sar.$self.dev;";
    }
    if ($self->{sar}->{watch_disk_usage}) {
        $cmd .= "scp $SSH_OPTS -q $self:/tmp/sar.disk sar.$self.disk;";
    }

    system $cmd;
}

package ClusterSSH;
use POSIX ":sys_wait_h";

sub new {
    my $nodes = $_[0];
    my $self  = {};
    bless $self;

    my $injector_num = 0;
    $self->{nodes}               = {map { $_ => ClusterSSHNode::new($_, $injector_num++, $nodes) } @$nodes};

    $self->{sar}->{watch_memory_usage}  = 0;
    $self->{sar}->{watch_cpu_usage}     = 0;
    $self->{sar}->{watch_network_usage} = 0;
    $self->{sar}->{watch_disk_usage}    = 0;

    return $self;
}

sub _run {
    my $self           = $_[0];
    my $to_exec        = $_[1];
    my $env            = $_[2];
    my $opt            = $_[3];
    my $nodes          = $self->{nodes};
    $self->{opt}       = $opt;
    $self->{results}   = ();

    # First start profilers if needed
    if ( $opt->{profile} ) {
        for my $n (values %$nodes) {
            $n->start_profilers($self->{sar});
        }
    }

    for my $k (keys %$nodes) {
        my $thr;
        if ($opt->{is_scriptfile}) {
            $thr = threads->create( 'ClusterSSHNode::run_scriptfile', $nodes->{$k}, $to_exec, $env, $opt );
            #print "1 - Created thread $thr for node $nodes->{$k}\n";
        } else {
            $thr = threads->create( 'ClusterSSHNode::run_cmd', $nodes->{$k}, $to_exec, $env, $opt );
            #print "Created thread $thr for node $nodes->{$k}\n";
        }
        push @{ $self->{threads}->{$k} }, $thr;
    }

    #print "Forked all events\n";

    my @all = threads->list(threads::all);
    my @running = threads->list(threads::running);
    my @joinable = threads->list(threads::joinable);



    #print main::Dumper(\@all);
    #print main::Dumper(\@running);
    #print main::Dumper(\@joinable);

    if ($opt->{do_not_join}) {
        return;
    } else {
        return $self->wait_threads;
    }
}

########################
## External functions ##
########################

sub wait_threads {
    my $self           = $_[0];
    my %to_return      = ();

    for my $n ( keys %{ $self->{threads} } ) {
        my $r      = "";
        my $ttable = $self->{threads}->{$n};

        for my $t (@$ttable) {
            $r .= $t->join() // "";
        }
        $to_return{$n} = $r;
    }

    ## Killing profilers
    if($self->{opt}->{profile}){
        my @profiling_threads = ();
        for my $n ( keys %{ $self->{threads} } ) {
            my $thr = threads->create( 'ClusterSSHNode::stop_profilers', $self->{nodes}->{$n});
            push @profiling_threads, $thr;
        }
        for my $thr (@profiling_threads) {
            $thr->join();
        }
    }
    ## End

    while ((my $child = waitpid(-1,WNOHANG)) > 0) {
        #don't care
    }

    $self->{threads} = undef;
    $self->{results} = \%to_return;
return \%to_return;
}

sub run_scriptfile {
    my ( $self, $to_exec, $env, $opt ) = @_;
    return $self->_run( $to_exec, $env, {
            is_scriptfile => 1,
            defined $opt ? %$opt : (),
        });
}

sub run_cmd {
    my ( $self, $to_exec, $env, $opt ) = @_;
    return $self->_run( $to_exec, $env, {
            is_scriptfile => 0,
            defined $opt ? %$opt : (),
        });
}

1;

