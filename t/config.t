#!perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 13;
use lib 't/lib';
use Kinetic::TestSetup;
use File::Spec;
use File::Find;

BEGIN {
    use_ok('Kinetic::Util::Config');
}

##############################################################################

# Find a list of all store classes, so that we can specifically test for them.
my %stores;
my $dir = File::Spec->catdir(qw(lib Kinetic Store), '');
find({ wanted  => sub {
           $stores{'Kinetic::Store' .
                     join '::', File::Spec->splitdir($_) } = 1
                       if !/\.svn/ && s/\.pm$// && s/^$dir//
                   },
       no_chdir => 1
     },
     $dir);

ALL: { # 3 tests.
    package Kinetic::Util::Config::TestAll;
    use Kinetic::Util::Config qw(:all);
    use Test::More;
    ok(APACHE_BIN, "Got apache_bin" );
    ok(STORE_CLASS, "Got store_class" );
    ok($stores{&STORE_CLASS}, "Got store_class value" );
}

APACHE: { # 2 tests.
    package Kinetic::Util::Config::TestApache;
    use Kinetic::Util::Config qw(:apache);
    use Test::More;
    ok(APACHE_BIN, "Got apache_bin" );
    eval "STORE_CLASS";
    ok($@, "Got error trying to access store_class");
}

STORE: { # 3 tests.
    package Kinetic::Util::Config::TestStore;
    use Kinetic::Util::Config qw(:store);
    use Test::More;
    ok(STORE_CLASS, "Got store_class" );
    ok($stores{&STORE_CLASS}, "Got store_class value" );
    eval "APACHE_BIN";
    ok($@, "Got error trying to access apache_bin");
}

PG: { # 2 tests.
    package Kinetic::Util::Config::TestPg;
    use Kinetic::Util::Config qw(:pg);
    use Test::More;
    ok(PG_DB_NAME, "Got store_class" );
    eval "STORE_CLASS";
    ok($@, "Got error trying to access store_class");
}

NOIMPORT: { # 2 tests.
    package Kinetic::Util::Config::TestNoImport;
    use Kinetic::Util::Config;
    use Test::More;
    eval "STORE_CLASS";
    ok($@, "Got error trying to access store_class");
    eval "APACHE_BIN";
    ok($@, "Got error trying to access apache_bin");
}

1;
__END__