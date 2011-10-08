package Coeus::Interpreter::AST;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT = qw(
    make_leftbinop
    make_rightbinop
);

my %modifies_config_ops = ();

sub modifies_configuration {
    my ($opname) = @_;
    return exists $modifies_config_ops{$opname}
}

sub unmake {
    my ($node) = @_;

    no strict 'refs';

    my $type = $node->[0];
    my $unmade = *{ "unmake_$type" }->($node);

    foreach my $part (keys %$unmade) {
        if(ref($unmade->{$part})) {
            if(@{ $unmade->{$part} } > 0 && !ref($unmade->{$part}->[0])) {
                $unmade->{$part} = unmake($unmade->{$part});
            }
            else {
                $unmade->{$part} = [map { unmake($_) } @{ $unmade->{$part} }];
            }
        }
    }

    return $unmade;
}

sub _define_node {
    my ($name, $modifies, @args) = @_;

    no strict 'refs';

    push @EXPORT, "make_$name";
    $modifies_config_ops{$name} = 1 if $modifies;

    *{ "make_$name" } = sub {
        my ($args) = @_;

        foreach my $arg (@args) {
            die "Missing argument $arg for $name" unless exists $args->{$arg};
        }

        my @node = ($name, @{ $args }{@args});
        if(exists $args->{line}) {
            push @node, $args->{line};
        }
        else {
            push @node, undef;
        }

        return \@node;
    };

    *{ "unmake_$name" } = sub {
        my ($node) = @_;

        my %node_data = (
            __TYPE__     => $name,
            __MODIFIES__ => $modifies,
        );

        my $index = 1;
        foreach my $arg (@args) {
            $node_data{$arg} = $node->[$index++];
        }

        # there may still be a line entry on the end
        if($index == $#{ $node }) {
            $node_data{__LINE__} = $node->[$index];
        }

        return \%node_data;
    }
}

# Types
_define_node('type_decl', 0, qw(name behavior));
_define_node('condition', 0, qw(condition capability uncapability));
_define_node('capability', 0, qw(name));
_define_node('uncapability', 0, qw(name));

# Landscapes
_define_node('landscape_decl', 0, qw(name policies));
_define_node('policy_decl', 0, qw(default name policy attributes));
_define_node('policy_ref', 0, qw(name));

# Language structures
_define_node('call', 0, qw(name args));
_define_node('deref', 0, qw(ref));
_define_node('propref', 0, qw(var property));
_define_node('varref', 0, qw(var));
_define_node('literal', 0, qw(value));
_define_node('sequence', 0, qw(commands));
_define_node('binop', 0, qw(op left right));
_define_node('uniop', 0, qw(op expr));
_define_node('topic_block', 0, qw(topic block));
_define_node('bind', 1, qw(value target));
_define_node('identifier', 0, qw(name));
_define_node('list', 0, qw(elements));

# Interpretation structure
_define_node('map', 0, qw(topic block));

# Configuration manipulation
_define_node('install', 1, qw(object target));
_define_node('commission', 1, qw(type id));
_define_node('decommission', 1, qw(instance));
_define_node('use', 1, qw(user provider type));
_define_node('policy_change', 1, qw(policy));
_define_node('stop_instance', 1, qw(instance));
_define_node('start_instance', 1, qw(instance));

# Configuration queries
_define_node('use_query', 0, qw(user provider type filter));
_define_node('wildcard_filter', 0);
_define_node('type_filter', 0, qw(type id));
_define_node('capability_filter', 0, qw(capability));
_define_node('identity_filter', 0, qw(identity));
_define_node('expression_filter', 0, qw(expression));
_define_node('instance_query', 0, qw(type filter));
_define_node('can', 0, qw(capability));
_define_node('lifecycle_query', 0, qw(identifier));
_define_node('install_instance_query', 0, qw(host instance));
_define_node('install_host_query', 0, qw(host instance filter));
_define_node('inclusion_query', 0, qw(members universe));

# Meta structures
_define_node('action_decl', 0, qw(name parameters body));
_define_node('include', 0, qw(file));
_define_node('subscription', 0, qw(landscape name));
_define_node('unsubscribe', 0, qw(name));
_define_node('in', 0, qw(subscription lines));
_define_node('atomic_block', 0, qw(commands));

sub make_leftbinop {
    my ($args) = @_;

    # our input looks like [1, '/', 3, '*', 4]
    # and needs to be transformed into the tree:
    #       '*'
    #      /   \
    #    '/'    4
    #   /   \
    #  1     3

    my @terms = @{ $args->{terms} };
    my $constant_op = $args->{op};

    while(@terms > 1) {
        my $left = shift @terms;
        my $op = $constant_op || shift @terms; # if one was given, just use it
        my $right = shift @terms;

        unshift @terms, make_binop({op => $op, left => $left, right => $right});
    }

    return $terms[0];
}

sub make_rightbinop {
    my ($args) = @_;

    # Input is [v1, v2, v3, expr]
    # and needs to be
    #
    #         :=
    #        /  \
    #       v1  :=
    #          /  \
    #         v2  :=
    #            /   \
    #           v3   expr
    
    my @terms = @{ $args->{terms} };

    while(@terms > 1) {
        my $expr = pop @terms;
        my $lvalue = pop @terms;

        push @terms, make_bind({ target => $lvalue, value => $expr })
    }

    return $terms[0];
}

1;

__END__

=head1 NAME

Coeus::Interpreter::AST - Abstract Syntax Tree building functions

=head1 SYNOPSIS

   use Coeus::Interpreter::AST;

   my $ast = make_binop(
       {
           left  => make_literal({value => 1}),
           op    => '+',
           right => make_literal({value => 2})
       });

=head1 DESCRIPTION

=head1 FUNCTIONS

=over 8

=item C<define_node($name, $modifies, @args)>

Creates new C<make_$name> and C<unmake_$name> functions for the 
construction and deconstruction, respectively, of AST nodes.  The C<@args>
are a list of strings of the parameter names for the node.  The C<make_$name>
function will check that all required parameters are supplied when constructing
a new node. The C<$modifies> flag is used to mark nodes that represent configuration changes. Refer
to L<Coeus::Interpreter::Commands> for more information. In addition to the defined C<@args> a C<line> 
can also be provided to record the line number in the source document that the AST node corrosponds to.

The C<unmake_$name> functions are used for inspecting generated ASTs. They take the generated AST structure
(which is arrays of arrays) and translate it into a format that is much more suited
to displaying for debugging purposes. Each node is transformed into a hash with one key for each 
of the declared C<@args>, as well as C<__TYPE__> (the C<$name>), C<__MODIFIES__> (the C<$modifies> flag), 
and C<__LINE__> (if a line number is specified).

=item C<unmake($ast) : $hash>

Runs through the given C<$ast> constructing the C<unmake_$name> versions of each node. Returns
the new "unmade" hash of the AST.

=item C<make_leftbinop({ op => $op, terms => \@terms }) : $ast>

Create an AST for applying C<$op> to the C<\@terms> in left associative order.

=item C<make_rightbinop({ terms => \@terms }) : $ast>

Create an AST for applying assignment to the C<\@terms> in right associative order.

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
