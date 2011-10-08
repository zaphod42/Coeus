#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;
use Test::Deep;

use Coeus::Test;

# can setup a usage between instances
interprets {
    my $x = $_->lookup('x');
    my $y = $_->lookup('y');

    ok(
        @{ $_->current_configuration->find_usages(
            sub {
                $_->user == $x
                  && $_->provider == $y
                  && $_->type eq 'B';
            }
        ) } > 0
    );
} <<PROG;
type A { B }
x := ![A]
y := ![A]

![x -> B y]
PROG

errors(qr/cannot use b/i, <<PROG);
type A { }
x := ![A]
![x -> B x ]
PROG

# can setup from multiple instances a usage
interprets {
    my $x = $_->lookup('x');
    cmp_deeply($_->current_configuration->find_usages(sub { $_->provider == $x }),
        [methods(type => 'cap'), methods(type => 'cap'), methods(type => 'cap')]);
} <<PROG;
type A { cap }

x := ![A]
![A]
![A]

![?[A] -> cap x]
PROG

# can setup to multiple instances a usage
interprets {
    my $x = $_->lookup('x');
    cmp_deeply($_->current_configuration->find_usages(sub { $_->user == $x }),
        [methods(type => 'cap'), methods(type => 'cap'), methods(type => 'cap')]);
} <<PROG;
type A { cap }

x := ![A]
![A]
![A]

![x -> cap ?[A]]
PROG

# no usages are created if one cannot happen
interprets {
    ok($@);
    is(scalar(@{ $_->current_configuration->uses }), 0);
} <<PROG;
type A { .b -> cap }

x := ![A] { .b := 1 }
![A] { .b := 1 }
![A]

![x -> cap ?[A]]
PROG

# can stop usages
interprets {
    ok(!$_->lookup('b')->running);
    cmp_deeply($_->lookup('a')->capabilities, ['cap']);
} <<PROG;
type A { 
    ?[_ -> cap ?] -> cap2
    cap 
}

a := ![A]
b := ![a -> cap a]
stop[b]
PROG

# can start usages
interprets {
    ok($_->lookup('b')->running);
    cmp_deeply($_->lookup('a')->capabilities, bag('cap', 'cap2'));
} <<PROG;
type A { 
    ?[_ -> cap ?] -> cap2
    cap 
}

a := ![A]
b := ![a -> cap a]
stop[b]
start[b]
PROG

# can start usages from a query
interprets {
    ok($_->lookup('b')->running);
    cmp_deeply($_->lookup('a')->capabilities, bag('cap', 'cap2'));
} <<PROG;
type A { 
    ?[_ -> cap ?] -> cap2
    cap 
}

a := ![A]
b := ![a -> cap a]
stop[b]
start[?[a -> cap a]]
PROG
