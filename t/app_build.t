#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
#use Test::More 'no_plan';
use Test::More tests => 22;
use Test::Exception;
use aliased 'Test::MockModule';
use File::Spec::Functions qw(catdir updir catfile curdir);
use Kinetic::Build::Test kinetic => { root => updir };
use Config::Std;
#use lib '../../lib';

my $CLASS = 'Kinetic::AppBuild';
my @builders;

BEGIN {
    # All build tests execute in the sample directory with its
    # configuration file.
    use_ok 'Kinetic::AppBuild' or die $@;
    chdir 't'; chdir 'sample';
    $ENV{KINETIC_CONF} = catfile 'conf', 'kinetic.conf';
}

END {
    $_->dispatch('realclean') for @builders;
    chdir updir; chdir updir;
}

my $kb_mocker = MockModule->new('Kinetic::Build::Base');
$kb_mocker->mock(_check_build_component => 1);

my $config_file = catfile(updir, qw(conf kinetic.conf));

ok my $builder = new_builder(), 'Create new builder';
isa_ok $builder, $CLASS, 'The builder';

is $builder->install_base, updir, 'The install base is correct';
is $builder->path_to_config, $config_file, 'The config file should be correct';
is $builder->install_destination('www'), catdir(updir, 'www'),
    'The www base should be correct';
is $builder->install_destination('lib'), catdir(updir, 'lib'),
    'The lib base should be correct';

# Make sure that the config file is getting read in.
read_config( $config_file => my %conf);
is_deeply $builder->notes('_config_'), \%conf,
    'The config file should have been read into notes';

# Try specifying path_to_config explicitly.
ok $builder = new_builder( path_to_config => $config_file ),
    'Creae builder with explicit path_to_config';
isa_ok $builder, $CLASS, 'The builder';

is $builder->install_base, updir, 'The install base is correct';
is $builder->path_to_config, $config_file, 'The config file should be correct';
is $builder->install_destination('www'), catdir(updir, 'www'),
    'The www base should be correct';
is $builder->install_destination('lib'), catdir(updir, 'lib'),
    'The lib base should be correct';

# Try a bogus install base directory.
throws_ok { new_builder( install_base => 'foo' ) }
    qr/Directory "foo" does not exist; use --install-base to specify the\nKinetic base directory; or use --path-to-config to point to kinetic\.conf/,
    'We should catch an invalid install_base';

# Try an install_base directory without Kinetic.
throws_ok { new_builder( install_base => 'lib' ) }
    qr/Kinetic does not appear to be installed in "lib"; use --install-base to\nspecify the Kinetic base directory or use --path-to-config to point to kinetic\.conf/,
    'We should catch an install_base without Kinetic';

# Now try for when the kinetic_root in the conf is different.
ok $builder = new_builder( install_base => catdir(updir, updir) ),
    'Construct new builder with different install_base';

# Things should now be set according to the install_base in the config file.
read_config( catfile(updir, updir, qw(conf kinetic.conf)) => my %topconf );
is_deeply $builder->notes('_config_'), \%topconf,
    'The config file should have been read into notes';

is $builder->install_base, $topconf{kinetic}{root},
    'The install base should be set from the conf file';
is $builder->install_destination('www'),
    catdir($topconf{kinetic}{root}, 'www'),
    'The www base should be relative to the config root';
is $builder->install_destination('lib'),
    catdir($topconf{kinetic}{root}, 'lib'),
    'The lib base should be relative to the config root';

# Make sure that we die if there is no root in the config.
my $ab_mocker = MockModule->new($CLASS);
$ab_mocker->mock('notes' => {});
throws_ok { new_builder() }
    qr/I cannot find Kinetic\. Is it installed\? use --path-to-config to point to its config file/,
    'We should die if the config file is messed up';
$ab_mocker->unmock('notes');

=begin pod


sub test_files : Test(no_plan) {
    my $self  = shift;
    my $CLASS = $self->test_class;

    my $mocker = MockModule->new('Kinetic::Build::Base');
    $mocker->mock(_check_build_component => 1);

    # Start with no path to config.
    throws_ok { $self->new_builder( install_base => 'foo') }
        qr/Directory "foo" does not exist; use --install-base to specify the\nKinetic base directory; or use --path-to-config to point to kinetic.conf/,
        'We should get an error for an invalid install_base';

    return;


    ok my $builder = $self->new_builder;
    isa_ok $builder, $CLASS, 'The builder';

    my $blib_file = 'blib/lib/TestApp/Simple.pm';
    my $bwww_file = 'blib/www/test.html';
    my $bbin_file = 'blib/script/somescript';

    file_not_exists_ok $blib_file, 'blib lib file should not yet exist';
    file_not_exists_ok $bwww_file, 'blib www file should not yet exist';
    file_not_exists_ok $bbin_file, 'blib bin file should not yet exist';

    $builder->dispatch('build');

    file_exists_ok $blib_file, 'blib lib file should now exist';
    file_exists_ok $bwww_file, 'blib www file should now exist';
    file_exists_ok $bbin_file, 'blib bin file should now exist';
}

=cut

sub new_builder {
    push @builders, $CLASS->new(
        dist_name    => 'TestApp::Simple',
        dist_version => '1.0',
        quiet        => 1,
        install_base => updir,
        accept_defaults => 1,
        @_,
    );
    return $builders[-1];
}
1;
__END__
