package Coeus::Model::System;

use Moose;
use Clone qw(clone);

use Coeus::Model::Configuration;
use Coeus::Model::Subscription;

has 'configuration' => (is => 'ro', isa => 'Coeus::Model::Configuration', default => sub { Coeus::Model::Configuration->new });
has 'subscriptions' => (is => 'ro', reader => '_subs_hash', isa => 'HashRef[Coeus::Model::Subscription]', default => sub { {} });
has 'landscapes' => (is => 'ro', reader => '_lands_hash', isa => 'HashRef[Coeus::Model::Landscape]', default => sub { {} });
has 'types' => (is => 'ro', reader => '_types_hash', isa => 'HashRef[CodeRef]', default => sub { {} });

sub subscriptions {
    my ($self) = @_;

    return [values %{ $self->_subs_hash }];
}

sub add_instance {
    my ($self, $instance, $subscription) = @_;

    $self->configuration->add_instance($instance);
    $self->recalc_capabilities;

    if($subscription) {
        $subscription->configuration->add_instance($instance);
        foreach my $use (@{ $self->configuration->find_usages(sub { $_->user == $instance }) }) {
            $subscription->configuration->add_use($use);
            $self->add_instance($use->provider, $subscription);
        }
    }
}

sub remove_instance {
    my ($self, $instance, $subscription) = @_;

    my @confs;
    if($subscription) {
        @confs = ($subscription->configuration);
    }
    else {
        @confs = map { $_->configuration } $self, @{ $self->subscriptions };
    }

    foreach my $conf (@confs) {
        $conf->remove_instance($instance);
        foreach my $use (@{ $conf->find_usages(sub { $_->user == $instance || $_->provider == $instance }) }) {
            $conf->remove_use($use);
        }
    }
}

sub stop {
    my ($self, $instance) = @_;
    $instance->stop;
    foreach my $use (@{ $self->configuration->find_usages(sub { $_->provider == $instance }) }) {
        $self->stop($use->user) if $use->type eq Coeus::Model::Use->HOST;
        $use->stop;
    }
    foreach my $use (@{ $self->configuration->find_usages(sub { $_->user == $instance }) }) {
        $use->stop;
    }
    $self->recalc_capabilities;
}

sub start {
    my ($self, $instance) = @_;
    $instance->start;
    foreach my $use (@{ $self->configuration->find_usages(sub { $_->provider == $instance }) }) {
        $self->start($use->user) if $use->type eq Coeus::Model::Use->HOST;
        $use->start;
    }
    foreach my $use (@{ $self->configuration->find_usages(sub { $_->user == $instance }) }) {
        $use->start;
    }
    $self->recalc_capabilities;
}

sub fail {
    my ($self, $thing) = @_;
    $thing->fail;
    foreach my $use (@{ $self->configuration->find_usages(sub { $_->provider == $thing }) }) {
        $self->fail($use->user) if $use->type eq Coeus::Model::Use->HOST;
        $use->fail;
    }
    foreach my $use (@{ $self->configuration->find_usages(sub { $_->user == $thing }) }) {
        $use->fail;
    }
    $self->recalc_capabilities;
}

sub add_use {
    my ($self, $use, $subscription) = @_;
   
    $self->configuration->add_use($use);

    if($subscription) {
        $subscription->configuration->add_use($use);
    }

    foreach my $sub (@{ $self->subscriptions }) {
        next if $subscription && $sub == $subscription;

        if(@{ $sub->configuration->find_instances(sub { $_ == $use->user }) } > 0) {
            $sub->configuration->add_use($use);
            $self->add_instance($use->provider, $sub);
        }
    }
}

sub remove_use {
    my ($self, $use) = @_;
    
    $self->configuration->remove_use($use);
    foreach my $sub (@{ $self->subscriptions }) {
        $sub->configuration->remove_use($use);
    }
}

sub add_subscription {
    my ($self, $landscape, $name) = @_;

    return $self->_subs_hash->{$name} = Coeus::Model::Subscription->new( {
        name => $name,
        landscape => $self->_lands_hash->{$landscape},
        configuration => Coeus::Model::Configuration->new
    });
}

sub remove_subscription {
    my ($self, $name) = @_;

    delete $self->_subs_hash->{$name};
}

sub lookup_subscription {
    my ($self, $name) = @_;

    return exists $self->_subs_hash->{$name} ? $self->_subs_hash->{$name} : undef;
}

sub add_landscape {
    my ($self, $land) = @_;

    return $self->_lands_hash->{$land->name} = $land;
}

sub lookup_landscape {
    my ($self, $name) = @_;

    return exists $self->_lands_hash->{$name} ? $self->_lands_hash->{$name} : undef;
}

sub add_type {
    my ($self, $name, $behavior) = @_;
    
    return $self->_types_hash->{$name} = $behavior;
}

sub lookup_type {
    my ($self, $name) = @_;

    return exists $self->_types_hash->{$name} ? $self->_types_hash->{$name} : undef;
}

sub recalc_capabilities {
    my ($self) = @_;

    my $one_changed = 1;
    while($one_changed) {
        $one_changed = 0;
        foreach my $inst (@{ $self->configuration->instances }) {
            $one_changed = $inst->recalc_capabilities($self) || $one_changed;
        }
        foreach my $use (@{ $self->configuration->uses }) {
            next if $use->type eq Coeus::Model::Use->HOST;
            if($use->running && !$use->provider->has_capability($use->type)) {
                $use->fail;
            }
            elsif($use->failed && $use->provider->has_capability($use->type)) {
                $use->restore;
            }
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Coeus::Model::System - Controls an entire System of Configurations in Coeus

=head1 SYNOPSIS

 use Coeus::Model::System;

 my $sys = Coeus::Model::System->new;

 ... TODO

=head1 DESCRIPTION

This class handles systems of configurations in Coeus. It is the main interface for adding
instances, uses, subscriptions, landscapes, and types.  It handles recalculating instance
behaviors (along with L<Coeus::Model::Instance>) whenever something is changed through its 
interface. NOTE: That means that when a parameter on an instance is changed (which does not
got through this interface) C<recalc_capabilities> should be called on the system!

The methods for adding, removing, starting, and stopping instances and uses ensure that
the configurations of subscriptions are updated appropriately.

=head1 METHODS

=over 8

=item C<configuration()>

Returns the system-wide configuration.

=item C<subscriptions()>

Returns an arrayref of the subscriptions in the system.

=item C<add_instance($instance[, $subscription])>

Add an instance to the system. If C<$subscription> is provided then
the instance will be added to the system configuration as well as
the subscription's configuration. Any usages and other instances will
also be put in the subscription, if needed.

=item C<remove_instance($instance[, $subscription])>

Remove an instance from the system. If C<$subscription> is provided, then
the instance will only be removed from the one subscription and not the entire system.
When the instance is removed any usages associated with it are also removed.

=item C<add_use($use[, $subscription])>

Add a use to the system. If C<$subscription> is provided then the use
is also added to the subscription's configuration.  All other subscriptions
in the system are also updated to contain any required instances that they
might need after the use is added.

=item C<remove_use($use)>

Remove a use from the system (including all subscriptions!).

NOTE: There is no form of C<remove_use> that takes a subscription
since removing a usage relationship (just like adding one) is system wide!

=item C<stop($use|$instance)>

Stop the use or instance. In the case of an instance all hosted
instances are also stopped and any uses in which the given instance
is the user are also stopped.

=item C<start($use|$instance)>

Start the use or instance. In the case of an instance all hosted 
instances are also started and any uses in which the given instance
is the user are also started.

NOTE: This makes quite an assumption about the lifecycles of hosted
instances!

=item C<add_subscription($landscape, $name)>

Create a new subscription to the given C<$landscape> with the given
C<$name>. Returns the new L<Coeus::Model::Subscription> object.

=item C<remove_subscription($name)>

Remove the subscription of the given C<$name>.

NOTE: This does not remove any instances or uses!

=item C<lookup_subscription($name)>

Return the L<Coeus::Model::Subscription> associated with
C<$name>.

=item C<add_landscape($landscape)>

Add the given C<$landscape> (a L<Coeus::Model::Landscape> object)
to the system.

=item C<lookup_landscape($name)>

Returns the L<Coeus::Model::Landscape> object for the landscape of the given
C<$name>.

=item C<add_type($name, $behavior)>

Add a type of the given C<$name> with the the given C<$behavior>
to the system.  The behavior is a coderef with the following signature:

 sub {
    my ($instance, $system) = @_;
    ...
 }

The behavior has no return type since it is expected to update the capabilities of C<$instance>
directly.

=item C<lookup_type($name)>

Returns the behavior function associated with the given 
C<$name>.

=item C<recalc_capabilities()>

Recalculate the capabilities of all instances in the system.

=back

=head1 DIAGNOSTICS

There are no errors thrown from this class.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
