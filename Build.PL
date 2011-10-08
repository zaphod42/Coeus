use Module::Build;

my $class = Module::Build->subclass(
    class => "Coeus::Module::Build",
    code => <<'SUBCLASS');

sub ACTION_test {
    my ($self) = @_;

    push @INC, 't/lib';
    
    return $self->SUPER::ACTION_test();
}

sub process_pr_files {
    my $self = shift;

    use Parse::RecDescent;

    my $target = File::Spec->catdir($self->blib, 'lib', 'Coeus', 'Interpreter', 'Grammar.pm');

    return if $self->up_to_date('grammar.pr', $target);

    open my($fh), "grammar.pr" or die "Unable to open grammar for build";

    local $/;
    my $grammar = <$fh>;
    close $fh;

    print "Precompiling grammar.\n";
    Parse::RecDescent->Precompile($grammar, 'Coeus::Interpreter::Grammar');
    $self->copy_if_modified(from => 'Grammar.pm', to => $target);
    unlink 'Grammar.pm';
}

SUBCLASS

my $build = $class->new(
    module_name => 'Coeus', 
    dist_version_from => 'coeus',
    create_readme => 1,
    license  => 'restrictive', 
    requires => { 
        'perl'          => '5.8.1', 
        'Parse::RecDescent' => '1.94',
        'Regexp::Common' => '2.120',
        'Moose' => '0.40',
        'Math::Combinatorics' => '0.09',
        'Clone' => '0.22',
    },
    recommends => {
        'Graph::Easy' => '0.61',
    },
    build_requires => {
        'Test::Deep' => '0.097',
    },
    script_files => ['coeus'],);
$build->add_build_element('pr');
$build->create_build_script;
