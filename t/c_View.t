
use Test::More tests => 5;
use Test::NoWarnings; # Adds an extra test.
use Test::Output;

use_ok( Catalyst::Test, 'Kinetic::UI::Catalyst' );
use_ok('Kinetic::UI::Catalyst::C::View');

stderr_like { ok request('view')->is_success, 'View should work' }
    qr/\[\w{3}\s\w{3}\s[ 123]\d\s\d{2}:\d{2}:\d{2}\s\d{4}\] \[catalyst\] \[debug\] login failed/,
    'Catalyst should output debugging info';

