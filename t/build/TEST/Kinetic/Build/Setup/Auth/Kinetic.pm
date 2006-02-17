package TEST::Kinetic::Build::Setup::Auth::Kinetic;

# $Id: File.pm 2630 2006-02-15 05:42:59Z theory $

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup::Auth';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Kinetic::Build';
use aliased 'Test::MockModule';
use File::Spec::Functions qw(tmpdir catdir);

__PACKAGE__->runtests unless caller;

sub test_kinetic_auth : Test(8) {
    my $self  = shift;
    my $class = $self->test_class;

    is $class->authorization_class, 'Kinetic::Util::Auth::Kinetic',
      'authorization_class should return "Kinetic::UI::Catalyst::Auth::Kinetic"';

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock( resume => sub { bless {}, Build } );
    $builder->mock( _app_info_params => sub { } );

    ok my $auth = $class->new, "Create new $class object";
    isa_ok $auth, $class;
    isa_ok $auth, 'Kinetic::Build::Setup::Auth';
    isa_ok $auth, 'Kinetic::Build::Setup';
    isa_ok $auth->builder, 'Kinetic::Build';
    is $auth->info,        undef, 'info() should be undef';
    ok $auth->rules,       'Rules should be defined';
}

sub test_rules : Test(14) {
    my $self  = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $kb = MockModule->new(Build);
    $kb->mock( check_manifest => sub {return} );
    $kb->mock( _check_build_component => 1 );
    $kb->mock( _prompt => sub { shift; $self->{output} .= join '', @_; } );

    my $builder = $self->new_builder;
    $kb->mock( resume => $builder );
    $builder->{tty} = 1;

    # Construct the object.
    ok my $auth = $class->new($builder), "Create new $class object";
    isa_ok $auth, $class;
    is $auth->builder, $builder, 'Builder should be set';

    # Run the rules.
    my $tmp_dir = catdir( tmpdir(), qw(kinetic cache) );
    ok $auth->validate, 'Run validate()';
    is $auth->expires, 3600, 'Expires should be 3600';
    is $self->{output}, undef, ' There should have been no output';

    # Try it with prompts.
    $builder->accept_defaults(0);
    my @input = qw(7200);
    $kb->mock( _readline => sub { shift @input } );

    ok $auth->validate, 'Run validate() with prompts';
    is $auth->expires,  7200, 'Expires should now be 7200';

    is delete $self->{output},
      qq{Please enter authorization expiration time in seconds [3600]: },,
      'Prompts should be sent to output';

    # Try it with command-line arguments.
    local @ARGV = qw(
      --auth-expires 1234
    );
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $auth = $class->new($builder),
      "Create new $class object to read \@ARGV";
    is $auth->builder, $builder, 'Builder should be the new builder';

    # Run the rules.
    ok $auth->validate, 'Run validate()';
    is $auth->expires, 1234, 'Expires should be 1234';
    is $self->{output}, undef, ' There should have been no output';
}

1;
__END__