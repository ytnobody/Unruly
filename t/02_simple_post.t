use strict;
use warnings;
use Test::More;
use Unruly;
use utf8;
use Sys::Hostname;

my $test_msg = sprintf('time=%s host=%s user=%s ほげふがてすと #UNRULYBUILD', time, hostname, $ENV{USER});

my $unruly = Unruly->new(url => 'http://yancha.hachiojipm.org');
$unruly->twitter_login('unruly_build' => 'unruly_1234');
$unruly->post($test_msg);
my $posts = $unruly->search(keyword => $test_msg);

is $posts->[0]{text}, $test_msg;

done_testing;
