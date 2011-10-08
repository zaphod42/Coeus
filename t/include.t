#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Coeus::Test;

interprets {
    is($_->lookup('x'), 'included');
} <<PROG;
include 't/data/test.coeus'
PROG

errors qr/unable to include/i, <<PROG;
include 't/data/not_there.coeus'
PROG
