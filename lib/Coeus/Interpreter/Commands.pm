package Coeus::Interpreter::Commands;

use strict;
use warnings;
use Scalar::Util qw(refaddr);

use Coeus::Model::Use;
use Coeus::Model::Instance;
use Coeus::Model::Policy;
use Coeus::Model::Landscape;

use Coeus::Interpreter;
use Coeus::Interpreter::Environment; 
use Coeus::Interpreter::Hook;

sub error {
    my ($msg, $env, $line) = @_;
    if(defined($line)) {
        die ["ERROR: $msg (line $line)\n", $env];
    }
    else {
        die ["ERROR: $msg\n", $env];
    }
}

my %normal_forms = ();
sub make_normal_form {
    my ($op, $code) = @_;
    
    $normal_forms{$op} = $code;
}

my %special_forms = ();
sub make_special_form {
    my ($op, $code) = @_;
    
    $special_forms{$op} = $code;
}

sub coeus_eval {
    my ($expr, $env) = @_;

    my $uid = refaddr($expr); # assuming that we never dispose of expressions...
    my $op = $expr->[0];
    my @args = @$expr[1 .. $#$expr-1];
    my $line = $expr->[-1];

    eval { Coeus::Interpreter::Hook::signal_entry($env, $op, $uid); };
    error($@, $env) if $@;

    my (@eval_args, $f);
    if(exists $normal_forms{$op}) {
        @eval_args = map { defined $_ ? coeus_eval($_, $env) : undef } @args;
        $f = $normal_forms{$op};
    }
    elsif(exists $special_forms{$op}) {
        @eval_args = @args;
        $f = $special_forms{$op};
    }
    else {
        error("Encountered unknown operation $op!", $env);
    }

    my $r = $f->($env, @eval_args, $line);

    eval { Coeus::Interpreter::Hook::signal_exit($env, $op, $uid, $r, @eval_args); };
    error($@, $env) if $@;

    return $r;
}

########################################
# Special Forms: Declarations
########################################
make_special_form('action_decl', sub {
    my ($env, $name_expr, $parameter_exprs, $body) = @_;
    my $name = coeus_eval($name_expr, $env);
    $env->add_action($name => { parameters => [map { coeus_eval($_, $env) } @$parameter_exprs], body => $body });
});

make_special_form('type_decl', sub {
    my ($env, $name_expr, $behavior_expr) = @_;

    my $name = coeus_eval($name_expr, $env);
    # types are evaled in the system environment (ie. outside subscriptions) and without any symbol table
    my $type_env = Coeus::Interpreter::Environment->new({ base => $env, restricted => 1, subscription => undef });
    $env->add_type($name => sub { 
        my ($instance, $system) = @_;
        $type_env->bind('_' => $instance);
        $type_env->system($system);
        coeus_eval($behavior_expr, $type_env); 
    });
});

make_special_form('landscape_decl', sub {
    my ($env, $name_expr, $policy_exprs) = @_;

    my $name = coeus_eval($name_expr, $env);
    my @policies = map { coeus_eval($_, $env) } @$policy_exprs;

    my @defaults = grep { $_->[0] } @policies;
    error("More than one default policy defined in landscape $name", $env)
      if @defaults > 1;

    my $default = $defaults[0]->[1]->name;
    my $land = Coeus::Model::Landscape->new({ start => $default, name => $name });

    foreach my $policy (map { $_->[1] } @policies) {
        $land->add_policy($policy); 
    }

    $env->add_landscape($land);
});

make_special_form('policy_decl', sub {
    my ($env, $default, $name_expr, $policy_expr, $attributes) = @_;

    my $name = coeus_eval($name_expr, $env);
    my $policy_env =
      Coeus::Interpreter::Environment->new({base => $env, restricted => 1});
    my $policy;
    $policy = Coeus::Model::Policy->new(
        {
            ast           => $policy_expr,
            min_resilient => defined $attributes->{resilient}
            ? coeus_eval($attributes->{resilient}, $env)
            : 0,
            comment => defined $attributes->{comment}
            ? coeus_eval($attributes->{comment}, $env)
            : undef,
            name => $name,
            code => sub {
                my ($subscription, $system) = @_;
                $policy_env->system($system);
                $policy_env->subscription($subscription);
                listify(coeus_eval($policy_expr, $policy_env))
                  ? 1
                  : do { $subscription->add_error($policy); 0; };
            },
        }
    );
    return [$default, $policy];
});


########################################
# Special Forms: Value Construction
########################################
make_special_form('identifier', sub {
    my ($env, $name) = @_;
    return $name;
});

make_special_form('list', sub {
    my ($env, $elements) = @_;
    return [map { coeus_eval($_, $env) } @$elements];
});

make_special_form('literal', sub {
    my ($env, $value) = @_;

    if($value =~ /^['"](.*)['"]$/) {
        my $string = $1;
        $string =~ s/\\(["'])/$1/g;
        return $string;
    }
    else {
        return $value 
    }
});


########################################
# Special Forms: Flow Control
########################################

# needs to be a special form to be able to do
# short-circuiting
my %binop_funcs;
my %binop_undef = (
    '+' => 0,
    '-' => 0,
    '*' => 0,
    '/' => 0,
    '==' => '{}',
    '>=' => '{}',
    '<=' => '{}',
    '>' => '{}',
    '<' => '{}',
    'eq' => '{}',
    'ne' => '{}',
    'lt' => '{}',
    'gt' => '{}',
    'lte' => '{}',
    'gte' => '{}',
);
make_special_form('binop', sub {
    my ($env, $op, $left_expr, $right_expr) = @_;

    # string concat is ~ in Coeus but . in Perl
    if($op eq '~') {
        $op = '.';
    }

    my $f;
    if(exists $binop_funcs{$op}) {
        $f = $binop_funcs{$op};
    }
    else {
        # Instead of dispatching on the op we'll just construct
        # some perl to eval this for us.  This also will give us
        # the short circuiting.

        my $undef = exists $binop_undef{$op} ? $binop_undef{$op} : 'undef';
        $f = eval <<CODE;
sub {
    my (\$env, \$left_expr, \$right_expr) = \@_;
do { 
    my \$left = coeus_eval(\$left_expr, \$env);
    defined(\$left) ? listify(\$left) : $undef
}
$op 
do {
    my \$right = coeus_eval(\$right_expr, \$env);
    defined(\$right) ? listify(\$right) : $undef
}
}
CODE
        $binop_funcs{$op} = $f;
    }

    return $f->($env, $left_expr, $right_expr);
});

make_special_form('topic_block', sub {
    my ($env, $topic_expr, $block_expr) = @_;

    my $topic = coeus_eval($topic_expr, $env);

    foreach (listify($topic)) {
        my $block_env = Coeus::Interpreter::Environment->new({ parent => $env });
        $block_env->bind('_' => $_);
        coeus_eval($block_expr, $block_env);
    }
    
    return $topic;
});

make_special_form('map', sub {
    my ($env, $topic_expr, $block_expr) = @_;

    my @r = map { 
        my $block_env = Coeus::Interpreter::Environment->new({ parent => $env });
        $block_env->bind('_' => $_);
        coeus_eval($block_expr, $block_env);
    } listify(coeus_eval($topic_expr, $env));

    return @r > 1 ? \@r : $r[0];
});

make_special_form('sequence', sub {
    my ($env, $commands) = @_;
    
    my $value;
    foreach my $command (@$commands) {
        $value = coeus_eval($command, $env);
    }
    
    return $value;
});

make_special_form('condition', sub {
    my ($env, $condition, $capability, $uncapability) = @_;
    
    my $bool = coeus_eval($condition, $env);
    if(listify($bool)) {
        return coeus_eval($capability, $env);
    }
    else {
        return coeus_eval($uncapability, $env);
    }
});

########################################
# Normal Forms
########################################
make_normal_form('install', sub {
    my ($env, $instance, $host) = @_;
    
    my $existing_host_relationships = $env->find_usages(
        sub {
            $_->user->id  eq $instance->id
              && $_->type eq Coeus::Model::Use->HOST;
        }
    );

    if (grep { $_->provider != $host } @$existing_host_relationships) {
        error('Attempted to install ' . $instance->id . ' on more than one host.', $env);
    }

    $env->add_use(
        Coeus::Model::Use->new(
            {
                user     => $instance,
                provider => $host,
                type     => Coeus::Model::Use->HOST
            }
        )
    ) unless @$existing_host_relationships;

    return $instance;
});

my %uniop_funcs;
make_normal_form('uniop', sub {
    my ($env, $op, $expr) = @_;

    my $f;
    if(exists $uniop_funcs{$op}) {
        $f = $uniop_funcs{$op};
    }
    else {
        $f = eval "sub { $op \$_[0] }";
        $uniop_funcs{$op} = $f;
    }

    return $f->($expr);
});


# atomic bocks simply provide a place for hooks
# too see
make_normal_form('atomic_block', sub {
    my ($env, $commands_return) = @_;
    return $commands_return;
});

make_normal_form('bind', sub {
    my ($env, $value, $target) = @_;

    my ($symtab, $var) = @{ $target };

    my $r = $symtab->bind($var => $value);
    $env->system->recalc_capabilities;
    return $r;
});

make_normal_form('call', sub {
    my ($env, $name, $args, $line) = @_;

    my $sub = $env->lookup_action($name);
    error("Call to undefined action $name", $env, $line) unless $sub;

    my $new_env = Coeus::Interpreter::Environment->new({ base => $env });

    my @args = @$args;
    foreach my $name (@{ $sub->{parameters} }) {
        $new_env->bind($name => shift(@args));
    }
    
    my $return = coeus_eval($sub->{body}, $new_env);

    return $return;
});

make_normal_form('deref', sub {
    my ($env, $ref) = @_;

    my ($symtab, $var) = @{ $ref };
    
    return $symtab->lookup($var);
});

make_normal_form('commission', sub {
    my ($env, $type, $id, $line) = @_;
    
    error("Reference to undefined type $type", $env, $line) unless $env->lookup_type($type);

    my $instance;

    my $instances;
    if(defined $id && @{ $instances = $env->system->configuration->find_instances(sub { $_->type eq $type && $_->id eq $id }) } > 0) {
        $instance = $instances->[0];
    }
    else {
        my $args = { type => $type, behavior => sub { $env->lookup_type($type)->(@_) } };
        $args->{id} = $id if defined $id;
        $instance = Coeus::Model::Instance->new($args);
    }

    $env->add_instance($instance);

    return $instance;
});

make_normal_form('decommission', sub {
    my ($env, $instance) = @_;
    
    $env->remove($_) for (listify($instance));
});

make_normal_form('stop_instance', sub {
    my ($env, $instance) = @_;

    $env->stop($_) for (listify($instance));

    return $instance;
});

make_normal_form('start_instance', sub {
    my ($env, $instance) = @_;

    $env->start($_) for (listify($instance));

    return $instance;
});

make_normal_form('propref', sub {
    my ($env, $var, $property) = @_;

    return [$env->lookup($var), $property];
});

make_normal_form('varref', sub {
    my ($env, $var) = @_;
    return [$env->symtab, $var];
});

make_normal_form('use', sub {
    my ($env, $users, $providers, $type, $line) = @_;

    my @uses;
    foreach my $user (listify($users)) {
        foreach my $provider (listify($providers)) {
            error("Cannot use $type. It is not provided by the target.", $env, $line)
                unless $provider->has_capability($type);
    
            my $use = Coeus::Model::Use->new(
                {
                    user     => $user,
                    provider => $provider,
                    type     => $type
                }
            );
            push @uses, $use;
        }
    }

    $env->add_use($_) for (@uses);

    return @uses > 1 ? \@uses : $uses[0];
});

make_normal_form('capability', sub {
    my ($env, $name) = @_;

    $env->lookup('_')->add_capability($name);
});

make_normal_form('uncapability', sub {
    my ($env, $name) = @_;

    $env->lookup('_')->remove_capability($name);
});

make_normal_form('capability_filter', sub {
    my ($env, $capability) = @_;
    return sub { $_[0]->type eq $capability };
});

make_normal_form('identity_filter', sub {
    my ($env, $instances) = @_;
    my %have_instance = map { $_->id => 1 } listify($instances);
    return sub { exists $have_instance{$_[0]->id} };
});

make_normal_form('type_filter', sub {
    my ($env, $type, $id) = @_;

    return sub { $_[0]->type eq $type && ($id && $_[0]->id eq $id || !$id) };
});

# exception to the other filters because the expression needs to be delayed
make_special_form('expression_filter', sub {
    my ($env, $expression) = @_;

    my $local_env = Coeus::Interpreter::Environment->new({parent => $env});
    return sub {
        my ($thing) = @_;
        $local_env->bind('_', $thing);
        return coeus_eval($expression, $local_env);
    };
});

make_normal_form('wildcard_filter', sub {
    return sub { 1 };
});

make_normal_form('instance_query', sub {
    my ($env, $instance_filter, $filter) = @_;

    return $env->find_instances(sub { $instance_filter->($_) && $filter->($_) });
});

make_normal_form('use_query', sub {
    my ($env, $user_filter, $provider_filter, $type_filter, $filter) = @_;

    my $restricted = $env->restricted;

    return $env->find_usages(sub {
                 $type_filter->($_)
              && (($restricted && $_->running) || !$restricted)
              && $provider_filter->($_->provider)
              && $user_filter->($_->user)
              && $filter->($_);
          });
});

make_normal_form('install_instance_query', sub {
    my ($env, $hosts, $instances) = @_;

    my %have_host = map { $_->id => 1 } listify($hosts);
    my @hosted_instances = map { $_->user } @{
        $env->find_usages(
            sub {
                $_->type eq Coeus::Model::Use->HOST
                  && exists $have_host{$_->provider->id};
            }
        )
      };

    return _intersect(\@hosted_instances, $instances);
});

make_normal_form('install_host_query', sub {
    my ($env, $hosts, $instances, $filter) = @_;

    my %have_instance = map { $_->id => 1 } listify($instances);
    my @hosting_instances = map { $_->provider } @{
        $env->find_usages(
            sub {
                $_->type eq Coeus::Model::Use->HOST
                  && exists $have_instance{$_->user->id};
            }
        )
      };

    return [grep { $filter->($_) } @{ _intersect(\@hosting_instances, $hosts) }];
});

make_normal_form('inclusion_query', sub {
    my ($env, $members, $universe) = @_;

    return scalar(@{ _intersect($members, $universe) });
});

sub _intersect {
    my ($a, $b) = @_;
    my %seen;
    my @intersect;
    foreach my $e (listify($a), listify($b)) { 
        if(++$seen{$e->id} > 1) {
            push @intersect, $e;
        }
    }

    return \@intersect;
}

make_normal_form('can', sub {
    my ($env, $capability) = @_;

    return $env->lookup('_')->has_capability($capability);
});

make_normal_form('include', sub {
    my ($env, $filename) = @_;

    my $text = do {
        local $/;
        open my($fh), $filename or error("Unable to include $filename: $!", $env);
        <$fh>;
    };

    my $interp = Coeus::Interpreter->new();
    eval { $interp->run($text, $env); };
    if($@) {
        error("While including '$filename': $@->[0]", $env);
    }
});

make_normal_form('policy_ref', sub {
    my ($env, $name) = @_;
    return $env->subscription->landscape->policy($name)->eval($env->subscription, $env->system);
});

make_normal_form('subscription', sub {
    my ($env, $landscape_name, $name) = @_;

    $env->add_subscription($landscape_name => $name);
});

make_normal_form('lifecycle_query', sub {
    my ($env, $target_symbol) = @_;

    my $target = $env->lookup($target_symbol);
    return $target->running;
});

make_normal_form('unsubscribe', sub {
    my ($env, $name) = @_;
    $env->remove_subscription($name);
});

make_special_form('in', sub {
    my ($env, $subscription_lit, $lines) = @_;

    my $subscription_name = coeus_eval($subscription_lit, $env);
    my $subscription = $env->lookup_subscription($subscription_name);
    error("No subscription named '$subscription_name' available", $env) unless defined $subscription;

    my $inner_env = Coeus::Interpreter::Environment->new({ parent => $env, subscription => $subscription });

    coeus_eval($lines, $inner_env);
});

make_normal_form('policy_change', sub {
    my ($env, $policy) = @_;

    error("Subscription " . $env->subscription->name . " of landscape " . $env->subscription->landscape->name . " does not have a policy $policy")
        unless defined($env->subscription->landscape->policy($policy));

    $env->subscription->policy($policy);
});

sub listify {
    my ($in) = @_;

    if(ref($in) eq 'ARRAY') {
        return @$in;
    }
    else {
        return $in;
    }
}

1;
