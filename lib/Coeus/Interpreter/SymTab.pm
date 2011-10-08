package Coeus::Interpreter::SymTab;

use Moose;

has 'table' => (is => 'ro', isa => 'HashRef', default => sub { {} });
has 'parent' => (is => 'ro', isa => 'Coeus::Interpreter::SymTab');

sub bind {
    my ($self, $name, $value) = @_;

    $self->table->{$name} = $value;
}

sub unbind {
    my ($self, $name) = @_;

    delete $self->table->{$name} || ($self->parent && $self->parent->unbind($name));
}

sub bound {
    my ($self, $name) = @_;

    return (exists($self->table->{$name}) || ($self->parent && $self->parent->bound($name)));
}

sub lookup {
    my ($self, $name) = @_;
    
    return exists($self->table->{$name}) ? $self->table->{$name} : ($self->parent && $self->parent->lookup($name));
}

sub reverse_lookup {
    my ($self, $value) = @_;

    foreach my $sym (@{ $self->symbols }) {
        return $sym if $value == $self->lookup($sym);
    }

    return undef;
}

sub symbols {
    my ($self) = @_;
    
    my @symbols = keys %{ $self->table };
    push @symbols, @{ $self->parent->symbols } if $self->parent;

    return [_uniq(@symbols)];
}

sub _uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Interpreter::SymTab - A symbol table for tracking bindings

=head1 DESCRIPTION

This module provides a symbol table with a possible parent table.  This allows
lexical scoping of symbols in the table.

=head1 FUNCTIONS

=over 8

=item C<< bind($name => $value) >>

Bind a name to the given value.

=item C<unbind($name)>

Remove the binding for $name, if it exists

=item C<bound($name)>

Returns true if $name has been bound in this symtab.

=item C<lookup($name)>

Lookup a value by name

=item C<reverse_lookup($value)>

Lookup a name by value

=item C<symbols()>

Returns the list of symbols

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
