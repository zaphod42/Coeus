package Coeus::Interpreter::Hook;

use strict;
use warnings;

my %REGISTRATIONS;

sub register {
    my ($mapper) = @_;
    register_entry($mapper);
    register_exit($mapper);
}

sub register_entry {
    _register_to($_[0], 'entry');
}

sub register_exit {
    _register_to($_[0], 'exit');
}

sub _register_to {
    my ($mapper, $list) = @_;
    push @{ $REGISTRATIONS{$list} }, $mapper;
}

sub signal_entry {
    my ($env, $op, $uid) = @_;
    $_->($env, $op, $uid) foreach (@{ $REGISTRATIONS{entry} });
}

sub signal_exit {
    my ($env, $op, $uid, $return, @args) = @_;
    $_->($env, $op, $uid, $return, @args) foreach (reverse @{ $REGISTRATIONS{exit} });
}

1;

__END__

=head1 NAME

Coeus::Interpreter::Hook - Provide hooks into the evaluation of Coeus

=head1 SYNOPSIS

 package My::Coeus::Hook;

 use Coeus::Interpreter::Hook;

 Coeus::Interpreter::Hook::register_entry(\&hook);
 Coeus::Interpreter::Hook::register_exit(\&other_hook);

 sub hook {
    my ($env, $op, $uid) = @_;
    # do things *before* $op is evaluated
 }

 sub other_hook {
    my ($env, $op, $uid, $return, @args) = @_;
    # do things *after* $op has been evaluated to $return
 }

=head1 DESCRIPTION

This module provides a general hook mechanism into the evaluation
of Coeus. It is possible to hook into before, after, and before+after a
node of Coeus is interpreted. In all cases the environment for the interpretation
is provided as well as the operation that is being interpreted.  The arguments
of the operation are not provided, but a UID for the operation is so that
it is easy to find the exit that corrosponds with an entry.

If a hook dies, the error will halt the interpretation and the error will be
propogated out.

In all cases the provided coderefs will be called in the order in with they
are registered.

=head1 FUNCTIONS

=over 8

=item C<register_entry($coderef)>

Provide a $coderef that will be called I<before> interpreting an operation.  The
$coderef will be passed the current L<Coeus::Interpreter::Environment> as well as a string
of the name of the operation that will be performed next.

=item C<register_exit($coderef)>

Provide a $coderef that will be called I<after> interpreting an operation.
The $coderef will be passed the current L<Coeus::Interpreter::Environment>, the string
of the operations name, and the value that the operation evaluated to.

=item C<register($coderef)>

Perform both a L<register_entry($coderef)> and a L<register_exit($coderef)>.

=back

=head1 DIAGNOSTICS

There are not user visiable problems that can occur in this module.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
