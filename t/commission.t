#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 17;
use Test::Deep;

use Coeus::Test;

# can commission an instance
interprets {
    is($_->lookup('x')->type, 'A');
} <<PROG;
type A {}

x := ![A]
PROG

# Capabilities are calculated after commission
interprets {
    ok($_->lookup('x')->has_capability('B'));
} <<PROG;
type A { B }

x := ![A]
PROG

# Properties can be assigned to
interprets {
    is($_->lookup('x')->lookup('z'), 1);
} <<PROG;
type A {}

x := ![A]
x.z := 1
PROG

# There is no limit to the names of properties
interprets {
    is($_->lookup('x')->lookup('z'), 1);
} <<PROG;
type A {}

x := ![A] {
    .z := 1
}
PROG

# Instance has no properties by default
interprets {
    ok(!$_->lookup('x')->has_capability('B'));
} <<PROG;
type A {
    .prop -> B
}

x := ![A]
PROG

# Capabilities are calculated after topic block application
interprets {
    ok($_->lookup('x')->has_capability('B'));
} <<PROG;
type A {
    .prop -> B
}

x := ![A] {
    .prop := 1
}
PROG

# topic block sees the enclosing environment
interprets {
    is($_->lookup('x')->lookup('prop'), 2);
} <<PROG;
type A { }

y := 1
x := ![A] {
    .prop := y * 2
}
PROG

# Behavior calculation cannot reference the outside environment
errors qr//, <<PROG;
type A { prop -> B }

prop := 1
x := ![A]
PROG

# sharing
interprets {
    cmp_deeply($_->lookup_subscription('first')->configuration->instances,
        [methods(id => 'id1', ['lookup', 'attr'] => 1)]);
    cmp_deeply($_->lookup_subscription('second')->configuration->instances,
        [methods(id => 'id1', ['lookup', 'attr'] => 1)]);
} <<PROG;
type A {}
landscape A {}

subscribe(A, 'first')
subscribe(A, 'second')

in 'first' { 
    ![A:id1] { .attr := 1 } 
}
in 'second' { 
    ![A:id1] 
}
PROG

# instances only get added once
interprets {
    cmp_deeply($_->system->configuration->instances,
        [methods(id => 'id1')]);
} <<PROG;
type A {}

![A:id1]
![A:id1]
PROG

# bringing in a shared instance also brings in depended upon instances
interprets {
    cmp_deeply($_->lookup_subscription('second')->configuration->instances,
        bag(methods('id' => 'id1'), methods('id' => ignore())));
    cmp_deeply($_->lookup_subscription('second')->configuration->uses,
        [methods('type' => 'cap')]);
} <<PROG;
type A { cap }
landscape A {}

subscribe(A, 'first')
subscribe(A, 'second')

in 'first' {
    y := ![A:id1]
    x := ![A]
    ![y -> cap x]
}

in 'second' {
    ![A:id1]
}
PROG

# adding a dependence on an instance brings the new instance into the subscriptions that contain the using instance
interprets {
    cmp_deeply($_->lookup_subscription('first')->configuration->instances,
        bag(methods(id => 'id1'), methods(id => 'id2')));
    cmp_deeply($_->lookup_subscription('first')->configuration->uses,
        [methods(type => 'cap')]);

    cmp_deeply($_->lookup_subscription('second')->configuration->instances,
        bag(methods(id => 'id1'), methods(id => 'id2')));
    cmp_deeply($_->lookup_subscription('second')->configuration->uses,
        [methods(type => 'cap')]);
} <<PROG;
type A { cap }
landscape A {}

subscribe(A, 'first')
subscribe(A, 'second')

in 'first' {
    ![A:id1]
}

in 'second' {
    x := ![A:id1]
    y := ![A:id2]
    ![x -> cap y]
}
PROG
