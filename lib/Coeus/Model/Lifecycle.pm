package Coeus::Model::Lifecycle;

use Moose::Role;
use Moose::Util::TypeConstraints;

enum Lifecycle => qw(running stopped);
enum Failure => qw(working failed);

has '_running_state' => (is => 'rw', default => sub { 'running' }, isa => 'Lifecycle');
has '_fail_state' => (is => 'rw', default => sub { 'working' }, isa => 'Failure');

sub running {
    my ($self) = @_;
    return $self->_running_state eq 'running' && !$self->failed;
}

sub failed {
    my ($self) = @_;
    return $self->_fail_state eq 'failed';
}

sub stop {
    my ($self) = @_;
    $self->_running_state('stopped');
}

sub start {
    my ($self) = @_;
    $self->_running_state('running');
}

sub fail {
    my ($self) = @_;
    $self->_fail_state('failed');
}

sub restore {
    my ($self) = @_;
    $self->_fail_state('working');
}

1;
