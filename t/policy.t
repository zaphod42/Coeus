#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 13;

use Coeus::Test;

# False policy has no way of conforming
errors qr/does not conform to policy/i, <<PROG;
landscape A {
    *state:
        0
}

subscribe(A, 'test')
in 'test' {
    x := 1
}
PROG

# default resiliency is 0 (do not care about failures)
interprets {
    is($_->lookup_landscape('A')->resilient('state'), 0);
}<<PROG;
landscape A {
    *state:
        1
}
PROG

# can change the resiliency
interprets {
    is($_->lookup_landscape('A')->resilient('state'), 2);
}<<PROG;
landscape A {
    *state(resilient = 2):
        1
}
PROG

# failing instances stop the policy from being fulfilled
errors qr/does not conform to policy/i, <<PROG;
landscape A {
    *maint:
        1
    prod(resilient = 2):
        ?[A | running?(_)] >= 2
}

type A {}

subscribe(A, 'sub')

in 'sub' {
    ![A] 
    ![A]
    ![A]
    policy[prod]
}
PROG

# fails are only checked up to the level of resiliency
interprets {
    ok(!$@);
}<<PROG;
landscape A {
    *maint:
        1
    prod(resilient = 2):
        ?[A | running?(_)] >= 2
}

type A {}

subscribe(A, 'sub')

in 'sub' {
    ![A] 
    ![A]
    ![A]
    ![A]
    policy[prod]
}
PROG

# usages can also fail
errors qr/does not conform to policy/i, <<PROG;
landscape A {
    *maint:
        1
    prod(resilient = 1):
        ?[A | running?(_)] < 2 || (?[A | running?(_)] == 2 && ?[?[A] -> cap ?[A]] >= 1)
}

type A { cap }

subscribe(A, 'sub')

in 'sub' {
    ![A:id1]
    ![A:id2]
    ![?[A:id1] -> cap ?[A:id2]]
    policy[prod]
}
PROG

# When a hosting instance fails all of the hosted instances fail
errors qr/does not conform to policy/i, <<PROG;
landscape A {
    *maint:
        1
    prod(resilient = 1):
        ?[B | running?(_)] >= 1
}

type A { }
type B { }

subscribe(A, 'sub')

in 'sub' {
    ![A:host]
    ![?[A:host] <- B]
    ![?[A:host] <- B]
    policy[prod]
}
PROG

errors qr/subscription a of landscape foo does not have a policy bar/i, <<PROG;
landscape Foo { }

subscribe(Foo, 'a')

in 'a' {
    policy[bar]
}
PROG

# Policies can be composed of other policies
errors qr/does not conform to policy/i, <<PROG;
landscape A {
    *start: 1
    main:
        ?[B] == 1 && other
    other:
        ?[A] == 1
}
type A {}
type B {}

subscribe(A, 'a')
in 'a' {
    ![B]
    policy[main]
}
PROG

# other policies cannot appear inside queries
errors qr/unable to parse/i, <<PROG;
landscape A {
    *start: 1
    main:
        ?[B | other] == 1
    other:
        ?[A] == 1
}
type A {}
type B {}

subscribe(A, 'a')
in 'a' {
    ![B]
    policy[main]
}
PROG

# other policies cannot appear inside queries
errors qr/unable to parse/i, <<PROG;
landscape A {
    *start: 1
    main:
        ?[?[B] -> b other] == 1
    other:
        ?[A] == 1
}
PROG

# the resilient attribute specifies the *minimum* resiliency
# policies placed together with && will go to the maximum of the two
# sides resiliency
errors qr/does not conform to policy/i, <<PROG;
landscape A {
    *start: 1
    main:
        ?[B | running?(_) ] == 1 && other
    other(resilient = 2):
        ?[A | running?(_) ] >= 1
}
type A {}
type B {}

subscribe(A, 'a')
in 'a' {
    ![A]
    ![A]
    ![A]
    ![B]
    policy[main]
}
PROG

# TODO: test ||

# The error message contains the comments from the policies
errors qr/comment 1.*comment 2/si, <<PROG;
landscape A {
    *start: 1
    main(comment = "comment 2"):
        ?[B | running?(_) ] >= 0 && other
    other(resilient = 2, comment = "comment 1"):
        ?[A | running?(_) ] >= 1
}
type A {}
type B {}

subscribe(A, 'a')
in 'a' {
    ![A]
    ![A]
    ![B]
    ![B]
    ![B]
    policy[main]
}
PROG
