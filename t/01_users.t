use strict;
use warnings;
use Test::More;
use Unruly;

my $unruly = Unruly->new(url => 'http://yancha.hachiojipm.org');
my $users = $unruly->users;
isa_ok $users, 'ARRAY';

done_testing;
