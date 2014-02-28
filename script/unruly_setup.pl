#!perl
use strict;
use warnings;
use 5.014;
use IO::Handle;
use File::Spec;
use Carp;

STDERR->autoflush(1);
STDOUT->autoflush(1);

use constant TYPES => {
    '1' => 'daemontools',
    '2' => 'Server::Starter',
    '3' => 'Proclet', 
    '9' => 'Without Superdaemon',
};

sub _getline () {
    my $command = STDIN->getline;
    $command =~ s/(\r\n|\n)$//;
    $command;
}

sub _mkdir ($) {
    my $in_path = shift;
    my @path = split(/(\/|\\|\:\:)/, $in_path);
    for my $i (0 .. $#path) {
        my $_path = File::Spec->catdir(@path[0 .. $i]);
        unless (-d $_path) {
            warn "mkdir: $_path";
            mkdir $_path or die $!;
        }
    }
    return File::Spec->catdir(@path);
}

sub _spew ($$;$) {
    my ($in_path, $data, $mode) = @_;
    my @path = split(/(\/|\\|\:\:)/, $in_path);
    my $file = File::Spec->catfile(@path);
    open my $fh, '>', $file or croak $!;
    print $fh $data;
    close $fh;
    if ($mode) {
        chmod $mode, $file;
    }
}

my $bot_name = shift @ARGV;
my $type;
my $types = TYPES;
my $template = do {local $/; <DATA>};

# receive a bot name 
while (!$bot_name) {
    print 'Please enter a bot name: ';
    $bot_name = _getline;
}

# receive a setup type
while (!$type) {
    print "Please choose a superdaemon. \n";
    for my $number (sort keys %$types) {
        printf('%s: %s'."\n", $number, $types->{$number});
    }
    print 'What do you want to use? (type a number): ';
    my $num = _getline;
    $type = $types->{$num};
}

# set some path for internally use
my $dist_name = $bot_name =~ s/\:\:/\-/rg;
my $parent_namespace = $bot_name =~ s/::(.+?)$//r;

# create project directory
my $base_dir = _mkdir($dist_name);
my $base_dir_fullpath = File::Spec->rel2abs($base_dir);

# create worker.pl
$template =~ s/__bot_name__/$bot_name/g;
_spew("$base_dir/worker.pl", $template, 0755);

# define miscellaneous variables
my $username = getpwuid($>);

# define basal cpanfile
my $cpanfile_data = <<'EOF';
requires 'Log::Minimal';
requires 'AnyEvent';

### for Unruly
requires 'JSON';
requires 'PocketIO::Client::IO';
requires 'URI';
requires 'WWW::Mechanize';

EOF

# define run file for daemontools
my $runfile_data = <<'EOF';
#!/bin/sh
BOT_USER=__user_name__
cd __base_dir__
exec 2>&1
exec setuidgid \$BOT_USER ./worker.pl
sleep 5 ### reconnect interval
EOF

# define log/run file for daemontools
my $logrunfile_data = <<EOF;
#!/bin/sh
exec 2>&1
exec multilog t ./main
EOF

# define run file for Server::Starter
my $start_server_data = <<'EOF';
#!/bin/sh
cd __base_dir__ 
start_server --interval=5 -- ./worker.pl
EOF

# define Procfile for Proclet
my $procfile_data = <<EOF;
bot: ./worker.pl
EOF

if ($type eq 'daemontools') {
    print "Please input username for setuidgid [$username]: ";
    my $_username = _getline || $username;

    print "Please input path for service [$base_dir_fullpath]: ";
    my $_base_dir = _getline || $base_dir_fullpath;

    $runfile_data =~ s/__user_name__/$_username/g;
    $runfile_data =~ s/__base_dir__/$_base_dir/g;

    _mkdir("$base_dir/service/$dist_name/log");
    _spew("$base_dir/service/$dist_name/run", $runfile_data, 0755);
    _spew("$base_dir/service/$dist_name/log/run", $logrunfile_data, 0755);
}
elsif ($type eq 'Server::Starter') {
    print "Please input path for service [$base_dir_fullpath]: ";
    my $_base_dir = _getline || $base_dir_fullpath;

    $start_server_data =~ s/__base_dir__/$_base_dir/g;

    $cpanfile_data .= sprintf("requires '%s';\n", 'Server::Starter');
    _spew("$base_dir/run", $start_server_data, 0755);
}
elsif ($type eq 'Proclet') {
    $cpanfile_data .= sprintf("requires '%s';\n", 'Proclet');
    _spew("$base_dir/Procfile", $procfile_data);
}

# create cpanfile
_spew("$base_dir/cpanfile", $cpanfile_data);

# git init
chdir $base_dir;
system(qw/git init/);

# add Unruly as a submodule
system(qw/git submodule add/, 'git://github.com/ytnobody/Unruly.git', File::Spec->catfile('submodules','Unruly'));

__DATA__
#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use Log::Minimal;
use AnyEvent;

use File::Spec;
use File::Basename 'dirname';
use lib (
    File::Spec->catdir(dirname(__FILE__), 'lib'),
    File::Spec->catdir(dirname(__FILE__), 'local', 'lib'),
    glob(File::Spec->catdir(dirname(__FILE__), 'submodule', '*', 'lib')),
);
use Unruly;

my $bot_name = '__bot_name__';
my @tags = qw/BOT/;

my $bot = Unruly->new(
    url  => 'http://yancha.hachiojipm.org',
    tags => {map {($_ => 1)} @tags},
    ping_intervals => 15,
);

unless( $bot->login($bot_name) ) {
    critf('Login failure');
    exit;
}

my $cv = AnyEvent->condvar;

$bot->run(sub {
    my ($client, $socket) = @_;

    infof('runnings at pid %s', $$);

    $socket->on('user message' => sub {
        my ($_socket, $message) = @_;

        if ($message->{is_message_log}) {
            ### ++などに反応させたい場合はここにロジックを書く
        }
        else {
            unless ($message->{nickname} eq $bot_name) {
                infof('received "%s" (from:%s)', $message->{text}, $message->{nickname});

                my $response = sprintf('%s さんは 「%s」 と言いました', $message->{nickname}, $message->{text});
                $bot->post($response, @tags);
            }
        }
    });

});

$cv->wait;


