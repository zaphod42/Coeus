#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;

use Coeus::Test;

interprets {
    is($_->lookup('x'), 'hello world');
} <<PROG;
x := "hello world"
PROG

interprets {
    is($_->lookup('x'), 'quote "');
} <<'PROG';
x := "quote \""
PROG

interprets {
    is($_->lookup('x'), 'quote "');
} <<'PROG';
x := 'quote "'
PROG

interprets {
    is($_->lookup('x'), 'hello world');
} <<PROG;
x := 'hello ' ~ 'world'
PROG

interprets {
    is($_->lookup('x'), '1.2 times');
} <<PROG;
x := 1.2 ~ ' times'
PROG

interprets {
    is($_->lookup('x'), '3 times');
} <<PROG;
x := 1 + 2 ~ ' times'
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 'one' eq 'one'
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 'one' ne 'two'
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 'b' gt 'a'
PROG

interprets {
    ok(!$_->lookup('x'));
} <<PROG;
x := 'a' gt 'b'
PROG

interprets {
    ok($_->lookup('x'));
} <<PROG;
x := 'a' lt 'b'
PROG
