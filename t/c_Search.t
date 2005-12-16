
use Test::More tests => 3;
use_ok( Catalyst::Test, 'Kinetic::UI::Catalyst' );
use_ok('Kinetic::UI::Catalyst::C::Search');

ok( request('search')->is_success );

