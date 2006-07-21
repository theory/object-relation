package TEST::Kinetic::Store::Handle::DB::SQLite;

# $Id$

use strict;
use warnings;

use base 'TEST::Kinetic::Store::Handle::DB';
use Test::More;
use Test::Exception;
use Kinetic::Store::Handle qw/:all/;

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

# Skip all of the tests in this class if SQLite isn't supported.
__PACKAGE__->SKIP_CLASS(
    $ENV{KS_CLASS} && $ENV{KS_CLASS} =~ /DB:SQLite$/
    ? 0
    : 'Not testing live data store',
) if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub full_text_search : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = $test->test_objects;
    my $class = $foo->my_class;
    my $store = Kinetic::Store::Handle->new;
    throws_ok {$store->query($class => 'full text search string')}
        'Kinetic::Store::Exception::Fatal::Unsupported',
        'SQLite should die if a full text search is attempted';
}

sub test_boolean : Test(6) {
    my $self = shift;
    $self->clear_database;

    my $dbh = $self->dbh;
    throws_ok {
        $dbh->do(
            q{INSERT INTO one(name, bool) VALUES(?, ?)},
            {},
            'Name',
            12,
        ),
    } 'Kinetic::Store::Exception::DBI',
        'INSERTing an invalid bool should generate an error';
    like $@,
        qr/value for domain boolean violates check constraint "ck_boolean"/,
        '... And the error message should be correct';

    ok my $one = One->new(name => 'One'), 'Create One object';
    ok $one->save, '... And save it';
    throws_ok {
        $dbh->do(
            q{UPDATE one SET bool = ? WHERE uuid = ?},
            {},
            12,
            $one->uuid,
        ),
    } 'Kinetic::Store::Exception::DBI',
        'UPDATINGing  withan invalid bool should generate an error';
    like $@,
        qr/value for domain boolean violates check constraint "ck_boolean"/,
        '... And the error message should be correct';
}

1;
