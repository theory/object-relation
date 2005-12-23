#!perl

use Test::More tests => 3;

BEGIN {
    # XXX Catalyst tests must not be run from the t/ directory
    use lib 'lib';
    use_ok( Catalyst::Test, 'Kinetic::UI::Catalyst' ) or die;
    use_ok('Kinetic::UI::Catalyst::C::Search') or die;
}

ok( request('search')->is_success );

