#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use Test::More 'no_plan';
#use Test::More tests => 34;
use Test::Exception;
use Test::File;
use aliased 'Test::MockModule';
use File::Spec::Functions qw(catdir updir catfile curdir);
use Kinetic::Build::Test kinetic => { root => updir };
use Config::Std;
use File::Copy;
use File::Path;
use DBI;
use lib '../../lib';

my $CLASS = 'Kinetic::AppBuild';
my @builders;

BEGIN {
    # All build tests execute in the sample directory with its
    # configuration file.
    chdir 't'; chdir 'sample';

    # Setup a sample configuration file for us to use.
    mkpath 'conf';
    my $conf_file = catfile qw(conf sample.conf);
    open my $conf_fh, '>', $conf_file or die "Cannot open $conf_file: $!\n";
    print $conf_fh join "\n",
        '[auth]',
        '_sample_: foo',
        '[sample]',
        'foo: bar',
        'baz: woo',
    ;
    close $conf_fh;

    # Omit KINETIC_CONF; the tests will set it as needed.
    delete $ENV{KINETIC_CONF};

    # Start 'er up!
    use_ok 'Kinetic::AppBuild' or die $@;
}

END {
    $_->dispatch('realclean') for @builders;
    rmtree 'conf';
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

##############################################################################
# Okay, let's load stuff up from the test conf file.
#local $ENV{KINETIC_CONF} = catfile updir, qw(conf kinetic.conf);
$kb_mocker->unmock('_check_build_component');
ok $builder = new_builder( dev_tests => 1 ),
    'Create new builder with dev_tests => 1';
ok $builder->dev_tests, 'dev_tests should be true';

##############################################################################
# Now let'd make sure that the build action does what we want.
my $blib_file  = 'blib/lib/TestApp/Simple.pm';
my $bwww_file  = 'blib/www/test.html';
my $bbin_file  = 'blib/script/somescript';
my $bconf_file = 'blib/conf/kinetic.conf';
my $tconf_file = 't/conf/kinetic.conf';

file_not_exists_ok $blib_file,  'blib lib file should not yet exist';
file_not_exists_ok $bwww_file,  'blib www file should not yet exist';
file_not_exists_ok $bbin_file,  'blib bin file should not yet exist';
file_not_exists_ok $bconf_file, 'blib conf file should not yet exist';
file_not_exists_ok $tconf_file, 't conf file should not yet exist';

$builder->dispatch('build');

file_exists_ok $blib_file,  'blib lib file should now exist';
file_exists_ok $bwww_file,  'blib www file should now exist';
file_exists_ok $bbin_file,  'blib bin file should now exist';
file_exists_ok $bconf_file, 'blib conf file should now exist';
file_exists_ok $tconf_file, 't conf file should now exist';

# So make sure that the conf files have the proper data in them.
read_config( catfile(qw(blib conf kinetic.conf)) => my %bconf );
read_config( $config_file  => my %dconf );
# Add sample data for comparing.
$dconf{auth}->{_sample_} = 'foo';
$dconf{sample} = { foo => 'bar', baz => 'woo' };
is_deeply \%bconf, \%dconf, 'The configuration file should be merged';

# We should have test data.
read_config( catfile(qw(t conf kinetic.conf)) => my %tconf );
SKIP: {
    # Test the test config for at least one data store.
    skip 'Not testing PostgreSQL', 1
        if $tconf{store}{class} ne 'Kinetic::Store::DB::Pg';
    is_deeply $tconf{store}, {
        db_user          => '__kinetic_test__',
        db_pass          => '__kinetic_test__',
        db_super_user    => 'postgres',
        dsn              => 'dbi:Pg:dbname=__kinetic_test__',
        db_super_pass    => '',
        class            => 'Kinetic::Store::DB::Pg',
        template_db_name => 'template1'
    }, 'The store data should contain test info';
}

# Sync up the store and root data to verify the whole thing.
$dconf{store} = $tconf{store};
$dconf{kinetic}{root} = $tconf{kinetic}{root};
is_deeply \%tconf, \%dconf, 'The test config file should be merged';

##############################################################################
# Now, dispatch to test, and make sure that it builds a data store.
my $mb_mocker = MockModule->new('Module::Build');
$mb_mocker->mock(ACTION_test => sub {
    # We'll run tests during the test action here. Sneaky, huh?
    ok 1, 'Run super test';
});

SKIP: {
    skip 'Not running dev tests', 2 unless $ENV{KINETIC_SUPPORTED};

    # We should fail to connect to the test data store.
#    eval { DBI->connect(@{$tconf{store}}{qw(dsn db_user db_pass)}) };
#    ok $@, 'We should fail to connect to the test database';

    ok $builder->dispatch('test'), 'Dispatch to test action should return';

}

##############################################################################
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
