#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 11;

use Coeus::Test;

interprets {
    is($_->lookup('x'), 0.25);
} <<PROG;
x := 0.5 * 0.5
PROG

interprets {
    is($_->lookup('x'), 2);
} <<PROG;
x := 4/2
PROG

interprets {
    is($_->lookup('x'), 2);
} <<PROG;
x := 4 - 2
PROG

interprets {
    is($_->lookup('x'), -2);
} <<PROG;
x := -2
PROG

interprets {
    is($_->lookup('x'), 11);
} <<PROG;
x := 2 + 3 * 3
PROG

interprets {
    is($_->lookup('x'), 15);
} <<PROG;
x := (2 + 3) * 3
PROG

interprets {
    is($_->lookup('x'), 9);
} <<PROG;
x := 3 * 6 / 2
PROG

interprets {
    is($_->lookup('x'), 6);
} <<PROG;
x := 6 / 3 * 3
PROG

interprets {
    is($_->lookup('x'), 7.5);
} <<PROG;
x := 2 * 3 / 4 * 5
PROG

interprets {
    is($_->lookup('x'), 4);
} <<PROG;
x := 1 + 2 - 3 + 4
PROG

interprets {
    is($_->lookup('x'), 6);
} <<PROG;
x := 8 + -2
PROG
