package TEST::Kinetic::Store::DB::SQLite;

# $Id$

use strict;
use warnings;

use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::SQLite' };
use Kinetic::Build::Schema::DB::SQLite; # this seems a bit weird
use Test::More;
use base 'Test::Class';
use Cwd;
use lib '../../lib';

# we load Schema first because this class tells the others
# to use their appropriate Schema counterparts.  This is not
# intuitive and will possibly have to be changed at some point.
#use aliased 'Kinetic::Build::Schema';
use aliased 'Test::MockModule';
use aliased 'Sub::Override';

use aliased 'Kinetic::Build';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Util::State';
use aliased 'Kinetic::Store::DB::SQLite' => 'Store';
use aliased 'Kinetic::Build::Store'      => 'BStore';

my $hex = qr/[0-9A-F]/;
sub UUID () { qr/^$hex{8}-$hex{4}-$hex{4}-$hex{4}-$hex{12}$/ }

__PACKAGE__->runtests;

sub _load_classes : Test(startup => 4) {
    my $test     = shift;
    $test->{cwd} = getcwd;
    my $db = File::Spec->catfile($test->{cwd}, qw/t build_sample kinetic.db/);
    if (-e $db) {
        # a previous test failure might not unlink this properly
        unlink $db or die "Cannot unlink ($db): $!";
    }
    chdir 't';
    chdir 'build_sample';
    my $test_lib = File::Spec->catfile($test->{cwd}, qw/t lib/);

    my $build = Build->new(
        module_name     => 'KineticBuildOne',
        conf_file       => 'test.conf', # always writes to t/ and blib/
        accept_defaults => 1,
        source_dir      => $test_lib,
        quiet           => 1,
    );
    $build->dispatch('build');
    # we must call "create_build_script" because bstore calls resume()
    # internally
    $build->create_build_script;
    my $bstore = BStore->new;
    $bstore->build;
    my $schema_class = $bstore->_schema_class;
    eval "user $schema_class";
    my $schema = $schema_class->new;
    $schema->load_classes($test_lib);
    $test->{dbh} = $bstore->_dbh;
    Store->_dbh($test->{dbh});

    my @tables = map { $_->table } $schema->classes;
    can_ok $bstore, '_dbh';
    ok my $dbh = $bstore->_dbh, 'And it should return a database handle';
    isa_ok $dbh, 'DBI::db' => 'And the handle';

    my $num_tables = 0;
    foreach my $table (@tables) {
        my $sql = "SELECT * FROM $table";
        eval {$dbh->selectall_arrayref($sql)};
        $num_tables++ unless $@;
    }
    is @tables, $num_tables, 'And the database should be set up correctly';
}

sub shutdown : Test(shutdown) {
    chdir '..';
    chdir '..';
    my $test = shift;
    Store->_dbh->disconnect;
    my $db = File::Spec->catfile($test->{cwd}, qw/t build_sample kinetic.db/);
    unlink $db or die "Cannot unlink ($db): $!";
};

sub setup : Test(setup) {
    Store->_dbh->begin_work;
}

sub teardown : Test(teardown) {
    Store->_dbh->rollback;
}

sub insert : Test(8) {
    my $mock_store = MockModule->new(Store);
    my ($SQL, $BIND);
    $mock_store->mock(_do_sql => 
        sub { 
            my $self = shift; 
            $SQL     = shift; 
            $BIND    = shift;
            $self 
        } 
    );

    my $class = Meta->for_key('one');
    my $ctor  = $class->constructors('new');
    my $one = $ctor->call($class->package);
    $mock_store->mock(_set_id => sub { $one->{id} = 2002 } );
    $one->name('Ovid');
    $one->description('test class');

    can_ok Store, '_insert';
    my $expected    = q{INSERT INTO one (guid, name, description, state, bool) VALUES (?, ?, ?, ?, ?)};
    my $bind_params = [
        'Ovid',
        'test class',
        '1', # state: Active
        '1'  # bool
    ];
    ok ! exists $one->{id}, 'And a new object should not have an id';
    ok Store->_insert($one),
        'and calling it should succeed';
    is $SQL, $expected,
        'and it should generate the correct sql';
    my $uuid = shift @$BIND;
    like $uuid, UUID, 'with the UUID in the bind params';
    is_deeply $BIND, $bind_params,
        'and the correct bind params';
    ok exists $one->{id}, 'and an id should be created';
    is $one->{id}, 2002, 'and it should have the last insert id the database returned';
}

sub update : Test(7) {
    my $mock_store = MockModule->new(Store);
    my ($SQL, $BIND);
    $mock_store->mock(_do_sql => 
        sub { 
            my $self = shift; 
            $SQL     = shift; 
            $BIND    = shift;
            $self 
        } 
    );

    my $class = Meta->for_key('one');
    my $ctor  = $class->constructors('new');
    my $one = $ctor->call($class->package);
    $one->name('Ovid');
    $one->description('test class');
    can_ok Store, '_update';
    $one->{id} = 42;
    # XXX The guid should not change, should it?  I should 
    # exclude it from this?
    my $expected = "UPDATE one SET guid = ?, name = ?, description = ?, "
                  ."state = ?, bool = ? WHERE guid = ?";
    my $bind_params = [
        'Ovid',
        'test class',
        '1', # state: Active
        '1'  # bool
    ];
    ok Store->_update($one),
        'and calling it should succeed';
    is $SQL, $expected,
        'and it should generate the correct sql';
    my $uuid  = shift @$BIND;
    my $uuid2 = pop @$BIND;
    is $uuid, $uuid2, 'and the uuid should not change if we have not changed it';
    like $uuid, UUID, 'with the UUID in the bind params';
    is_deeply $BIND, $bind_params,
        'and the correct bind params';
    is $one->{id}, 42, 'and the private id should not be changed';
}

sub save : Test(7) {
    my $test  = shift;
    my $class = Meta->for_key('one');
    my $ctor  = $class->constructors('new');
    my $one = $ctor->call($class->package);
    $one->name('Ovid');
    $one->description('test class');

    can_ok Store, 'save';
    my $dbh = Store->_dbh;
    my $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one');
    ok ! $result, 'We should start with a fresh database';
    ok Store->save($one), 'and saving an object should be successful';
    $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one');
    $result->{state} = State->new($result->{state});
    # XXX this works, but it might be a bit fragile
    is_deeply $one, $result, 'and the data should match what we pull from the database';
    is $test->_num_recs('one'), 1, 'and we should have one record in the view';

    my $two = $ctor->call($class->package);
    $two->name('bob');
    $two->description('some description');
    Store->save($two);
    is $test->_num_recs('one'), 2, 'and we should have two records in the view';
    $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one WHERE name = \'bob\'');
    $result->{state} = State->new($result->{state});
    is_deeply $two, $result, 'and the data should match what we pull from the database';
}

sub lookup : Test(no_plan) {
    my $test  = shift;
    my $class = Meta->for_key('one');
    my $ctor  = $class->constructors('new');

    my $one   = $ctor->call($class->package);
    $one->name('Ovid');
    $one->description('test class');
    Store->save($one);

    my $two   = $ctor->call($class->package);
    $two->name('divO');
    $two->description('ssalc tset');
    Store->save($two);
    can_ok Store, 'lookup';
    my $thing = Store->lookup($class, guid => $two->guid);
}

sub _num_recs {
    my ($self, $table) = @_;
    my $result = Store->_dbh->selectrow_arrayref("SELECT count(*) FROM $table");
    return $result->[0];
}

1;
