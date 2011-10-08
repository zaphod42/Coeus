#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;
use Test::Deep;
use Data::Dumper;

use Coeus::Test;

interprets {
    cmp_deeply($_->lookup('x')->capabilities, []) or diag Dumper($_->lookup('x')->capabilities);
} <<PROG;
type A { .p eq "hello" -> world }

x := ![A] { .p := "something" }
PROG

interprets {
    is($_->lookup('x')->lookup('p'), 'hello');
    cmp_deeply($_->lookup('x')->capabilities, ['world']);
} <<PROG;
type A { .p eq "hello" -> world }

x := ![A] { .p := "hello" }
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, ['world']);
} <<PROG;
type A { .p eq "hello" -> world }

x := ![A]
x.p := "hello"
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, ['world']);
} <<PROG;
type A { ?[_ -> hello ?] -> world }
type B { hello }

x := ![A]
y := ![B]
![x -> hello y]
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, []);
} <<PROG;
type A { ?[_ -> hello ?] -> world }
type B { nope }

x := ![A]
y := ![B]
![x -> nope y]
PROG

interprets {
    cmp_deeply($_->lookup('no_use')->capabilities, []);
} <<PROG;
type A { ?[_ -> hello ?] -> world }
type B { hello }

x := ![A]
y := ![B]
![x -> hello y]

no_use := ![A]
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, bag('world', 'hello'));
} <<PROG;
type A { 
    ?[? -> hello _] -> world
    hello
}
type B { }

x := ![A]
y := ![B]
![y -> hello x]
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, bag('world', 'hello'));
} <<PROG;
type A {
    .p == 1 -> world
    .p * 2 == 2 -> hello
}

x := ![A] {
    .p := 1
}
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, bag('world', 'hello'));
} <<PROG;
type A {
    can?(world) -> hello
    .p == 1 -> world
}

x := ![A] {
    .p := 1
}
PROG

interprets {
    cmp_deeply($_->lookup('x')->capabilities, []);
} <<PROG;
type A { 
    ?[_ -> b ?] -> a
}
type B {
    ?[_ -> c ?] -> b
}
type C {
    c
}
x := ![A]
y := ![B]
z := ![C]
![y -> c z]
![x -> b y]
stop[z]
PROG

# make sure that this doesn't get parsed as "b.p -> a"
interprets {
    cmp_deeply($_->lookup('x')->capabilities, bag('a', 'b'));
} <<PROG;
type A {
    b
    .p -> a
}

x := ![A] {
    .p := 1
}
PROG

# behaviors sometimes cannot be calculated because there is no stable model
errors qr/loop detected/i, <<PROG;
type A {
    not can?(x) -> y
    can?(y) -> x
}
![A]
PROG
