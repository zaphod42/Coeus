#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 9;
use Test::Deep;

use Coeus::Test;

interprets {
    ok(!@{ $_->current_configuration->instances });
} <<PROG;
type A {}
action t() {
    # not called
    ![A]
}
PROG

interprets {
    cmp_deeply($_->current_configuration->instances, [methods(type => 'A')]);
} <<PROG;
type A {}
action t() {
    ![A]
}

t()
PROG

interprets {
    is($_->lookup('x')->type, 'A');
} <<PROG;
type A {}
type B {}
action t() {
    ![B]
    ![A]
}

x := t()
PROG

interprets {
    is($_->lookup('x'), $_->lookup('y'));
} <<PROG;
type A {}
action t(x) {
    x
}

x := ![A]
y := t(x)
PROG

interprets {
    ok(!$_->bound('x'));
} <<PROG;
type A {}
action t() {
    x := ![A]
    x
}

t()
PROG

interprets {
    isnt($_->lookup('x'), 2);
} <<PROG;
action t() {
    y
}

y := 2
x := t()
PROG

interprets {
    is($_->lookup('y'), '3hello world');
} <<PROG;
type A {}
action t(x, y, z) {
    x ~ y ~ z.p
}

x := ![A] { .p := " world" }
y := t(1 + 2, "hello", x)
PROG

# check for a problem in which the alpha ops (eq, ne, lt, gt, etc.) were
# being matched incorrectly by causing the identifier to be split
# In this the last 2 lines were parsing as "old() ne w()"
interprets {
    pass();
} <<PROG;
action new() { 1 }
action old() { 1 }

old()
new()
PROG

parses <<PROG;
action a() {}
PROG
