#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;

use Kinetic::Util::Config ':sqlite';
use aliased 'Kinetic::Build::Schema::DB::SQLite';
use File::Path;
use File::Spec::Functions;
use DBI;

mkpath catdir 't', 'data';
my $schema = SQLite->new;
$schema->load_classes('t/sample/lib');
my $dbh = DBI->connect('dbi:SQLite:dbname=' . SQLITE_FILE, '', '');
$dbh->begin_work;

eval {
    $dbh->do($_) foreach
      $schema->begin_schema,
      $schema->setup_code,
      (map { $schema->schema_for_class($_) } $schema->classes),
      $schema->end_schema;
    $dbh->commit;
};
if (my $err = $@) {
    $dbh->rollback;
    die $err;
}

END {
    $dbh->disconnect;
}
