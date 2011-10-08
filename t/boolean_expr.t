#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 17;

use Coeus::Test;

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 1 && 2
PROG

interprets {
    ok(!$_->lookup('x'));
} <<PROG;
x := 0 && 1
PROG

interprets {
    ok(!$_->lookup('x'));
} <<PROG;
x := 1 && 0
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 1 || 2
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 0 || 2
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 1 || 0
PROG

interprets {
    ok(!$_->lookup('x'));
} <<PROG;
x := 0 || 0
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 1 && 2 || 0
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 0 || 7 && 0 || 1
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := not 0
PROG

interprets {
    ok(!$_->lookup('x'));
} <<PROG;
x := not not 0
PROG

interprets {
    ok(!$_->lookup('x'));
} <<PROG;
x := not 0 && 0
PROG

interprets {
    is($_->lookup('x'), "hello");
} <<PROG;
x := 0 || "hello"
PROG

interprets {
    is($_->lookup('x'), "hello");
} <<PROG;
x := "no" && "hello"
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
type A {}
![A]
x := ?[A] == 1
PROG

interprets {
    ok(!$_->lookup('x'));
} <<PROG;
x := y || 0
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := not y
PROG
