#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
#use Test::More 'no_plan';
use Test::More tests => 80;
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
my ($MAIN_BUILD, $STORE, $KBS, @builders, @ARGS);

BEGIN {
    # Omit KINETIC_CONF; the tests will set it as needed.
    delete $ENV{KINETIC_CONF};
    require Kinetic::Build;

    # Load up current build config, as we'll need it.
    $MAIN_BUILD = Kinetic::Build->resume;
    $STORE = $MAIN_BUILD->store;

    # Make sure the store setup loads before we change directories, since it
    # is serialized in _build/notes.
    $MAIN_BUILD->setup_objects('store')->builder;

    # Get the current command-line arguments, so that we can use them to
    # create new build objects without errors.
    my $args = $MAIN_BUILD->args;
    @ARGS = (
        @{ delete $args->{ARGV} },
        map { ("--$_" => $args->{$_}) } keys %{ $args }
    );

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

    # Start 'er up!
    use_ok 'Kinetic::AppBuild' or die $@;
}

END {
    # Clean up our messes.
    $_->dispatch('realclean') for @builders;
    rmtree 'conf';
    $KBS->test_cleanup if $KBS;
    # Return to root so Kinetic::Build::Test can restore t/conf/kinetic.conf.
    chdir updir; chdir updir;
}

is_deeply [$CLASS->setup_properties ], [qw(store)],
    'Setup properties should be properly inherited';

# Prevent checking setups for now.
my $kb_mocker = MockModule->new('Kinetic::Build::Base');
$kb_mocker->mock(_check_build_component => 1);

my $config_file = catfile(updir, qw(conf kinetic.conf));

ok my $builder = new_builder(), 'Create new builder';
isa_ok $builder, $CLASS, 'The builder';

is $builder->install_base, updir, 'The install base is correct';
is $builder->path_to_config, $config_file, 'The config file should be correct';
is $builder->install_destination('lib'), catdir(updir, 'lib'),
    'The lib base should be correct';
is $builder->module_name, 'TestApp::Simple',
    'The module name should be "TestApp::Simple"';
my $dist_version = $builder->dist_version;
$dist_version = version->new($dist_version) unless ref $dist_version;
cmp_ok $dist_version, '==', version->new('1.1.0'),
    'The version number should be "1.1.0"';

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
# Okay, let the setups get loaded.
$kb_mocker->unmock('_check_build_component');

# Force the store setups into thinking that it doesn't matter that the
# database doesn't exist by telling it that this isn't Kinetic::AppBuild. This
# is important, because generally, the database must exist to install an app.
my $isa_flag;
$kb_mocker->mock( isa => sub {
    return undef if $_[1] eq $CLASS && !$isa_flag++;
    shift->SUPER::isa(@_);
});

ok $builder = new_builder( dev_tests => 1 ),
    'Create new builder with dev_tests => 1';
is $builder->path_to_config, $config_file,
    'The path to config should be corectly set';
is_deeply $builder->notes('_config_'), \%conf,
    'The config file should have been read into notes';
ok $builder->dev_tests, 'dev_tests should be true';

##############################################################################
# Now let'd make sure that the build action does what we want.
my $blib_file  = 'blib/lib/TestApp/Simple.pm';
my $bbin_file  = 'blib/script/somescript';
my $bconf_file = 'blib/conf/kinetic.conf';
my $tconf_file = 't/conf/kinetic.conf';

file_not_exists_ok $blib_file,  'blib lib file should not yet exist';
file_not_exists_ok $bbin_file,  'blib bin file should not yet exist';
file_not_exists_ok $bconf_file, 'blib conf file should not yet exist';
file_not_exists_ok $tconf_file, 't conf file should not yet exist';

$builder->dispatch('build');

file_exists_ok $blib_file,  'blib lib file should now exist';
file_exists_ok $bbin_file,  'blib bin file should now exist';
file_exists_ok $bconf_file, 'blib conf file should now exist';
file_exists_ok $tconf_file, 't conf file should now exist';

# So make sure that the conf files have the proper data in them.
read_config( $config_file  => my %dconf );
read_config( catfile(qw(blib conf kinetic.conf)) => my %bconf );

# Add sample data for comparing.
$dconf{auth}->{_sample_} = 'foo';
$dconf{sample} = { foo => 'bar', baz => 'woo' };

if ($STORE eq 'sqlite') {
    $dconf{store}{dsn} = 'dbi:SQLite:dbname=' . catfile updir, qw(store kinetic.db);
} elsif ($STORE eq 'pg') {
    delete @{$dconf{store}}{qw(db_super_pass db_super_user template_db_name)};
}
is_deeply \%bconf, \%dconf, 'The configuration file should be merged';

# We should have test data.
read_config( catfile(qw(t conf kinetic.conf)) => my %tconf );
SKIP: {
    # Test the test config for at least one data store.
    skip 'Not testing PostgreSQL', 1 if $STORE ne 'pg';
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
SKIP: {
    skip 'Not running dev tests', 50 unless $ENV{KINETIC_SUPPORTED};
    use Carp;
    $SIG{__DIE__} = \&confess;

    # We need to access the schema object to test which classes it has loaded.
    my $db_mocker = MockModule->new('Kinetic::Build::Setup::Store::DB');
    my $orig_load_schema;
    my $schema;
    $db_mocker->mock(_load_schema => sub {
        return $schema = $orig_load_schema->(@_);
    });
    $orig_load_schema = $db_mocker->original('_load_schema');

    # Set up tests to run *during* the test actions. Yes, this is sneaky! But
    # it's cool, because it allows us to test the database after it's created
    # and before it's dropped by the test action.
    my $mb_mocker = MockModule->new('Module::Build');
    $mb_mocker->mock(ACTION_test => sub {
        test_store(\%tconf, $schema )->disconnect;
    });

    # We should fail to connect to the test data store.
    dies_ok { dbi_connect(@{$tconf{store}}{qw(dsn db_user db_pass)}) }
        'We should not be able to connect to the test database';

    # So dispatch to the test action.
    $builder->install_base(catdir updir, updir);
    ok $builder->dispatch('test'), 'Dispatch to test action should return';
    sleep 1 if $STORE eq 'pg'; # Wait for disconnect from template1.

    # So we tested the data store during the test action, and now it should be
    # gone again.
    dies_ok { dbi_connect(@{$tconf{store}}{qw(dsn db_user db_pass)}) }
        'And now the database should be gone again';

    ##########################################################################
    # Okay, now now we want to test an install. But first, we need an existing
    # database. So build one from the existing install.
    $KBS = $MAIN_BUILD->setup_objects('store');

    # Silence the copy of the builder used by the store setup.
    ok my $mbuild = $KBS->builder, 'Get the store setup copy of builder';
    $mbuild->source_dir(join '/', updir, updir, 'lib');
    $mbuild->base_dir(curdir);
    $mbuild->quiet(1);

    # Build the test database.
    ok $KBS->test_setup, 'Run test_setup on current Kinetic build';
    $mbuild->init_app;

    # Make sure that we have the system views.
    my $dbh = test_store(
        \%tconf,
        $schema,
        qw(contact contact_type version_info)
    );

    # Make sure that none of the sample views exist.
    for my $key (qw(comp_comp composed extend one relation simple two types_test)) {
        dies_ok { $dbh->selectcol_arrayref("SELECT 1 FROM $key") }
            "The $key view should not exist";
    }
    $dbh->disconnect;

    # Now install the sample app.
    # Create a new build object, so that it knows that the database exists.
    push @ARGS, '--db-file' => catfile qw(t data kinetic.db)
        if $STORE eq 'sqlite';
    ok $builder = new_builder(dev_tests => 1 ),
        'Create new builder for testing install';

    # Prevent Module::Build's test action from running.
    $mb_mocker->mock(ACTION_install => undef );

    # Install it!
    $builder->dispatch('install');

    # Now the sample views should exist in the database.
    $dbh = dbi_connect(@{$tconf{store}}{qw(dsn db_user db_pass)});
    for my $key (qw(comp_comp composed extend one relation simple two types_test)) {
        ok $dbh->selectcol_arrayref("SELECT 1 FROM $key"),
            "The $key view should exist";
    }

    # Tear down the test database.
    $dbh->disconnect;
    ok $KBS->test_cleanup, 'Cleanup Kinetic data store';
    $KBS = undef; # Prevent cleanup in END block
    dies_ok { dbi_connect(@{$tconf{store}}{qw(dsn db_user db_pass)}) }
        'And now the database should be gone again';
}


##############################################################################
sub new_builder {
    local @ARGV = @ARGS;
    push @builders, $CLASS->new(
        module_name     => 'TestApp::Simple',
        quiet           => 1,
        install_base    => updir,
        accept_defaults => 1,
        store           => $STORE,
        test_cleanup    => 1, # Change to 0 to leave the data store
        @_,
    );
    return $builders[-1];
}

##############################################################################

sub dbi_connect {
    DBI->connect(@_, { RaiseError => 1, PrintError => 0 })
}

##############################################################################

sub test_store {
    my ($conf, $schema) = ( shift, shift );
    my @check_keys = @_ ? @_ : qw(
        comp_comp composed contact contact_type extend one
        relation simple two types_test version_info yello
    );

    # We'll run tests during the test action here. Sneaky, huh?
    my @keys = sort map { $_->key } $schema->classes;
    is_deeply \@keys, \@check_keys,
        ,
        'Both TestApp and Kinetic classes should now be loaded';
    ok my $dbh = dbi_connect(@{$conf->{store}}{qw(dsn db_user db_pass)}),
        'Now we should be able to connect to the test database';
    # Make sure that views exist for all of the keys.
    for my $key (@check_keys) {
        ok $dbh->selectcol_arrayref("SELECT 1 FROM $key"),
            "The $key view should exist";
    }

    return $dbh;
}

1;
__END__
