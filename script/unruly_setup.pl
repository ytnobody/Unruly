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

sub _spew ($$) {
    my ($file, $data) = @_;
    open my $fh, '>', $file or croak $!;
    print $fh $data;
    close $fh;
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

# create worker.pl
$template =~ s/__bot_name__/$bot_name/g;
_spew(File::Spec->catfile($base_dir, 'worker.pl'), $template);

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

if ($type eq 'daemontools') {
}
elsif ($type eq 'Server::Starter') {
    $cpanfile_data .= sprintf("requires '%s';\n", 'Server::Starter');
}
elsif ($type eq 'Proclet') {
    $cpanfile_data .= sprintf("requires '%s';\n", 'Proclet');
}

# create cpanfile
_spew(File::Spec->catfile($base_dir, 'cpanfile'), $cpanfile_data);

# git init
chdir $base_dir;
system(qw/git init/);

# add Unruly as a submodule
system(qw/git submodule add/, 'git://github.com/ytnobody/Unruly.git', File::Spec->catfile('submodules','Unruly'));

__DATA__
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


