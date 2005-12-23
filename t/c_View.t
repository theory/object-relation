
use Test::More tests => 3;
use_ok( Catalyst::Test, 'Kinetic::UI::Catalyst' );
use_ok('Kinetic::UI::Catalyst::C::View');

ok( request('view')->is_success );

