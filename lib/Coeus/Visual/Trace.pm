package Coeus::Visual::Trace;

use strict;
use warnings;
use Scalar::Util qw(blessed);

use Coeus::Interpreter::Hook;

Coeus::Interpreter::Hook::register_entry(\&start_trace);
Coeus::Interpreter::Hook::register_exit(\&show_trace);

sub start_trace {
    my ($env, $op, $uid) = @_;

    if (   $op eq 'commission'
        || $op eq 'use'
        || $op eq 'bind'
        || $op eq 'decommission'
        || $op eq 'stop_instance'
        || $op eq 'start_instance') {
        print STDERR " ==> Entering $op\n";
    }
}

sub show_trace {
    my ($env, $op, $uid, $return, @args) = @_;

    if (   $op eq 'commission'
        || $op eq 'use')
    {
        print STDERR " <== ${op}(", join(q{, }, _to_string(@args)),
          ") => " . _to_string($return) . "\n";
    } elsif($op eq 'bind') {
        my ($value, $symtab, $var) = ($args[0], @{ $args[1] });
        if($symtab->isa('Coeus::Model::Instance')) {
            print STDERR " <== " . _to_string($symtab) . ".$var := $value\n";
        }
        else {
            print STDERR " <== No configuration change from bind\n";
        }
    } elsif ($op eq 'decommission'
        || $op eq 'stop_instance'
        || $op eq 'start_instance')
    {
        print STDERR " <== ${op}(", join(q{, }, _to_string(@args)), ")\n";
    }
}

sub _to_string {
    my (@things) = grep { defined } @_;

    my @strings = map {
        (blessed($_) && $_->isa('Coeus::Model::Instance'))
          ? $_->type . ":" . $_->id
          : (blessed($_) && $_->isa('Coeus::Model::Use'))
          ? '['
          . _to_string($_->user) . ' -> '
          . $_->type . " "
          . _to_string($_->provider) . ']'
          : (ref($_) eq 'ARRAY') ? '('. join(q{, }, _to_string(@$_)) . ')'
          : $_
    } @things;

    if(wantarray) {
        return @strings;
    }
    else {
        return join(q{}, @strings);
    }
}

1;
