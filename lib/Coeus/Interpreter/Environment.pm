package Coeus::Interpreter::Environment;

use Moose;

use Coeus::Interpreter::SymTab;
use Coeus::Model::System;

# The currently active configuration. The one that commands will work on
has 'subscription' => (is => 'rw', isa => 'Maybe[Coeus::Model::Subscription]');

# The entire system
has 'system' => (
    is      => 'rw',
    isa    => 'Coeus::Model::System',
    default => sub { Coeus::Model::System->new },
    handles => [
        'add_type',            'lookup_type',
        'add_landscape',       'lookup_landscape',
        'add_subscription',    'lookup_subscription',
        'remove_subscription', 'subscriptions',
        'stop', 'start',
    ]
);
has 'actions' => (
    is      => 'ro',
    isa    => 'Coeus::Interpreter::SymTab',
    default => sub { Coeus::Interpreter::SymTab->new },
    handles => {add_action => 'bind', lookup_action => 'lookup'}
);

# The current symbol table of variables
has 'symtab' => (
    is      => 'ro',
    isa    => 'Coeus::Interpreter::SymTab',
    default => sub { Coeus::Interpreter::SymTab->new },
    handles => ['bind', 'lookup', 'bound']
);

# Determines if the environment is 'restricted.' Restricted environments
# limit access to certain things such as configuration changing actions
# and usages queries for inactive usage relationships (the relationships will
# simply not be visible in a restricted environment).
has 'restricted' => (
    is      => 'ro',
    isa    => 'Bool',
    default => 0
);

sub BUILD {
    my ($self, $args) = @_;

    if(my $base = ($args->{base} || $args->{parent})) {
        $self->{restricted} = exists $args->{restricted} ? $args->{restricted} : $base->restricted;
        $self->{actions} = $base->actions;
        $self->{system} = exists $args->{system} ? $args->{system} : $base->system;
        $self->{subscription} = $base->subscription unless $args->{subscription};

        if($args->{parent}) {
            $self->{symtab} = Coeus::Interpreter::SymTab->new({ parent => $base->symtab });
        }
    }
}

sub current_configuration {
    my ($self) = @_;

    if($self->subscription) {
        return $self->subscription->configuration;
    }
    else {
        return $self->system->configuration;
    }
}

sub add_use {
    my ($self, $use) = @_;

    $self->system->add_use($use, $self->subscription);
    $self->system->recalc_capabilities;
}

sub remove_use {
    my ($self, $use) = @_;

    $self->system->remove_use($use);
}

sub find_usages {
    my ($self, $matcher) = @_;

    return $self->current_configuration->find_usages($matcher);
}

sub add_instance {
    my ($self, $instance) = @_;

    $self->system->add_instance($instance, $self->subscription);
}

sub remove_instance {
    my ($self, $instance) = @_;

    $self->system->remove_instance($instance, $self->subscription);
}

sub find_instances {
    my ($self, $matcher) = @_;

    return $self->current_configuration->find_instances($matcher);
}

sub remove {
    my ($self, $thing) = @_;

    $self->remove_use($thing) if $thing->isa('Coeus::Model::Use');
    $self->remove_instance($thing) if $thing->isa('Coeus::Model::Instance');

    my $symbol = $self->symtab->reverse_lookup($thing);
    if($symbol) {
        $self->symtab->unbind($symbol);
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Interpreter::Environment - Evaluation environment for the Coeus interpreter

=head1 DESCRIPTION

This module should not be used directly.  It is used by the Coeus interpretation in 
L<Coeus::Interpreter::Commands>.  Look at those for examples of usage.

This module represents the evaluation environment of a section of the Coeus language.
Environments contain the current bindings for variables and actions, tracks the currently
active configuration (the one that will be changed by executing commands), and tracks if it is
a restricted environment or not.  

A large amount of the interface is simply delegated to the appropriate object that is tracked by
the environment.  For example C<lookup_subscription> and friends are all handled by the C<system>.

=head1 FUNCTIONS

=over 8

=item C<new({ [base|parent => $env], [restricted => $bool], [subscription => $subscription], [system => $system] })>

Create a new C<Coeus::Interpreter::Environment>. The base parameter creates a new environment that is based off of
the given environment, but does not use it as a lexical parent for the purpose of variable lookup.  The parent parameter
creates a lexically enclosed environment of the given environment.  In both cases the new environment will have the
same system (unless overridden), subscripiton (unless overridden), actions, and restriction as the other environement.  The
parent is used for variable lookup only (actions and such are only globally scoped).

=item C<current_configuration()>

Returns the currently active configuration.

=item C<subscription([$subscription])>

Get/Set the currently active subscription (see L<Coeus::Model::Subscription>).  If there is a subscription set then the
C<current_configuration> will the be configuration of the subscription, otherwise
it will be the configuration of the C<system>.

=item C<system([$system])>

Get/Set the system (see L<Coeus::Model::System>).

=item C<restricted()>

Returns if the environment represents a "restricted" environment.  Restricted environments
limit the visibility of certain elements of the configuration.

=item C<remove($thing)>

Remove either a L<Coeus::Model::Instance> or L<Coeus::Model::Use> from the current configuration.  See
the semantics of L<remove_use> and L<remove_instance> for the exact meaning of removing something.
In addition to the removal of the C<$thing> from the system, any references in the symbol table will
also be removed!

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
