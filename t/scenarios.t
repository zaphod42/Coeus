#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Coeus::Test;

my @scenarios = read_files('scenarios/*.coeus');

plan tests => scalar(@scenarios);

foreach my $scenario (@scenarios) {
    interprets {
        ok(!$@, $scenario->{name});
    } $scenario->{contents};
}

sub read_files {
    my $pattern = shift;
    my @files = glob($pattern);

    my @contents;
    foreach my $file (@files) {
        open my($fh), $file or die "Unable to open $file for reading: $!";

        local $/;
        push @contents, { name => $file, contents => scalar(<$fh>) };

        close $fh;
    }

    return @contents;
}
