package TEST::Kinetic::Store::DB::SQLite;

# $Id$

use strict;
use warnings;

use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::SQLite' };
use Kinetic::Build::Schema::DB::SQLite; # this seems a bit weird
use Test::More;
use base 'TEST::Kinetic::Store';
use lib '../../lib';

# we load Schema first because this class tells the others
# to use their appropriate Schema counterparts.  This is not
# intuitive and will possibly have to be changed at some point.
#use aliased 'Kinetic::Build::Schema';
use aliased 'Test::MockModule';
use aliased 'Sub::Override';

#use aliased 'Kinetic::Build';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Util::State';
use aliased 'Kinetic::Store::DB::SQLite' => 'Store';
use aliased 'Kinetic::Build::Store'      => 'BStore';

__PACKAGE__->runtests;

sub _build_args {
    my $test = shift;
    return (
        module_name     => 'KineticBuildOne',
        conf_file       => 'test.conf', # always writes to t/ and blib/
        accept_defaults => 1,
        source_dir      => $test->_test_lib,,
        quiet           => 1,
    );
}

sub load_classes : Test(startup => 4) {
    my $test     = shift;
    my $db = File::Spec->catfile($test->_start_dir, qw/t build_sample kinetic.db/);
    if (-e $db) {
        # a previous test failure might not unlink this properly
        unlink $db or die "Cannot unlink ($db): $!";
    }
#    my $build = Build->new($test->_build_args);
#
#    $build->dispatch('build');
#    # we must call "create_build_script" because bstore calls resume()
#    # internally
#    $build->create_build_script;
    my $bstore = BStore->new;
    chdir 't';
    chdir 'build_sample';

    $bstore->build;
    my $schema = $bstore->_schema_class->new;
    $schema->load_classes($test->_test_lib);
    my $dbh = $bstore->_dbh;
    $dbh->do($_) foreach
      $schema->begin_schema,
      $schema->setup_code,
      (map { $schema->schema_for_class($_) } $schema->classes),
      $schema->end_schema;
    $test->{dbh} = $bstore->_dbh;
    Store->_dbh($test->{dbh});

    my @tables = map { $_->table } $schema->classes;
    can_ok $bstore, '_dbh';
    ok $dbh = $bstore->_dbh, 'And it should return a database handle';
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
    $test->{dbh}->disconnect if $test->{dbh};
    my $db = File::Spec->catfile($test->_start_dir, qw/t build_sample kinetic.db/);
    unlink $db or die "Cannot unlink ($db): $!";
};

sub setup : Test(setup) {  
    my $test = shift;
    $test->{dbh}->begin_work if $test->{dbh};
}

sub teardown : Test(teardown) {
    my $test = shift;
    $test->{dbh}->rollback if $test->{dbh};
}

#sub foo:Test(1){ok 1}
#
#1;
#__END__
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
