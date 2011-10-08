#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 10;

use Coeus::Test;
use Test::Deep;

interprets {
    cmp_deeply($_->current_configuration->instances,
        bag(methods(type => 'A'), methods(type => 'B')));
} <<PROG;
type A {}
type B {}

a := ![A]
b := ![a <- B]
PROG

interprets {
    cmp_deeply($_->current_configuration->uses,
        [methods(type => Coeus::Model::Use->HOST,
                 provider => shallow($_->lookup('a')),
                 user => shallow($_->lookup('b')))]);
} <<PROG;
type A {}
type B {}

a := ![A]
b := ![a <- B]
PROG

interprets {
    is($_->lookup('b')->lookup('p'), 1);
    is_deeply($_->lookup('b')->capabilities, ['c']);
} <<PROG;
type A {}
type B { .p -> c }

a := ![A]
b := ![a <- B] {
    .p := 1
}
PROG

# install with id provided
interprets {
    is($_->lookup('b')->id, 'id');
} <<PROG;
type A {}

a := ![A]
b := ![a <- A:id]
PROG

# install with id provided does not recreated the host relationship
interprets {
    is(scalar(@{ $_->current_configuration->uses }), 1);
} <<PROG;
type A {}

a := ![A]
![a <- A:id]
![a <- A:id]
PROG

# decommissioning removes the host relationship
interprets {
    is(scalar(@{ $_->current_configuration->uses }), 0);
} <<PROG;
type A {}

a := ![A]
![a <- A:id]

X[![A:id]]
PROG

# installing on multiple hosts
interprets {
    is(scalar(@{ $_->lookup('x') }), 2);
} <<PROG;
type A {}

![A]
![A]

x := ![?[A] <- A]
PROG

# cannot install on multiple hosts and give an ID.
# it would mean that the same instance is installed on more than once
errors qr/install id on more than one host/i, <<PROG;
type A {}

![A]
![A]

![?[A] <- A:id]
PROG

# cannot install on multiple hosts and give an ID.
# it would mean that the same instance is installed on more than once
errors qr/install id on more than one host/i, <<PROG;
type A {}

a := ![A]
b := ![A]

![a <- A:id]
![b <- A:id]
PROG
