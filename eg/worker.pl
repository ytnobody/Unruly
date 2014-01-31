#!perl

use strict;
use warnings;
use AnyEvent;
use Unruly;
use utf8;

my $ur = Unruly->new(url => 'http://yancha.hachiojipm.org', tags => {UNRULYBUILD => 1});
$ur->twitter_login('ytnobody', '******');

my $cv = AnyEvent->condvar;

$ur->run(sub {
    my ( $client, $socket ) = @_;
    $socket->on('user message', sub {
        my $post = $_[1];
        my @tags = @{$post->{tags}};
        my $nick = $post->{nickname};
        my $text = $post->{text};
        if($post->{is_message_log}){ # PlusPlus and other.
            return;
        }
        warn sprintf('%sは「%s」と言いました', $nick, $text);
    });
});

$cv->wait;
