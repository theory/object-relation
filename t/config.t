#!perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 25;
use Test::NoWarnings; # Adds an extra test.
use Kinetic::Build::Test;
use File::Spec;
use File::Find;

BEGIN {
    use_ok('Kinetic::Util::Config') or die;
}

##############################################################################

# test the various config parser bits so we can make sure they are performing
# as expected.
my @comments = ( <<'END1', <<'END2', <<'END3', <<'END4');
# comment 1
END1
    # comment 2
END2
# comment 3
    # comment 4
END3

    # test comment

END4

my $comma_re   = Kinetic::Util::Config::_comma_re();
my $comment_re = Kinetic::Util::Config::_comment_re();
foreach my $comment (@comments) {
    like $comment, qr/^$comment_re$/, 'comment_re matches';
}

my @pairs = (
    "group => 'nobody',",
    "httpd => '/usr/local/apache/bin/httpd',",
    "user  => 'nobody',",
    "conf  => '/usr/local/kinetic/conf/httpd.conf',",
    "port  => 80,",
);
my $pair_re = Kinetic::Util::Config::_pair_re();
foreach my $pair (@pairs) {
    like $pair, qr/^$pair_re\s*$comma_re?$/, qq{"$pair" is a pair};
}

my @hash_body = ( <<'END1', <<'END2');
{
    group => 'nobody',
    httpd => '/usr/local/apache/bin/httpd',
    user  => 'nobody',
    conf  => '/usr/local/kinetic/conf/httpd.conf',
    port  => 80,
},
END1
{
    class => 'Kinetic::Store::DB::SQLite',
},
END2

my $hash_body_re = Kinetic::Util::Config::_hash_body_re();
foreach my $hash_body (@hash_body) {
    like $hash_body, qr/^$hash_body_re\s*$comma_re\s*$/, 'hash body matches';
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
    ok(APACHE_USER, "Got apache_user" );
    ok(STORE_CLASS, "Got store_class" );
    ok($stores{&STORE_CLASS}, "Got store_class value" );
}

APACHE: { # 2 tests.
    package Kinetic::Util::Config::TestApache;
    use Kinetic::Util::Config qw(:apache);
    use Test::More;
    ok(APACHE_USER, "Got apache_user" );
    eval "STORE_CLASS";
    ok($@, "Got error trying to access store_class");
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

1;
__END__
