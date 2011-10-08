#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 8;
use Test::Deep;

use Coeus::Test;

interprets {
    ok($_->lookup_subscription('test'));
} <<PROG;
landscape A {}

subscribe(A, 'test')
PROG

interprets {
    ok(!$_->lookup_subscription('test'));
} <<PROG;
landscape A {}

subscribe(A, 'test')
unsubscribe('test')
PROG

interprets {
    cmp_deeply($_->lookup_subscription('test')->configuration->instances,
        [methods(type => 'A')]);
    cmp_deeply($_->lookup_subscription('test')->configuration->instances,
        [@{ $_->system->configuration->instances }]);
} <<PROG;
landscape A {}
type A {}

subscribe(A, 'test')

in 'test' {
    ![A]
}
PROG

interprets {
    cmp_deeply($_->current_configuration->instances,
        [methods(type => 'A')]);
} <<PROG;
landscape A {}
type A {}

subscribe(A, 'test')

in 'test' {
    ![A]
}

unsubscribe('test')
PROG

# Policies are not checked until the end of the atomic block
interprets {
    ok(!$@);
} <<PROG;
landscape A {
    *start: ?[A] == 0
    other: ?[A] == 1
}
type A {}

subscribe(A, 'test')
in 'test' {
    atomic {
        policy[other]
        ![A]
    }
}
PROG

errors qr/no subscription named 'foo'/i, <<PROG;
in 'foo' {
}
PROG

# can subscribe and in with variables
interprets {
    ok(!$@)
} <<PROG;
landscape A {}

sub := 'foo'
subscribe(A, sub)
in sub {
}
PROG
