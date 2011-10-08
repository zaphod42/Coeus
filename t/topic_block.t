#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 6;

use Coeus::Test;

interprets {
    is($_->lookup('x')->lookup('p'), 1);
} <<PROG;
type A {}
x := ![A]
x {
    _.p := 1
}
PROG

interprets {
    is($_->lookup('x')->lookup('p'), 1);
} <<PROG;
type A {}
x := ![A]
x {
    .p := 1
}
PROG

interprets {
    is($_->lookup('x')->lookup('p'), 1);
    is($_->lookup('x')->lookup('q'), 2);
} <<PROG;
type A {}
x := ![A]
x {
    .p := 1
    .q := 2
}
PROG

interprets {
    is($_->lookup('x')->lookup('p'), 60);
} <<PROG;
type A {}
y := 2 * 30
x := ![A]
x {
    .p := y
}
PROG

interprets {
    is_deeply([map { $_->lookup('p') } @{ $_->current_configuration->instances }], [1, 1]);
} <<PROG;
type A {}
![A]
![A]
?[A] {
    .p := 1
}
PROG
