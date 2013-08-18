#!perl

use strict;
use warnings;
use AnyEvent;
use Unruly;
use Data::Dumper::Concise;

my $ur = Unruly->new(url => 'http://yancha.hachiojipm.org', tags => {UNRULYBUILD => 1, PUBLIC => 1});
$ur->twitter_login('unruly_build' => 'unruly_1234');

my $cv = AnyEvent->condvar;

#my $w; $w = AnyEvent->timer( after => 2, interval => 8, cb => sub {
#    $ur->post('赤福！ #UNRULYBUILD');
#} );

$ur->run(sub {
    my ( $self, $socket ) = @_;
    $socket->on('user message' => sub { warn(Dumper(@_)); $_[1]->send; });
});

$cv->wait;
