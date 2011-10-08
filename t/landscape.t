#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 4;
use Test::Deep;

use Coeus::Test;

interprets {
    ok($_->lookup_landscape('A'));
} <<PROG;
landscape A {
}
PROG

interprets {
    cmp_deeply($_->lookup_landscape('A')->policies, bag(qw(state1 state2)));
    is($_->lookup_landscape('A')->start, 'state1');
} <<PROG;
landscape A {
*state1:
    1
state2:
    0
}
PROG

# The policy evaluates in the scope of a given subscription
errors qr/state1.*subscription invalid/si, <<PROG;
landscape A {
*state0: 1
state1:
    ?[A] == 1 
}
type A {}

subscribe(A, 'test')
in 'test' {
    ![A]
    policy[state1]
}

subscribe(A, 'invalid')
in 'invalid' { policy[state1] }
PROG
