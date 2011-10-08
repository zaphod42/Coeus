#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 10;
use Test::Deep;

use Coeus::Test;

# stop an instance
interprets {
    ok(!$_->lookup('x')->running);
} <<PROG;
type A {}

x := ![A]
stop[x]
PROG

# start an instance
interprets {
    ok($_->lookup('x')->running);
} <<PROG;
type A {}

x := ![A]
stop[x]
start[x]
PROG

# stopping an instance stops the instances hosted on it
interprets {
    ok(!$_->lookup('y')->running);
} <<PROG;
type A {}

x := ![A]
y := ![x <- A]
stop[x]
PROG

# starting an instance starts the hosted instances
interprets {
    ok($_->lookup('y')->running);
} <<PROG;
type A {}

x := ![A]
y := ![x <- A]
stop[x]
start[x]
PROG

# stopping an instance stops the usage relationships on it
interprets {
    cmp_deeply($_->system->configuration->uses, [methods(running => bool(0))]);
} <<PROG;
type A { cap }
type B { ?[_ -> cap ?] -> Bcap }

x := ![A]
y := ![B]
![y -> cap x]
stop[x]
PROG

# stopping an instance stops the usage relationships from it
interprets {
    cmp_deeply($_->system->configuration->uses, [methods(running => bool(0))]);
} <<PROG;
type A { }
type B { 
    ?[? -> cap _] -> Bcap 
    cap
}

x := ![A]
y := ![B]
![x -> cap y]
stop[y]
PROG

# stopping an instance removes all capabilities
interprets {
    cmp_deeply($_->lookup('y')->capabilities, []);
} <<PROG;
type A { }
type B { 
    ?[? -> cap _] -> Bcap 
    cap
}

x := ![A]
y := ![B]
![x -> cap y]
stop[y]
PROG

# starting brings them back
interprets {
    is(scalar(@{ $_->lookup('z') }), 2);
} <<PROG;
type A { cap }
type B { ?[_ -> cap ?] -> Bcap }

x := ![A]
y := ![B]
![y -> cap x]
![x -> cap x]
stop[x]
start[x]
z := ?[? -> cap x]
PROG

# instance queries return stopped instances (allows for formulating cold backup plans)
interprets {
    is(scalar(@{ $_->lookup('x') }), 1);
} <<PROG;
type A {}

![A]
stop[?[A]]
x := ?[A]
PROG

# can filter out not running instances
interprets {
    is(scalar(@{ $_->lookup('x') }), 0);
} <<PROG;
type A {}

![A]
stop[?[A]]
x := ?[A|running?(_)]
PROG
