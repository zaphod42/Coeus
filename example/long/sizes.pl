#/usr/bin/perl

use strict;
use warnings;
use Math::Combinatorics qw(factorial);

print "Number of instances: ";
my $n = <STDIN>;
chomp $n;
print "Number of non-hosting usages: ";
my $u = <STDIN>;
chomp $u;
$n += $u;
print "Highest resiliency: ";
my $r = <STDIN>;
chomp $r;

my $sum = 0;
foreach my $k (1 .. $r) {
    print "Calculating combinations for $n, $k\n";
    $sum += (factorial($n) / (factorial($k) * factorial($n - $k)));
}

print "Need to check $sum configurations\n";
