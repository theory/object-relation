#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;

use Kinetic::Util::Config ':store';
use Kinetic::Util::Exceptions;
use DBI;

my $dsn = 'dbi:Pg:dbname=' . STORE_TEMPLATE_DB_NAME;

if (my ($host) = STORE_DSN =~ /host=([^;]+)/) {
    $dsn .= ";host=$host";
}
if (my ($port) = STORE_DSN =~ /port=(\d+)/) {
    $dsn .= ";port=$port";
}
my ($db) = STORE_DSN =~ /dbname=([^;]+)/
    or die 'Could not extract datbase name from "' . STORE_DSN . '"';

my $dbh = DBI->connect( $dsn, STORE_DB_SUPER_USER, STORE_DB_SUPER_PASS, {
    RaiseError     => 0,
    PrintError     => 0,
    pg_enable_utf8 => 1,
    HandleError    => Kinetic::Util::Exception::DBI->handler,
});

for (0..1) {
    sleep 1 while $dbh->selectrow_array(
        'SELECT 1 FROM pg_stat_activity where datname = ?',
        undef, $db
    );
}

$dbh->do(qq{DROP DATABASE "$db"});
$dbh->do('DROP USER "' . STORE_DB_USER . '"');
$dbh->disconnect;
