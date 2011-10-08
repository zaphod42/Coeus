#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;

use Coeus::Test;

interprets {
    ok(!$_->bound('x'));
} <<PROG;
PROG

interprets {
    is(1, $_->lookup('x'));
} <<PROG;
x := 1
PROG

interprets {
    is(7, $_->lookup('x'));
} <<PROG;
x := 2 * 2 + 3
PROG

interprets {
    is(7, $_->lookup('y'));
} <<PROG;
x := 7
y := x
PROG

interprets {
    is(7, $_->lookup('y')->lookup('z'));
} <<PROG;
type A { }
y := ![A]
y.z := 7
PROG

interprets {
    is(7, $_->lookup('y')->lookup('z'));
} <<PROG;
type A { }
x := ![A]
x.w := 7

y := ![A]
y.z := x.w
PROG

interprets {
    is(14, $_->lookup('y')->lookup('z'));
} <<PROG;
type A { }
x := ![A]
x.w := 7

y := ![A]
y.z := x.w * 2
PROG

interprets {
    is("hello", $_->lookup('x'));
} <<PROG;
x := "hello"
PROG

interprets {
    is("hello", $_->lookup('y')->lookup('z'));
} <<PROG;
type A {}
y := ![A]
y.z := "hello"
PROG

interprets {
    is($_->lookup('x'), 1);
    is($_->lookup('y'), 1);
} <<PROG;
x := y := 1
PROG
