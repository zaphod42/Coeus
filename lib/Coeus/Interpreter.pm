package Coeus::Interpreter;

use Moose;

use Coeus::Interpreter::Environment;
use Coeus::Interpreter::Commands;
use Coeus::Interpreter::PolicyCheck;
use Coeus::Interpreter::Grammar;

my $parser = Coeus::Interpreter::Grammar->new;

sub parse {
    my ($self, $text) = @_;

    $parser->{hidden_errors} = undef;
    my $ast = $parser->coeus($text)
      or die(["Unable to parse\n", undef]);

    return $ast;
}

sub eval {
    my ($self, $ast, $env) = @_;
    return Coeus::Interpreter::Commands::coeus_eval($ast, $env);
}

sub execute {
    my ($self, $ast, $env) = @_;

    $env ||= Coeus::Interpreter::Environment->new();
    $self->eval($ast, $env);

    return $env;
}

sub run {
    my ($self, $text, $env) = @_;

    my $ast = $self->parse($text);
    return $self->execute($ast, $env);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Interpreter - Interpreter interface for Coeus

=head1 SYNOPSIS

   use Coeus::Interpreter;

   my $interp = Coeus::Interpreter->new;

   my $resulting_env = $interp->run(<<Coeus);
      type A {}
      ![A]
   Coeus

=head1 METHODS

=over 8

=item C<parse($text) : $ast>

Parse the C<$text> of Coeus and return the corrosponding AST.

=item C<eval($ast, $env) : $value>

Interpret the C<$ast> in the given C<$env> and return the C<$value> that it evaluates to.

=item C<execute($ast, [$env]) : $env>

Interpret the C<$ast> and return the resulting C<$env>.
An C<$env> of L<Coeus::Interperter::Environment> can be provided in which the
interpretation will take place, otherwise a new, blank environment will
be created.

=item C<run($text, [$env]) : $env>

Parse and then interpret C<$text> and return the resulting C<$env>.
An C<$env> of L<Coeus::Interperter::Environment> can be provided in which the
interpretation will take place, otherwise a new, blank environment will
be created.

=back

=head1 DIAGNOSTICS

Errors are thrown from instances in for form of array references.  The first
element of the array is the text of the message and the second is the environment
(L<Coeus::Interpreter::Environment>) that was being used when the error occured.

In the case of a parse error the environment part will be undef.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

For performance all instances share the same parser.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut

