package Coeus::Model::Configuration;

use Moose;

has 'instances' => (is => 'rw', isa => 'ArrayRef[Coeus::Model::Instance]', default => sub { [] });
has 'uses' => (is => 'rw', isa => 'ArrayRef[Coeus::Model::Use]', default => sub { [] });

sub add_instance {
    my ($self, $instance) = @_;

    push @{ $self->instances }, $instance
        unless @{ $self->find_instances(sub { $_ == $instance }) };
}

sub remove_instance {
    my ($self, $instance) = @_;

    $self->instances($self->find_instances(sub { $_ != $instance }));
}

sub add_use {
    my ($self, $use) = @_;

    push @{$self->uses}, $use unless @{$self->find_usages(sub { $_ == $use })};
}

sub remove_use {
    my ($self, $use) = @_;

    $self->uses($self->find_usages(sub { $_ != $use }));
}

sub find_usages {
    my ($self, $matcher) = @_;

    return [grep { $matcher->() } @{ $self->uses }];
}

sub find_instances {
    my ($self, $matcher) = @_;

    return [grep { $matcher->() } @{ $self->instances }];
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Model::Configuration - A Coeus Configuration (contains Uses and Instances)

=head1 SYNOPSIS

 use Coeus::Model::Configuration;

 my $conf = Coeus::Model::Configuration->new;
 
 # To search through instances
 my $found_instances = $conf->find_instances(sub { ... });

 # To search through uses
 my $found_uses = $conf->find_uses(sub { ... });

=head1 DESCRIPTION

The class represents a configuration (either for a single L<Coeus::Model::Subscription>
or for an entire L<Coeus::Model::Subscription>).  For the most part it is simply
a container for L<Coeus::Model::Use>s and L<Coeus::Model::Instance>s, and provides
methods to manipulate and search the same.

This module does not enforce any of the constraints that should be on
configurations (mainly, that all uses refer to instances in the configuration).
This is because configurations should usually be dealt with inderectly through
L<Coeus::Model::System>s which have the information to enforce those constraints.

=head1 METHODS

=over 8

=item C<instances()>

Return an arrayref of the instances in the configuration.

=item C<add_instance($instance)>

Add an instance to the configuration. If $instance already
exists in the configuration (determined by reference equality, 
not by the id of the instance) then it will not be added again.

=item C<remove_instance($instance)>

Removes the instance from the configuration.  The instance to remove
is determined by reference, not by the instance's id.

=item C<find_instances($coderef)>

C<grep> for instances.

Calls $coderef for each instance and returns an arrayref
of the instances for which the $coderef returned true. C<$_>
is set to each instance in turn.

=item C<uses()>

Return an arrayref of the instances in the configuration.

=item C<add_use($use)>

Add an instance to the configuration. If $use already exists
in the configuration (determined by reference equality,
not by the id of the use) then it will not be added again.

=item C<remove_use($use)>

Removes the use from the configuration.  The use to remove
is deteremined by reference, not by the use's id.

=item C<find_usages($coderef)>

C<grep> for uses.

Calls $coderef for each instance and returns an arrayref
of the uses for which the $coderef returned true. C<$_>
is set to each intance in turn.

=back

=head1 DIAGNOSTICS

There are no erros thrown from this class.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
