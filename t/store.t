#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use lib qw(t/lib t/sample/lib);
use TEST::Kinetic::TestSetup qw(--source-dir t/sample/lib --no-init);
use TEST::Class::Kinetic 't/store';

TEST::Class::Kinetic->runall;

__END__
