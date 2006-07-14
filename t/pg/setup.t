#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 17;
use Test::NoWarnings; # Adds an extra test.
use Test::Exception;
use Test::File;
use utf8;

BEGIN {
    use_ok 'Kinetic::Store::Setup::DB::Pg' or die;
}

##############################################################################
# Test PostgreSQL implementation.
ok my $setup = Kinetic::Store::Setup::DB::Pg->new,
    'Create PostgreSQL setup object';

is $setup->user, 'kinetic', 'The username should be "kinetic"';
is $setup->pass, '', 'The password should be ""';
is $setup->dsn,  'dbi:Pg:dbname=kinetic',
    'The dsn should be "dbi:Pg:dbname=kinetic"';

is $setup->super_user,   'postgres', 'The superuser should be "postgres"';
is $setup->super_pass,   '', 'The superuser password should be ""';
is $setup->template_dsn, 'dbi:Pg:dbname=template1',
    'The template dsn should be "dbi:Pg:dbname=template1"';

ok $setup = Kinetic::Store::Setup::DB::Pg->new({
    user         => 'foo',
    pass         => 'bar',
    super_user   => 'hoo',
    super_pass   => 'yoo',
    dsn          => 'dbi:Pg:dbname=foo',
    template_dsn => 'dbi:Pg:dbname=template0',
}), 'Create PostgreSQL setup object with parameters';

is $setup->user, 'foo', 'The username should be "foo"';
is $setup->pass, 'bar', 'The password should be "bar"';
is $setup->dsn,  'dbi:Pg:dbname=foo',
    'The dsn should be "dbi:Pg:dbname=foo"';

is $setup->super_user,       'hoo', 'The superuser should be "hoo"';
is $setup->super_pass,       'yoo', 'The superuser password should be "yoo"';
is $setup->template_dsn, 'dbi:Pg:dbname=template0',
    'The template dsnshould be "dbi:Pg:dbname=template0"';

SKIP: {
    skip 'Not testing a live PostgreSQL database', 1
        unless $ENV{KS_CLASS} && $ENV{KS_CLASS} =~ /DB::Pg$/;

    ok $setup = Kinetic::Store::Setup::DB::Pg->new({
        user         => $ENV{KS_USER},
        pass         => $ENV{KS_PASS},
        super_user   => $ENV{KS_SUPER_USER},
        super_pass   => $ENV{KS_SUPER_PASS},
        dsn          => $ENV{KS_DSN},
        template_dsn => $ENV{KS_TEMPLATE_DSN},
    }), 'Create PostgreSQL setup object with live parameters';
}
