#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Coeus::Test;

interprets {
    ok($_->lookup_type('A'));
} <<PROG;
type A { }
PROG

interprets {
    isa_ok($_->lookup_type('A'), 'CODE');
} <<PROG;
type A {
    c
}
PROG
