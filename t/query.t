#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 20;
use Test::Deep;

use Coeus::Test;

interprets {
    cmp_deeply($_->lookup('x'), [shallow($_->lookup('y'))]);
} <<PROG;
type A { b }
y := ![A]
x := ?[y|can?(b)]
PROG

interprets {
    is_deeply($_->lookup('x'), []);
} <<PROG;
type A { }
y := ![A]
x := ?[y|can?(b)]
PROG

interprets {
    cmp_deeply($_->lookup('x'), [shallow($_->lookup('y'))]);
} <<PROG;
type A { b }
y := ![A]
x := ?[A|can?(b)]
PROG

interprets {
    cmp_deeply($_->lookup('x'), [shallow($_->lookup('y'))]);
} <<PROG;
type A { b }
y := ![A]
x := ?[A]
PROG

# instance query with wildcard
interprets {
    cmp_deeply($_->lookup('x'),
        bag(methods(type => 'A'), methods(type => 'B')));
} <<PROG;
type A { }
type B { }

![A]
![B]
x := ?[?]
PROG

interprets {
    is_deeply($_->lookup('x'), $_->current_configuration->uses);
} <<PROG;
type A { b }
y := ![A]
![y -> b y]
x := ?[y -> b y]
PROG

# can filter usages
interprets {
    is_deeply($_->lookup('x'), [$_->lookup('z2')]);
} <<PROG;
type A { b }
y := ![A]
z1 := ![y -> b y]
z2 := ![y -> b y]
stop[z1]
x := ?[y -> b y | running?(_)]
PROG

interprets {
    cmp_deeply($_->lookup('x'), [methods(provider => $_->lookup('y'))]);
} <<PROG;
type A { b }
type B { b }

y := ![A]
![y -> b y]

z := ![B]
![z -> b y]

w := ![A]
![w -> b z]

x := ?[?[A] -> b y]
PROG

interprets {
    cmp_deeply(
        $_->lookup('x'),
        [
            methods(provider => $_->lookup('y')),
            methods(provider => $_->lookup('y'))
        ]
    );
} <<PROG;
type A { b }
type B { }
y := ![A]
![y -> b y]

z := ![B]
![z -> b y]

x := ?[? -> b y]
PROG

# install query for the installed instance
interprets {
    cmp_deeply($_->lookup('x'),
        [
            methods(type => 'B')
        ]);
} <<PROG;
type A {}
type B {}

![A:base]
![![A:base] <- B]
![![A:base] <- A]
x := ?[?[A] <- B]
PROG

# install query for the hosting instance
interprets {
    cmp_deeply($_->lookup('x'),
        [
            methods(id => 'base2')
        ]);
} <<PROG;
type A {}
type B {}

![A:base1]
![A:base2]
![?[A:base1] <- B]
![?[A:base2] <- A:installed]
x := ?[A <- ?[A:installed]]
PROG

# install query for the hosting instance with filter
interprets {
    cmp_deeply($_->lookup('x'),
        [
            methods(id => 'base2')
        ]);
} <<PROG;
type A {}

![A:base1] { .a := 1 }
![A:base2] { .a := 2 }
![?[A:base1] <- A]
![?[A:base2] <- A]
x := ?[A <- ?[A] | .a == 2]
PROG

# install instance query with limiting rule
interprets {
    cmp_deeply($_->lookup('x'),
        [
            methods(type => 'B', ['lookup', 'attr'] => 1)
        ]);
} <<PROG;
type A {}
type B {}

![A:base]
![?[A:base] <- B] {
    .attr := 1
}
![?[A:base] <- B]
x := ?[?[A] <- B | .attr == 1]
PROG

# install query with wildcard
interprets {
    cmp_deeply($_->lookup('x'),
        bag(
            methods(type => 'B'),
            methods(type => 'A')
        ));
} <<PROG;
type A {}
type B {}

![A:base]
![?[A:base] <- B] 
![?[A:base] <- A]

x := ?[?[A] <- ?]
PROG

# can query an instance by id
interprets {
    cmp_deeply($_->lookup('a'), [methods(id => 'id')]);
} <<PROG;
type A {}

![A]
![A:id]

a := ?[A:id]
PROG

# can query for all instances and filter
interprets {
    cmp_deeply($_->lookup('a'), bag(methods(type => 'A'), methods(type => 'B', ['lookup', 'attr'] => 1)));
} <<PROG;
type A {}
type B {}

![A] { .attr := 1 }
![B] { .attr := 1 }
![B] { .attr := 2 }

a := ?[? | .attr == 1 ]
PROG

# can query for inclusion
interprets {
    ok($_->lookup('a'));
} <<PROG;
type A {}
type B {}

x := ![A] { .attr := 1 }
![B] { .attr := 1 }
![B] { .attr := 2 }

a := x subset ?[? | .attr == 1 ]
PROG

# can query for inclusion (exprs on both sides
interprets {
    ok($_->lookup('a'));
} <<PROG;
type A {}
type B {}

x := ![A] { .attr := 1 }
![B] { .attr := 1 }
![B] { .attr := 2 }

a := ?[A] subset ?[? | .attr == 1 ]
PROG

# can query for inclusion (negative case)
interprets {
    ok(!$_->lookup('a'));
} <<PROG;
type A {}
type B {}

x := ![A] { .attr := 1 }
![B] { .attr := 1 }
![B] { .attr := 2 }

a := x subset ?[? | .attr == 2 ]
PROG

# can query for wildcard capabilities
interprets {
    cmp_deeply($_->lookup('a'), bag(methods(type => 'a'), methods(type => 'b')));
} <<PROG;
type A { a }
type B { b }

![A]
![B]
![?[A] -> b ?[B]]
![?[B] -> a ?[A]]

a := ?[? -> ? ?]
PROG
