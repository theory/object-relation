package TEST::Kinetic::Build::Setup::Cache::File;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup::Cache';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Kinetic::Build';
use aliased 'Test::MockModule';
use File::Spec::Functions qw(tmpdir catdir);

__PACKAGE__->runtests unless caller;

sub extra_conf { root => undef }

sub test_file_cache : Test(9) {
    my $self  = shift;
    my $class = $self->test_class;

    is $class->catalyst_cache_class, 'Kinetic::UI::Catalyst::Cache::File',
        'catalyst_cache_class should return "Kinetic::UI::Catalyst::Cache::File"';
    is $class->object_cache_class, 'Kinetic::Util::Cache::File',
        'object_cache_class should return "Kinetic::Util::Cache::File"';

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    ok my $cache = $class->new, "Create new $class object";
    isa_ok $cache, $class;
    isa_ok $cache, 'Kinetic::Build::Setup::Cache';
    isa_ok $cache, 'Kinetic::Build::Setup';
    isa_ok $cache->builder, 'Kinetic::Build';
    is $cache->info, undef, 'info() should be undef';
    ok $cache->rules, 'Rules should be defined';
}

sub test_rules : Test(17) {
    my $self  = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $kb = MockModule->new(Build);
    $kb->mock( check_manifest  => sub {return} );
    $kb->mock( check_store     => 1 );
    $kb->mock( check_engine    => 1 );
    $kb->mock(_prompt => sub { shift; $self->{output} .= join '', @_; });

    my $builder = $self->new_builder;
    $kb->mock( resume => $builder );
    $builder->{tty} = 1;

    # Construct the object.
    ok my $cache = $class->new($builder), "Create new $class object";
    isa_ok $cache, $class;
    is $cache->builder, $builder, 'Builder should be set';

    # Run the rules.
    my $tmp_dir =  catdir(tmpdir(), qw(kinetic cache));
    ok $cache->validate, 'Run validate()';
    is $cache->expires, 3600, 'Expires should be 3600';
    is $cache->root, $tmp_dir, 'Root should be default';
    is $self->{output}, undef,' There should have been no output';

    # Try it with prompts.
    $builder->accept_defaults(0);
    my @input = qw(t 7200);
    $kb->mock(_readline => sub { shift @input });

    ok $cache->validate, 'Run validate() with prompts';
    is $cache->expires, 7200, 'Expires should now be 7200';
    is $cache->root, 't', 'Root should now be "t"';

    is delete $self->{output}, join(
        q{},
        qq{Please enter the root directory for caching [$tmp_dir]: },
        q{Please enter cache expiration time in seconds [3600]: },
   ), 'Prompts should be sent to output';

    # Try it with command-line arguments.
    local @ARGV = qw(
        --cache-root    lib
        --cache-expires 1234
    );
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $cache = $class->new($builder),
        "Create new $class object to read \@ARGV";
    is $cache->builder, $builder, 'Builder should be the new builder';

    # Run the rules.
    ok $cache->validate, 'Run validate()';
    is $cache->expires, 1234, 'Expires should be 1234';
    is $cache->root, 'lib', 'Root should be "lib"';
    is $self->{output}, undef,' There should have been no output';
}

1;
__END__
