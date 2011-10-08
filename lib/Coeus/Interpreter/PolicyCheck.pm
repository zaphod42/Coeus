package Coeus::Interpreter::PolicyCheck;

use strict;
use warnings;
use Math::Combinatorics;
use List::Util qw(max);

use Coeus::Interpreter::AST qw();
use Coeus::Interpreter::Hook;
use Coeus::Interpreter;

my $in_atomic = 0;
Coeus::Interpreter::Hook::register_entry(
    sub { $in_atomic++ if $_[1] eq 'atomic_block' });
Coeus::Interpreter::Hook::register_exit(
    sub { $in_atomic-- if $_[1] eq 'atomic_block' });

Coeus::Interpreter::Hook::register_exit(\&_check_policies);

sub _check_policies {
    my ($env, $op) = @_;

    return unless Coeus::Interpreter::AST::modifies_configuration($op);
    return if $in_atomic;

    my $counterexample = _find_counterexample($env->system, 0);
    if ($counterexample) {
        die "Configuration does not conform to policy\n"
          . _stringify_counterexample($counterexample);
    }
}

sub _find_counterexample {
    my ($system) = @_;

    my @subscriptions = @{ $system->subscriptions };
    return if !@subscriptions;

    if(my $subscription = _check_subscriptions($system, 0)) {
        return [$subscription];
    }

    my $max_length =
      max map { $_->landscape->resilient($_->policy) } @subscriptions;

    foreach my $current_length (1 .. $max_length) {
        my $combinations = Math::Combinatorics->new(
            count => $current_length,
            data  => [
                @{$system->configuration->instances},
                grep { $_->type ne Coeus::Model::Use->HOST } @{ $system->configuration->uses }
            ]
        );

        while(my @failures = $combinations->next_combination) {
            my $failed_system = _fail_things($system, \@failures);
            if(my $subscription = _check_subscriptions($failed_system, scalar(@failures))) {
                return [@failures, $subscription];
            }
        }
    }

    return undef;
}

sub _check_subscriptions {
    my ($system, $num_failures) = @_;

    foreach my $subscription (@{ $system->subscriptions }) {
        next if $num_failures > $subscription->resilient;
        $subscription->reset_errors;
        
        if(!$subscription->check_policy($system)) {
            return $subscription;
        }
    }

    return;
}

sub _fail_things {
    my ($system, $failures) = @_;

    my $failed_system = $system->clone;
    my $conf = $failed_system->configuration;

    my %ids = map { $_->id => 1 } @$failures;
    my @copies = (
        @{$conf->find_instances(sub { exists $ids{$_->id} })},
        @{$conf->find_usages(sub    { exists $ids{$_->id} })}
    );

    foreach my $thing (@copies) {
        $failed_system->fail($thing);
        $failed_system->stop($thing);
    }

    return $failed_system;
}

sub _stringify_counterexample {
    my ($counterexample) = @_;
    my $str = "Counterexample: \n";

    my $inst = sub { $_[0]->type . ":" . $_[0]->id };

    if(@$counterexample > 1) {
        foreach my $thing (@$counterexample[0..$#$counterexample-1]) {
            $str .= "\t -> ";
            if ($thing->isa('Coeus::Model::Instance')) {
                $str .= "Instance(" . $inst->($thing) . ")\n";
            } else {
                $str .= "Use("
                  . $inst->($thing->user) . " -> "
                  . $thing->type . " "
                  . $inst->($thing->provider) . ")\n";
            }
        }
    }
    else {
        $str .= "\tNo failures needed\n";
    }

    foreach my $policy (@{ $counterexample->[-1]->policy_errors }) {
        $str .=
            "failed in the policy "
          . $policy->name;
        $str .= "(" . $policy->comment . ")" if defined $policy->comment;
        $str .= "\n";
    }
    $str .= "for subscription "
    . $counterexample->[-1]->name . "\n";

    return $str;
}

1;

__END__

=head1 NAME

Coeus::Interpreter::PolicyCheck - Check that all policies in effect hold

=head1 DESCRIPTION

This module should not be used directly. It is a hook into the interpretation via
C<Coeus::Interpreter::Hook>.

This module checks that each subscription's current policy holds in the subscription's configuration
by executing the following algorithm:

    $max_failures = max resiliency of all subscriptions
    for $num_failures = 0 to $max_failures
        @relevent_parts = (all instances in system, 
                           all usages in system 
                             - hosting usages in system)
        @failure_groups = choose $num_failures from @relevent_parts
        foreach @group in @failure_groups
            $cloned = clone the system
            fail each element of @group in $cloned
            foreach $policy in currently active policies
                skip if $policy resiliency < $num_failures
                error if $policy does not hold in $cloned

This algorithm checks all possible combinations of failures in the system up to the maximum resiliency needed.
Combinations of failures can be used, as opposed to permutations, because the model used for the configurations does
not have any kind of order dependency for behaviors.  This drastically cuts down the size of the configuration space that
needs to be checked and makes the checking of the policies achievable in a reasonable amount of time for reasonable input.

=head1 DIAGNOSTICS

If a subscription is found for which the policy does not hold and exception is thrown.  The
exception is a simple string of the format (text in [] are comments about the format and not a
part of the format!):

    Configuration does not conform to policy
    Counterexample: 
        No failures needed
        [ or a sequence of ]
        -> Instance([ $instance_id ])
        -> Use([ $user_id ] -> [ $use_type ] [ $provider_id ])
        [ ... and so on ]
    failed in the policy [ $policy_name ]([ $policy_comment ])
    [ ... from the most to the least deeply nested policy ... ]
    for subscription [ $subscription_name ]

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew Parker (aparker42@gmail.com)

Patches are welcome.

=head1 AUTHOR

Andrew Parker (aparker42@gmail.com)

=head1 LICENSE AND COPYRIGHT

*TODO: probably something from IBM*

=cut
