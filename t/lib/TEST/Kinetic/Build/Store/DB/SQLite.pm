package TEST::Kinetic::Build::Store::DB::SQLite;

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Store::DB';
use Test::More;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Build';
use Test::Exception;

__PACKAGE__->runtests;
sub test_class_methods : Test(8) {
    my $test = shift;
    my $class = $test->test_class;
    is $class->info_class, 'App::Info::RDBMS::SQLite',
      'We should have the correct App::Info class';
    is $class->min_version, '3.0.8',
      'We should have the correct minimum version number';
    is $class->max_version, 0,
      'We should have the correct maximum version number';
    is $class->schema_class, 'Kinetic::Build::Schema::DB::SQLite',
      'We should have the correct schema class';
    is $class->store_class, 'Kinetic::Store::DB::SQLite',
      'We should have the correct store class';
    is $class->dbd_class, 'DBD::SQLite',
      'We should have the correct DBD class';
    is $class->dsn_dbd, 'SQLite',
      'We should have the correct DSN DBD string';
    ok $class->rules, "We should get some rules";
}

sub test_new : Test(4) {
    my $self = shift;
    my $class = $self->test_class;
    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;
    isa_ok $kbs->builder, 'Kinetic::Build';
    isa_ok $kbs->info, $kbs->info_class;
}

sub test_rules : Test(8) {
    my $self = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;

    # Test behavior if SQLite is not installed
    my $info = MockModule->new($class->info_class);
    $info->mock(installed => 0);
    throws_ok { $kbs->validate }
      qr/SQLite does not appear to be installed/,
      '... and it should die if SQLite is not installed';

    # Test when SQLite is not the correct version.
    $info->mock(installed => 1);
    $info->mock(version => '2.0');
    throws_ok { $kbs->validate }
      qr/SQLite is not the minimum required version/,
      '... or if SQLite is not the minumum supported version';

    # Test when everything is cool.
    $info->mock(version => '3.0.8');
    $builder->mock(prompt => 'fooness');
    ok $kbs->validate,
      '... and it should return a true value if everything is ok';
    is $kbs->db_file, 'fooness',
      '... and set the db_file correctly';
    is_deeply $kbs->{actions}, [['build_db']],
      "... and the actions should be set up";

    # Check the DSNs.
    is $kbs->dsn, 'dbi:SQLite:dbname=fooness';
}

1;
__END__
