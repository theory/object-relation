#!/usr/bin/perl -w

# $Id: setup.t 3046 2006-07-18 05:43:21Z theory $

use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'Not testing live PostreSQL server'
        unless $ENV{KS_SUPER_USER} && $ENV{KS_CLASS} =~ /DB::Pg$/;
#    plan tests => 3;
    plan 'no_plan';
}

use Test::NoWarnings; # Adds an extra test.

BEGIN {
    use_ok 'Kinetic::Store::Setup::DB::Pg' or die;
    $ENV{KS_DSN}  ||= '__kinetic_test__';
    $ENV{KS_USER}||= '__kinetic_test__';
}

ok my $setup = Kinetic::Store::Setup::DB::Pg->new({
    user         => $ENV{KS_USER},
    pass         => $ENV{KS_PASS},
    super_user   => $ENV{KS_SUPER_USER},
    super_pass   => $ENV{KS_SUPER_PASS},
    dsn          => $ENV{KS_DSN},
    template_dsn => $ENV{KS_TEMPLATE_DSN},
}), 'Create PostgreSQL setup object with possible live parameters';

END {
    $setup->disconnect_all;
}

##############################################################################
# Make sure that we can connect to the database.
my $dbh = eval {
    $setup->connect(
        $setup->template_dsn,
        $setup->super_user,
        $setup->super_pass,
    )
};

if (my $err = $@) {
    diag "Looks like we couldn't connect to the template database.\n",
         "Make sure that the KS_SUPER_USER, KS_DSN, and KS_TEMPLATE_DSN\n",
         "environment variables are properly set.\n";
    die $err;
}

ok $dbh, 'We should be connected to the template1 database';
