#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Store::Setup;

# Assume everything.
my $setup = Kinetic::Store::Setup->new({
    class => $ENV{KS_CLASS},
    user         => $ENV{KS_USER},
    pass         => $ENV{KS_PASS},
    super_user   => $ENV{KS_SUPER_USER},
    super_pass   => $ENV{KS_SUPER_PASS},
    dsn          => $ENV{KS_DSN},
    template_dsn => $ENV{KS_TEMPLATE_DSN},
});

$setup->teardown;
