#!perl -w

# $Id$

use strict;
use warnings;
#use Test::More qw/no_plan/;
use Test::More tests => 22;
use Test::NoWarnings; # Adds an extra test.
use Kinetic::Build::Test (auth => { protocol => [qw(Default LDAP)] });
use File::Spec;
use File::Find;

BEGIN {
    use_ok('Kinetic::Util::Config') or die;
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
    use Cwd 'getcwd';
    ok(STORE_CLASS, "Got store_class" );
    ok($stores{&STORE_CLASS}, "Got store_class value" );
    is(KINETIC_ROOT, getcwd(), 'Got the correct kinetic_root');
}

APACHE: { # 3 tests.
    package Kinetic::Util::Config::TestApache;
    use Test::More;
    eval "use Kinetic::Util::Config qw(:apache)";
    SKIP: {
        skip 'User did not choose Apache2 engine', 3, if $@;
        eval "STORE_CLASS";
        ok($@, "Got error trying to access store_class");
        ok(exists &APACHE_HTTPD, 'APACHE_HTTPD exists');
        ok(exists &APACHE_CONF, 'APACHE_CONF exists');
    }
}

CATALYST: { # 4 tests.
    package Kinetic::Util::Config::TestCatalyst;
    use Test::More;
    eval "use Kinetic::Util::Config qw(:catalyst)";
    SKIP: {
        skip 'User did not choose catalyst engine', 4, if $@;
        eval "STORE_CLASS";
        ok($@, "Got error trying to access store_class");
        ok(exists &CATALYST_PORT,    'catalyst port exists');
        ok(exists &CATALYST_HOST,    'catalyst host exists');
        ok(exists &CATALYST_RESTART, 'catalyst restart exists');
    }
}

STORE: { # 3 tests.
    package Kinetic::Util::Config::TestStore;
    use Kinetic::Util::Config qw(:store);
    use Test::More;
    ok(STORE_CLASS, "Got store_class" );
    ok($stores{&STORE_CLASS}, "Got store_class value" );
    eval "APACHE_USER";
    ok($@, "Got error trying to access apache_user");
}

USER: { # 2 tests.
    package Kinetic::Util::Config::TestUser;
    use Kinetic::Util::Config qw(:user);
    use Test::More;
    ok(USER_MIN_PASS_LEN, "Got USER_MIN_PASS_LEN" );
    eval "STORE_CLASS";
    ok($@, "Got error trying to access store_class");
}

NOIMPORT: { # 2 tests.
    package Kinetic::Util::Config::TestNoImport;
    use Kinetic::Util::Config;
    use Test::More;
    eval "STORE_CLASS";
    ok($@, "Got error trying to access store_class");
    eval "APACHE_USER";
    ok($@, "Got error trying to access apache_user");
}

AUTH: { # 3 tests.
    package Kinetic::Util::Config::TestAuth;
    use Kinetic::Util::Config qw(:auth);
    use Test::More;
    ok(AUTH_PROTOCOL, "Got AUTH_PROTOCOLS" );
    eval "STORE_CLASS";
    ok($@, "Got error trying to access store_class");
    is_deeply [AUTH_PROTOCOL], [qw(Default LDAP)],
        'AUTH_PROTOCOL should be a list';
}

1;
__END__
