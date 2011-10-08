package Coeus::Visual::DotMapper;

use strict;
use warnings;
use File::Spec::Functions;
use Digest::MD5 qw(md5_hex);
use Graph::Easy;

use Coeus::Interpreter::Hook;
use Coeus::Interpreter::AST qw();

our $DIR;
our $FILE;

my $num = 1;

Coeus::Interpreter::Hook::register(\&to_dot);
sub to_dot {
    my ($env, $op) = @_;

    return unless Coeus::Interpreter::AST::modifies_configuration($op);

    my $g = Graph::Easy->new();
    _conf_to_graph($env->system->configuration, $g, "System Configuration");
    foreach my $sub (@{ $env->system->subscriptions }) {
        _conf_to_graph($sub->configuration, $g, "Subscription: " . $sub->name);
    }

    my $filename = defined($DIR) ? catfile($DIR, "commit${num}.dot") : $FILE;
    $num++;

    open my($fh), ">$filename";
    print $fh $g->as_graphviz;
}

####################################
# Configuration Visualization
####################################
sub _conf_to_graph {
    my ($conf, $g, $name) = @_;

    my $md5 = md5_hex($name);
    my $config_group = Graph::Easy::Group->new(name => $name);
    $g->add_group($config_group);

    foreach my $node (@{ $conf->instances }) {
        my $graph_node = Graph::Easy::Node->new($md5 . $node->id);
        $graph_node->set_attribute(label => _node_text($node));
        $graph_node->set_attribute(shape => "record");
        $config_group->add_node($graph_node);
        $g->add_edge($graph_node, $graph_node, "forced_edge")
          ->set_attribute(style => 'invisible');
    }

    foreach my $use (@{ $conf->uses }) {
        $g->add_edge($config_group->node($md5 . $use->user->id),
            $config_group->node($md5 . $use->provider->id), _edge_text($use));
    }
}

sub _edge_text {
    my ($edge) = @_;
    my $name = $edge->type eq Coeus::Model::Use->HOST ? "host" : $edge->type;
    return "$name\\n(" . _status($edge) . ")"
}

sub _node_text {
    my ($node) = @_;

    my $text = $node->type . '(' . $node->id . ')';
    $text .= '\n' . '(' . _status($node) . ')';
    $text .= ' | ';
    foreach my $name (@{ $node->properties }) {
        my $prop = $node->lookup($name);
        $text .= $name . " : " . $prop . '\n';
    }

    $text .= " | " . join('\n', @{ $node->capabilities });

    return $text;
}

sub _status {
    my ($thing) = @_;
    return $thing->running ? 'running'
      : (
        $thing->failed ? 'failed'
        : 'stopped'
      );
}

1;
