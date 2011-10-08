#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 7;
use Test::Deep;

use Coeus::Test;

parses <<PROG;
type
    A
{}
PROG

parses <<PROG;
type   # line end comment
    A  # inside a command
{}
PROG

parses <<PROG;
type A {
    .a
    ->  # these lines are one
    b
    c # this is another
}
PROG

parses <<PROG;
type A { }

x 
:= ![
A ]{ # this is the init block
    .p
        := 1
}
PROG

errors qr/unable to parse/i, <<PROG;
type A {} ![ A ]
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, bag('b', 'c'));
} <<PROG;
type 
A { # comment
.p 
eq "hi"
-> c
b
}
x 
:= ![
A] 
{
.p :=
"hi"
}
PROG

parses <<PROG;
action s() {
    in 'f' {
    }
}
PROG
