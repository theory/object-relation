#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;

use Kinetic::Util::Config ':pg';
use Kinetic::Util::Exceptions;
use DBI;
my $dsn = 'dbi:Pg:dbname=' . PG_TEMPLATE_DB_NAME;
# I have to use the &s to prevent "Use of uninitialized value in concatenation
# (.) or string" warnings. Don't ask me why.
$dsn .= ':host=' . &PG_HOST if PG_HOST;
$dsn .= ':port=' . &PG_PORT if PG_PORT;
my $dbh = DBI->connect( $dsn, PG_DB_SUPER_USER, PG_DB_SUPER_PASS, {
    RaiseError     => 0,
    PrintError     => 0,
    pg_enable_utf8 => 1,
    HandleError    => Kinetic::Util::Exception::DBI->handler,
});

for (0..1) {
    sleep 1 while $dbh->selectrow_array(
        'SELECT 1 FROM pg_stat_activity where datname = ?',
        undef, PG_DB_NAME
    );
}

$dbh->do('DROP DATABASE "' . PG_DB_NAME . '"');
$dbh->do('DROP USER "' . PG_DB_USER . '"');
$dbh->disconnect;
