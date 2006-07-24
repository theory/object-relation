#!/usr/bin/perl -w

# $Id: store.t 3063 2006-07-21 23:07:19Z theory $

use warnings;
use strict;
use Test::File;

BEGIN {
    unless ($ENV{KS_CLASS} && $ENV{KS_CLASS} =~ /DB::Pg$/) {
        require Test::More;
        Test::More::plan( skip_all => 'Not testing live PostgreSQL store' );
    }
}

use lib qw(t/lib t/sample/lib);

use TEST::Kinetic::TestSetup (
    class        => $ENV{KS_CLASS},
    user         => $ENV{KS_USER}         || '',
    pass         => $ENV{KS_PASS}         || '',
    super_user   => $ENV{KS_SUPER_USER}   || '',
    super_pass   => $ENV{KS_SUPER_PASS}   || '',
    dsn          => $ENV{KS_DSN}          || '',
    template_dsn => $ENV{KS_TEMPLATE_DSN} || '',
);

use TEST::Class::Kinetic 't/store';

TEST::Class::Kinetic->runall;
