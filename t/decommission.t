#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;
use Test::Deep;

use Coeus::Test;

# decommission from a variable
interprets {
    ok(!$_->bound('x'));
    ok(!@{ $_->current_configuration->instances });
} <<PROG;
type A {}
x := ![A]
X[x]
PROG

# decommission from a direct expression
interprets {
    ok(!@{ $_->current_configuration->instances });
} <<PROG;
type A {}
X[![A]]
PROG

# decommssion a use
interprets {
    ok(!@{ $_->current_configuration->uses });
} <<PROG;
type A { b }
x := ![A]
![x -> b x]
X[?[x -> b x]]
PROG

# decommission in a topic block
interprets {
    ok(!@{ $_->current_configuration->uses });
} <<PROG;
type A { b }
x := ![A]
![x -> b x]
?[x -> b x] {
    X[_]
}
PROG

# decommission in a subscription leaves the instance in the system
interprets {
    is(scalar(@{ $_->current_configuration->instances }), 1);
    is(scalar(@{ $_->lookup_subscription('test')->configuration->instances }), 0);
} <<PROG;
type A {}
landscape A {}

subscribe(A, 'test')
in 'test' {
    X[![A]]
}
PROG

# decommission outside of a subscription removes the instance completely
interprets {
    is(scalar(@{ $_->current_configuration->instances }), 0);
    is(scalar(@{ $_->lookup_subscription('test')->configuration->instances }), 0);
} <<PROG;
type A {}
landscape A {}

subscribe(A, 'test')
in 'test' {
    ![A]
}

X[?[A]]
PROG

# decommission removes usage relationships
interprets {
    is(scalar(@{ $_->current_configuration->uses }), 0); 
} <<PROG;
type A { cap }

x := ![A]
y := ![A]
![x -> cap y]
X[x]
PROG

# decommission of a usage removes it completely from the system
interprets {
    is(scalar(@{ $_->current_configuration->uses }), 0);
    is(scalar(@{ $_->lookup_subscription('test')->configuration->uses }), 0);
} <<PROG;
type A { cap }
landscape A {}

subscribe(A, 'test')
in 'test' {
    ![A] {
        ![_ -> cap _]
    }
    X[?[? -> cap ?]]
}
PROG
