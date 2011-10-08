package Coeus::Test;

use strict;
use warnings;
use Exporter qw(import);
use Test::More;

use Carp qw(confess);
$SIG{__DIE__} = \&confess;

use Coeus::Interpreter;

# reusing the interpreter gives us a big speed boost
our $interp = Coeus::Interpreter->new();

our @EXPORT = qw(interprets errors parses);

sub interprets(&$) {
    my ($check, $text) = @_;
    my $env = eval { $interp->run($text) };
    if($@ && ref($@) eq 'ARRAY') {
        diag $@->[0] if $ENV{HARNESS_VERBOSE};
        $env = $@->[1];
    }
    elsif($@) {
        die $@;
    }

    local $_ = $env;
    $check->($env);
}

sub errors($$) {
    my ($match, $text) = @_;

    eval { $interp->run($text); };

    ok($@ && ((ref($@) eq "ARRAY" && $@->[0] =~ /$match/) || $@ =~/$match/))
        or diag "Error: <" . (ref($@) eq "ARRAY" ? $@->[0] : $@) . "> does not match the expected $match";

}

sub parses($) {
    my ($text) = @_;
    eval { $interp->run($text); };
    ok(!$@)
        or diag "$@->[0] does not parse";
}

1;
