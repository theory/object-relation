package TEST::Kinetic::Build::Setup::Cache::Memcached;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup::Cache';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Kinetic::Build';
use aliased 'Test::MockModule';
use Test::Exception;

__PACKAGE__->runtests unless caller;

sub extra_conf { address => undef }

sub test_memcached_cache : Test(9) {
    my $self  = shift;
    my $class = $self->test_class;

    is $class->catalyst_cache_class, 'Kinetic::UI::Catalyst::Cache::Memcached',
        'catalyst_cache_class should return "Kinetic::UI::Catalyst::Cache::Memcached"';
    is $class->object_cache_class, 'Kinetic::Util::Cache::Memcached',
        'object_cache_class should return "Kinetic::Util::Cache::Memcached"';

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

sub test_rules : Test(30) {
    my $self  = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $kb = MockModule->new(Build);
    $kb->mock( check_manifest  => sub {return} );
    $kb->mock( _check_build_component => 1);
    $kb->mock(_prompt => sub { shift; $self->{output} .= join '', @_; });

    my $builder = $self->new_builder;
    $kb->mock( resume => $builder );
    $builder->{tty} = 1;

    # Construct the object.
    ok my $cache = $class->new($builder), "Create new $class object";
    isa_ok $cache, $class;
    is $cache->builder, $builder, 'Builder should be set';

    # Run the rules.
    ok $cache->validate, 'Run validate()';
    is $cache->expires, 3600, 'Expires should be 3600';
    is_deeply $cache->addresses, ['127.0.0.1:11211'],
        'Addresses should be default';
    is $self->{output}, undef,' There should have been no output';

    # Try it with conf file settings.
    $builder->notes(_config_ => {
        cache => {
            address => ['123.123.123.123:76','123.123.123.124:76'],
            expires => 543,
        },
    });
    ok $cache->validate, 'Run validate() with config datat';
    is $cache->expires, 543, 'Expires should be 543';
    is_deeply $cache->addresses, ['123.123.123.123:76','123.123.123.124:76'],
        'Addresses should be correct';
    is $self->{output}, undef,' There should have been no output';

    # Try it with prompts.
    $builder->notes( _config_ => undef );
    $builder->accept_defaults(0);
    my @addrs = ('127.0.0.1:11211', '127.0.0.2:11212');
    my @input = (@addrs, '', 7200);
    $kb->mock(_readline => sub { shift @input });

    ok $cache->validate, 'Run validate() with prompts';
    is $cache->expires, 7200, 'Expires should now be 7200';
    is_deeply $cache->addresses, \@addrs,  'Addresses should be correct';

    is delete $self->{output}, join(
        q{},
        q{Please enter IP:port for a memcached server [127.0.0.1:11211]: },
        q{Please enter IP:port for another memcached server []: },
        q{Please enter IP:port for another memcached server []: },
        q{Please enter cache expiration time in seconds [3600]: },
   ), 'Prompts should be sent to output';

    # Try it with command-line arguments. Duplicate address silently ignored.
    local @ARGV = qw(
        --memcached-address 127.0.0.1:11211
        --memcached-address 127.0.0.2:11212
        --memcached-address 127.0.0.1:11211
        --memcached-address 127.0.0.3:11213
        --cache-expires 1234
    );
    push @addrs, '127.0.0.3:11213';
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $cache = $class->new($builder),
        "Create new $class object to read \@ARGV";
    is $cache->builder, $builder, 'Builder should be the new builder';

    # Run the rules.
    ok $cache->validate, 'Run validate()';
    is $cache->expires, 1234, 'Expires should be 1234';
    is_deeply $cache->addresses, \@addrs,  'Addresses should be correct';
    is $self->{output}, undef,' There should have been no output';

    # Try a bad IP address.
    @ARGV = qw(--memcached-address 123.456.7899:1234);
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $cache = $class->new($builder),
        "Create new $class object to read bogus args from \@ARGV";
    is $cache->builder, $builder, 'Builder should be the new builder';

    throws_ok { $cache->validate }
        qr/"123\.456\.7899:1234" is not a valid value for --memcached-address/,
        'A bad IP address should trigger an error';

    # Try a bad port.
    @ARGV = qw(--memcached-address 127.0.0.1:foo);
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $cache = $class->new($builder),
        "Create new $class object to read bogus args from \@ARGV";
    is $cache->builder, $builder, 'Builder should be the new builder';

    throws_ok { $cache->validate }
        qr/"127\.0\.0\.1:foo" is not a valid value for --memcached-address/,
        'A bad port should trigger an error';

    # Try a bad format.
    @ARGV = qw(--memcached-address 127.0.0.1-1234);
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $cache = $class->new($builder),
        "Create new $class object to read bogus args from \@ARGV";
    is $cache->builder, $builder, 'Builder should be the new builder';

    throws_ok { $cache->validate }
        qr/"127\.0\.0\.1-1234" is not a valid value for --memcached-address/,
        'A bad format should trigger an error';

}

1;
__END__
