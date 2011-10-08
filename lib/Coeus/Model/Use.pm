package Coeus::Model::Use;

use Moose;

with 'Coeus::Model::Lifecycle';

use constant HOST => "____HOSTING_RELATIONSHIP____";

my $ID_STATE = 0;
has 'id' => (is => 'ro', default => sub { "Use_" . $ID_STATE++ });
has 'user' => (is => 'ro', required => 1, isa => 'Coeus::Model::Instance');
has 'provider' => (is => 'ro', required => 1, isa => 'Coeus::Model::Instance');
has 'type' => (is => 'ro', required => 1, isa => 'Str');

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Model::Use - A usage relationship in Coeus

=head1 SYNOPSIS

    use Coeus::Model::Use;

    my $inst1 = Coeus::Model::Instance->new({...});
    my $inst2 = Coeus::Model::Instance->new({...});

    # assuming $inst2->has_capability('foo') is true.
    my $use = Coeus::Model::Use->new({ user => $inst1, provider => $inst2, type => 'foo' });

=head1 DESCRIPTION

This class represents a usage relationship between two
L<Coeus::Model::Instance>s.  Usually the C<type> of the
use should be provided by the C<provider> instance, but
this class will not enforce that.

There is a special type of C<Coeus::Model::Use::HOST> that 
is used to represent hosting relationship between instances.

=head1 METHODS

=over 8

=item C<< new({ user => $user, provider => $provider, type => $type }) >>

Create a usage relationship from $user to $provider for the capabiliity $type 
that $provider has.  The created object will have a unique id, within the process
in which it is created.  That means that the id will not be unique between runs 
of Coeus.

=item C<id()>

Returns the id of the usage.  The id is a string of the form "Use_[number]".

=item C<user>

Returns the user of the usage.

=item C<provider>

Returns the provider of the usage.

=item C<type>

Returns the type of the usage or C<Coeus::Model::Usage::HOST> if this
is the special hosting relationship.

=back

=head1 DIAGNOSTICS

There are not user visible errors in this module.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
