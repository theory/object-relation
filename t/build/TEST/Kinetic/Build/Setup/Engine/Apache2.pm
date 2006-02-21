package TEST::Kinetic::Build::Setup::Engine::Apache2;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup::Engine';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Test::MockModule';
use File::Spec::Functions 'catfile';
use Test::Exception;
use constant Build => 'Kinetic::Build';

__PACKAGE__->runtests unless caller;

sub test_apache : Test(12) {
    my $self  = shift;
    my $class = $self->test_class;

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    ok my $apache = $class->new, "Create new $class object";
    isa_ok $apache, $class;
    isa_ok $apache, 'Kinetic::Build::Setup::Engine';
    isa_ok $apache, 'Kinetic::Build::Setup';
    isa_ok $apache->builder, 'Kinetic::Build';

    my $info_class = 'App::Info::HTTPD::Apache';
    is $apache->info_class, $info_class, 'Info class should be "$info_class"';
    isa_ok $apache->info, $info_class,
        'info() should return an $info_class object';
    is $apache->min_version, '2.0.54', 'Min version should be "2.0.54"';
    is $apache->engine_class, 'Kinetic::Engine::Apache2',
        'Engine class should be "Kinetic::Engine::Apache2"';
    is $apache->conf_engine, 'apache', 'Conf engine should be "apache"';
    is_deeply [$apache->conf_sections], [qw(httpd conf)],
        'Conf sections should be qw(httpd conf)';
    ok $apache->rules, 'Rules should be defined';
}

sub test_rules : Test(48) {
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

    FAKE_MOD_PERL: {
        package mod_perl2;
        $INC{mod_perl2} = __FILE__;
        our $VERSION_TRIPLET = '2.0.0';
    }

    # Override App::Info methods to keep things quiet.
    my $info = MockModule->new($class->info_class);
    $info->mock(installed => 1);
    $info->mock(version => '2.0.54');
    $info->mock(httpd => 'myhttpd' );
    $info->mock(mod_perl => 1);
    my $conf_file = catfile(qw(conf kinetic.conf));
    $info->mock(conf_file => $conf_file);

    # Construct the object.
    ok my $apache = $class->new($builder), "Create new $class object";
    isa_ok $apache, $class;
    is $apache->builder, $builder, 'Builder should be set';

    # Start with the defaults.
    ok $apache->validate, 'Run validate()';
    is $apache->httpd, 'myhttpd', 'httpd should be "myhttpd"';
    is $apache->conf, $conf_file, 'Conf file should be "$conf_file"';
    is $apache->base_uri, '/', 'Base URI should be "/"';
    is $self->{output}, undef,' There should have been no output';

    # Try it with conf file settings.
    my $try_bin = catfile(qw(t somescript));
    my $try_conf = catfile(qw(conf kinetic.conf));
    $builder->notes(_config_ => {
        kinetic => {
            base_uri => '/foo/',
        },
        engine => {
            conf  => $try_conf,
        },
    });
    ok $apache->validate, 'Run validate() with conf file data';
    is $apache->conf, $try_conf, qq{Conf file should be "$try_conf"};
    is $apache->base_uri, '/foo/', 'Base URI should be "/foo"';
    is $self->{output}, undef,' There should have been no output';

    # Try it with prompts
    $builder->notes( _config_ => undef );
    $apache->base_uri('/');
    $builder->accept_defaults(0);
    my $bin_file = catfile(qw(bin somescript));
    my @input = ($bin_file, '/foo');
    $kb->mock(_readline => sub { shift @input });

    ok $apache->validate, 'Run validate() with prompts';
    is $apache->httpd, 'myhttpd', 'httpd should be "myhttpd"';
    is $apache->conf, $bin_file, 'Conf file should be "$bin_file"';
    is $apache->base_uri, '/foo/', 'Base URI should be "/foo/"';
    is delete $self->{output}, join(
        q{},
        qq{Please enter path to httpd.conf [$conf_file]: },
        q{Please enter the root URI for TKP [/]: },
    ), 'Questions should be sent to output';


    # Try it with command-line arguments.
    $info->unmock('httpd');
    local @ARGV = (
        '--path-to-httpd'     => $bin_file,
        '--base_uri'          => '/bar',
       ' --path-to-http-conf' => $conf_file,
    );
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $apache = $class->new($builder),
        "Create new $class object to read \@ARGV";
    is $apache->builder, $builder, 'Builder should be the new builder';

    # Run the rules.
    ok $apache->validate, 'Run validate() with \@ARGV options';
    is $apache->httpd, $bin_file, qq{httpd should be "$bin_file"};
    is $apache->conf, $conf_file, 'Conf file should be "$bin_file"';
    is $apache->base_uri, '/bar/', 'Base URI should be "/bar/"';
    is $self->{output}, undef,' There should have been no output';

    # Construct a rules object.
    ok my $fsa = FSA::Rules->new($apache->rules), "Create FSA::Rules machine";

    ##########################################################################
    # Test "Start"
    $info->mock(installed => 0);
    ok $fsa->start, 'Start machine';

    # Test behavior if Apache is not installed
    throws_ok { $fsa->switch } qr/Apache does not appear to be installed/,
      'It should die if Apache is not installed';

    ##########################################################################
    # Test "check_version"
    $info->mock(installed => 1);
    $info->mock(version => '1.0');
    ok $fsa->reset->start, 'Reset the machine';

    ok $fsa->switch, "We should now be able to switch";
    is $fsa->curr_state->name, 'check_version',
      'Now we should be in the "check_version" state';

    # Test behavior of it's the wrong version of Apache.
    throws_ok { $fsa->switch }
        qr/I require Apache v2.0.54 but found $bin_file, which is 1\.000\.\nUse --path-to-httpd to specify a different Apache executable/,
      'It should die with the wrong version';

    # Set up the proper version number.
    $info->mock(version => '2.0.54');
    ok $fsa->reset->curr_state('check_version'), 'Set up check version_ again';
    ok $fsa->switch, "We should now be able to switch";

    ##########################################################################
    # Test "check_mod_perl"
    is $fsa->curr_state->name, 'check_mod_perl',
        'Now we should be in the "check_mod_perl" state';
    ok $fsa->switch, 'We should now be able to switch';
    is $fsa->curr_state->name, 'httpd_conf',
      'Now we should be in the "httpd_conf" state';

    # Test when mod_perl support is missing.
    $info->mock(mod_perl => 0);
    ok $fsa->reset->curr_state('check_mod_perl'),
        'Set up check_mod_perl again';
    throws_ok { $fsa->switch }
        qr/I found $bin_file, but it does not appear to include mod_perl support/,
        'We should get an error when Apache does not have mod_perl support';

    # Test behavior of it's the wrong mod_perl of Apache.
    $info->mock(mod_perl => 1);
    $mod_perl2::VERSION_TRIPLET = '1.12.0';
    throws_ok { $fsa->reset->run, 'Reset the machine' }
        qr/I require mod_perl v2.0.0 but found only v1.12.0/,
        'It should throw an error for the wrong version of mod_perl';

    ##########################################################################
    # Test "check_httpd_conf"
    ok $fsa->reset->curr_state('httpd_conf'), 'Set up httpd_conf';
    is $fsa->curr_state->name, 'httpd_conf',
        'Now we should be in the "httpd_conf" state';
    ok $fsa->switch, 'We should be able to switch';
    is $fsa->curr_state->name, 'base_uri',
      'Now we should be in the "base_uri" state';

    # Try failing.
    my @confs = (undef, $conf_file);
    $info->mock(conf_file => sub { shift @confs });
    ok $fsa->reset->curr_state('httpd_conf'), 'Set up httpd_conf again';
    ok $fsa->switch, 'We should still be able to switch';
    is $fsa->curr_state->name, 'httpd_conf',
        'We should still be in the "httpd_conf" state';
    ok $fsa->switch, 'We should still be able to switch again';
    is $fsa->curr_state->name, 'base_uri',
        'Now we should be in the "base_uri" state';

    ##########################################################################
    # XXX Skipping base_uri because it will be going away, hopefully. :-)
}

1;
__END__
