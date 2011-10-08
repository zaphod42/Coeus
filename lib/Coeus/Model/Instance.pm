package Coeus::Model::Instance;

use Moose;

with 'Coeus::Model::Lifecycle';

my $ID_STATE = 0;
has 'id' => (is => 'ro', default => sub { "Instance_" . $ID_STATE++ });
has 'type' => (is => 'ro', required => 1, isa => 'Str');
has 'properties' => (is => 'ro', reader => 'properties_hash', isa => 'HashRef', default => sub { {} });
has 'capabilities' => (is => 'rw', default => sub { [] }, isa => 'ArrayRef[Str]');
has 'behavior' => (is => 'ro', isa => 'CodeRef', required => 1);

sub bind {
    my ($self, $name, $value) = @_;

    $self->properties_hash->{$name} = $value;
    return $value;
}

sub lookup {
    my ($self, $name) = @_;

    return $self->properties_hash->{$name};
}

sub properties {
    my ($self) = @_;

    return [keys %{ $self->properties_hash }];
}

sub clear_capabilities {
    my ($self) = @_;

    $self->capabilities([]);
}

sub add_capability {
    my ($self, $name) = @_;

    push @{ $self->capabilities }, $name
        unless $self->has_capability($name);
}

sub remove_capability {
    my ($self, $name) = @_;

    $self->capabilities([grep { $_ ne $name } @{ $self->capabilities }]);
}

sub has_capability {
    my ($self, $cap) = @_;

    return 0 < grep { $_ eq $cap } @{ $self->capabilities };
}

sub _different {
    my ($x, $y) = @_;

    return 1 if @$x != @$y;

    my @x = sort @$x;
    my @y = sort @$y;

    foreach my $a (@x) {
        my $b = shift @y;
        return 1 if $a ne $b;
    }
    return 0;
}

sub recalc_capabilities {
    my ($self, $system) = @_;

    # Copies are needed of the capabilities or else the
    # contents of the arrayrefs just change underneath us
    # and it looks like nothing has been changed
    my $original_caps = [@{ $self->capabilities }];

    my $behavior = $self->behavior;

    $self->clear_capabilities;
    return unless $self->running;

    my $last_caps = [@{ $self->capabilities }];
    my @seen_caps = ($last_caps);

    $behavior->($self, $system);
    my $new_caps = [@{ $self->capabilities }];

    while (_different($last_caps, $new_caps)) {
        $behavior->($self, $system);
        $last_caps = $new_caps;
        $new_caps  = [@{ $self->capabilities }];
        die "Loop detected when calculating capabilities of instance " . $self->id
            if grep { !_different($last_caps, $_) } @seen_caps;
        push @seen_caps, $last_caps;
    }

    return _different($new_caps, $original_caps);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Model::Instance - An instance of a type

=head1 SYNOPSIS

    use Coeus::Model::Instance;

    my $i = Coeus::Model::Instance->new({ type => 'Foo', behavior => sub { ... } });
    $i->recalc_capabilities($system);

    if($i->has_capability('a')) {
        print "$i can do a\n";
    }

=head1 DESCRIPTION

Represents an instance of a type in Coeus. An instance has parameters and a type which
determines the behavior of the instance.  The behavior provides the capabilities of the
instance which can then be used by other instances via L<Coeus::Model::Use>.

=head1 METHODS

=over 8

=item C<< new({ type => $type, behavior => $behavior, [ id => $id ] }) >>

Create a new instance of $type. The capabilities of the new instance
are calculated by the $bahavior coderef, which should have the form

    sub {
        my ($instance, $system) = @_;
        # call $instance->add_capability($str) to set the capabilities
        # of the $instance
    }

If an $id is provided the C<id> of the instance will be set to it, otherwise
it will default to an id of the form "Instanc_[number]".

=item C<< bind($name => $value) >>

Bind property $name to $value.

=item C<lookup($name)>

Returns the value of the property $name.

=item C<properties()>

Return an arrayref of all of the bound property names.

=item C<clear_capabilities()>

For use by the behaviors.

Clears the list of capabilities.

=item C<add_capability($cap)>

For use by the behaviors.

Add $cap to the list of capabilities. If $cap is already in the list 
of capabilities then nothing is done.

=item C<has_capability($cap)>

Returns true if $cap is in the list of capabilities and false otherwise.

=item C<recalc_capabilities($system)>

Recalculates the list of capabilities for the instance in the context
of the $system.

=back

=head1 DIAGNOSTICS

The C<recalc_capabilities> method can throw an error if it detects
a loop during the calculation of capabilities. A loop means that it
has seen the same set of capabilities twice during the run of calculation
and implies that there is no stable set of capabilities.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
