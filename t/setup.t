#!/usr/bin/perl -w

# $Id: accessors.t 3005 2006-07-11 21:46:22Z theory $

use strict;
use warnings;
#use Test::More tests => 118;
use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.
use Test::Exception;
use Test::File;
use File::Spec;
use utf8;

BEGIN {
    use_ok 'Kinetic::Store::Setup' or die;
}

my $db_file = File::Spec->catfile(File::Spec->tmpdir, 'kinetic.db');
END {
    unlink $db_file if -e $db_file;
}

# Make sure bad classes are bad.
throws_ok { Kinetic::Store::Setup->new({ class => 'Foo' }) }
    'Kinetic::Util::Exception::Fatal::InvalidClass',
    'Bogus setup class should throw an InvalidClass exception';

like $@->error, qr/I could not load the class “Foo”/,
    'The error message should be correct';

# Check the default subclass.
ok my $setup = Kinetic::Store::Setup->new, 'Create a new Setup object';
setup_isa($setup, 'Kinetic::Store::Setup::DB::SQLite');
can_ok $setup, qw(dsn user pass);

# Be explicit about subclasses.
setup_ctor('DB::SQLite');
setup_ctor('DB::Pg');

# Check the default values for the SQLite subclass.
is $setup->user, '', 'The username should be ""';
is $setup->pass, '', 'The password should be ""';
is $setup->dsn, "dbi:SQLite:dbname=$db_file",
    'The DSN should be the proper default value';
is_deeply [ $setup->class_dirs ], ['lib'],
    'The class_dirs should be [lib]';

# Make sure that explicit parameters are set.
ok $setup = Kinetic::Store::Setup->new({
    user       => 'foo',
    pass       => 'pass',
    dsn        => 'dbi:SQLite:dbname=foo',
    class_dirs => [qw(foo bar)],
}), 'Create a setup object with parameters';

is $setup->user, 'foo', 'The username should be "foo"';
is $setup->pass, 'pass', 'The password should be "pass"';
is $setup->dsn,  'dbi:SQLite:dbname=foo',
    'The dsn should be "dbi:SQLite:dbname=foo"';
is_deeply [ $setup->class_dirs ], [qw(foo bar)],
    'The class_dirs should be [qw(foo bar)]';

# Test the SQLite implementation.
ok $setup = Kinetic::Store::Setup->new, 'Create a default Setup object';
ok $setup->class_dirs('t/sample/lib'), 'Set the class_dirs for the sample';

file_not_exists_ok $db_file, 'The database file should not yet exist';
ok $setup->setup, 'Set up the database';
file_exists_ok $db_file, 'The database file should now exist';

# Make sure that everything has been created.
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '');
for my $view ( Kinetic::Meta->keys ) {
    my $class = Kinetic::Meta->for_key($view);
    my ($expect, $not) = $class->abstract
        ? ([], ' not')
        : ([[1]], '');
    is_deeply $dbh->selectall_arrayref(
        "SELECT 1 FROM sqlite_master WHERE type ='view' AND name = ?",
        {}, $view
    ), $expect, "View $view should$not exist";
}
$dbh->disconnect;

##############################################################################

sub setup_ctor {
    my $class = shift;
    my $full_class = "Kinetic::Store::Setup::$class";
    ok my $setup = Kinetic::Store::Setup->new({ class => $full_class }),
        'Create a new Setup object with the class specified';
    can_ok $setup, qw(dsn user pass);
    setup_isa($setup, $full_class);
    ok $setup = Kinetic::Store::Setup->new({ class => $class }),
        'Create a new Setup object with a partial class  name specified';
    setup_isa($setup, $full_class);
    can_ok $setup, qw(dsn user pass dbh setup build_db class_dirs);
    (my $store = $full_class) =~ s/Setup:://;
    is $full_class->store_class, $store, "The store class should be $store";
    is $setup->store_class, $store, "The instance store class should be $store";
    (my $schema = $full_class) =~ s/Setup/Schema/;
    is $full_class->schema_class, $schema, "The schema class should be $schema";
    is $setup->schema_class, $schema, "The instance schema class should be $schema";
}

sub setup_isa {
    my ($setup, $class) = @_;
    isa_ok $setup, 'Kinetic::Store::Setup', 'it';
    isa_ok $setup, 'Kinetic::Store::Setup::DB', 'it';
    isa_ok $setup, $class, 'it';
}
