package TEST::Kinetic::Build::Store::DB::SQLite;

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Store::DB';
use Test::More;

sub test_class_methods : Test(6) {
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
    is $class->dbd_class, 'DBD::SQLite',
      'We should have the correct DBD class';
    is $class->dsn_dbd, 'SQLite',
      'We should have the correct DSN DBD string';
}

1;
__END__
