package Coeus::Model::Subscription;

use Moose;

has 'landscape' => (is => 'ro', isa => 'Coeus::Model::Landscape', required => 1);
has 'configuration' => (is => 'ro', isa => 'Coeus::Model::Configuration', required => 1);
has 'policy' => (is => 'rw', isa => 'Str', lazy => 1, default => sub { $_[0]->landscape->start });
has 'name' => (is => 'ro', required => 1, isa => 'Str');
has 'policy_errors' => (is => 'ro', default => sub { [] });

sub check_policy {
    my ($self, $system) = @_;
    return $self->landscape->policy($self->policy)->eval($self, $system);
}

sub resilient {
    my ($self) = @_;
    return $self->landscape->resilient($self->policy);
}

sub reset_errors {
    my ($self) = @_;
    $self->{policy_errors} = [];
}

sub add_error {
    my ($self, $policy) = @_;
    push @{ $self->policy_errors }, $policy;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Model::Subscription - A subscription to a landscape in Coeus

=head1 SYNOPSIS

    # Example code

=head1 DESCRIPTION

This class represents a subscription to a landscape in the Coeus
language. A subscription has a current policy, which is one of the policies
of the landscape, and a configuration.

The subscription can check itself for conformance to its policy
and provides a report of which policies were found to not
hold. There can be more than one policy not holding because
policies can be composed.

=head1 METHODS

=over 8

=item C<landscape()>

Returns the L<Coeus::Model::Landscape> of the subscription.

=item C<configuration()>

Returns the L<Coeus::Model::Configuration> of the subscription.

=item C<policy([$name])>

Get/Set the (name of the) current policy of the subscription.

=item C<name()>

Returns the name of the subscription.

=item C<policy_errors()>

Returns an arrayref of the policies that failed the last time
that L<check_policy> was called.

=item C<check_policy($system)>

Check that the current policy holds in the given C<$system>.
Returns true or false depending on whether the policy held or not.

=item C<resilient()>

Returns the resiliency of the current policy.

=item C<reset_errors()>

Clear the L<policy_errors> list.  This should be called
before L<check_policy> is attempted.

=item C<add_error($policy)>

Add the C<$policy> to the list of policy errors.

=back

=head1 DIAGNOSTICS

There are no errors that can be thrown from this class.

When policies are checked the list of policies that did
not hold can be found from the L<policy_errors> method.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
