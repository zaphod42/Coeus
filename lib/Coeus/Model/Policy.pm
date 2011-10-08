package Coeus::Model::Policy;

use Moose;
use List::Util;

has 'landscape' => (is => 'rw', isa => 'Coeus::Model::Landscape', weak_ref => 1);
has 'min_resilient' => (is => 'ro', isa => 'Int');
has 'ast' => (is => 'ro');
has 'name' => (is => 'ro', isa => 'Str');
has 'code' => (is => 'ro', isa => 'CodeRef');
has 'comment' => (is => 'ro', isa => 'Maybe[Str]');

sub resilient {
    my ($self) = @_;
    return _max_depth($self->ast, $self->min_resilient, $self->landscape);
}

sub eval {
    my ($self, $subscription, $system) = @_;
    return $self->code->($subscription, $system);
}

sub _max_depth {
    my ($policy_ast, $min, $landscape) = @_;

    if($policy_ast->[0] eq 'binop') {
        if($policy_ast->[1] eq '||') {
            return List::Util::min($min, _max_depth($policy_ast->[2], $min, $landscape), _max_depth($policy_ast->[3], $min, $landscape));
        }
        else { # &&, ==, !=, <=, etc.
            return List::Util::max($min, _max_depth($policy_ast->[2], $min, $landscape), _max_depth($policy_ast->[3], $min, $landscape));
        }
    }
    elsif($policy_ast->[0] eq 'uniop') {
        return List::Util::max($min, _max_depth($policy_ast->[2], $min, $landscape));
    }
    elsif($policy_ast->[0] eq 'policy_ref') {
        return List::Util::max($min, $landscape->policy($policy_ast->[1]->[1])->resilient);
    }
    else {
        return $min;
    }
}

1;

__END__

=head1 NAME

Coeus::Model::Policy - A policy of a Coeus::Model::Landscape

=head1 SYNOPSIS

    use Coeus::Model::Policy;

    my $pol = Coeus::Model::Policy->new({ ... });
    if(!$pol->eval($subscription, $system)) {
        print "The policy does not hold!\n";
    }

=head1 DESCRIPTION

This model handles the representation and, to some extent,
the checking of policies for L<Coeus::Model::Landscape>s. A policy is,
at its core, just a boolean expression in Coeus that is evaluated in the 
context of a L<Coeus::Model::Subscription>.  In addition to the basic
boolean expressions of Coeus, though, a policy can also contain references
to other policies. 

Each policy has a "resiliency" associated with it.  This number
represents the number of either L<Coeus::Model::Instance>s or
L<Coeus::Model::Use>s that can "fail" and the policy must still
evaluate to true.  Because of the compositionality of policies, however, the 
resiliency of a policy will not always be exactly what is specified in
the Coeus source.

The "resilient" attribute in Coeus source specifies the I<minimum> number
of failures after which the policy must still hold.  Because of the ability
to compose policies, this is not always the number of failures that will
actually be checked.  The actuall resiliency of the policy is calculated as:

    res(e1 || e2)  = min(res(e1), res(e2), m)
    res(e1 bop e2) = max(res(e1), res(e2), m)
    res(uop e1)    = max(res(e1), m)
    res(p)         = max(res(p), m)
    res(e1)        = m

where C<m> is the minimum resiliency, C<bop> is a binary operator (e.g. &&, ==, !=, etc.),
C<uop> is a unary operator, C<e1> and C<e2> are Coeus boolean expressions, and C<p> is a policy
reference.

=head1 METHODS

=over 8

=item C<< new({ min_resilient => $min, ast => $ast, name => $name, code => $coderef, comment => $comment }) >>

Create a new policy object named $name with a minimum resiliency of $min.  The policy is described by the $ast
and is evaluated by the $coderef.

The $coderef is of the form:

    sub {
        my ($subscription, $system) = @_;
        # return true or false based on $subscription and $system
    }

=item C<landscape($land)>

Set the landscape that contains this policy.  This landscape is then used during the
calculation of the resiliency to lookup other policies.

=item C<eval($subscription, $system)>

Evaluate the policy in the given $subscription and $system. Returns the result of the
policy (either true or false).

=item C<resilient()>

Calculate and return the actual resiliency of the policy using
the algorithm described above.

=back

=head1 DIAGNOSTICS

There are no use visible errors from this module.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
