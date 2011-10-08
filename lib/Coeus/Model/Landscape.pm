package Coeus::Model::Landscape;

use Moose;

has 'start' => (is => 'ro', required => 1, isa => 'Str');
has 'policies' => (is => 'ro', reader => '_policies', isa => 'HashRef', default => sub { {} });
has 'name' => (is => 'ro', required => 1, isa => 'Str');

sub add_policy {
    my ($self, $policy) = @_;

    $policy->landscape($self);
    $self->_policies->{$policy->name} = $policy;
}

sub policies {
    my ($self) = @_;

    return [keys %{ $self->_policies }];
}

sub policy {
    my ($self, $name) = @_;

    return $self->_policies->{$name};
}

sub resilient {
    my ($self, $name) = @_;

    return $self->_policies->{$name}->resilient;
}

__PACKAGE__->meta->make_immutable;

1;
