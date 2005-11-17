package TEST::Kinetic::Format;

# $Id: JSON.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';

use Test::JSON;
use Test::More;
use Test::Exception;

use Class::Trait qw( TEST::Kinetic::Traits::Store );

use Kinetic::Util::Constants qw/UUID_RE/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

use Readonly;
Readonly my $FORMAT => 'Kinetic::Format';
Readonly my $JSON   => "${FORMAT}::JSON";

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub setup : Test(setup) {
    my $test = shift;
    $test->mock_dbh;
    $test->create_test_objects;
}

sub teardown : Test(teardown) {
    my $test = shift;
    $test->unmock_dbh;
}

sub constructor : Test(5) {
    my $test = shift;
    can_ok $FORMAT, 'new';
    throws_ok { $FORMAT->new } 'Kinetic::Util::Exception::Fatal',
      '... and trying to create a new formatter without a format should fail';

    throws_ok { $FORMAT->new( { format => 'no_such_format' } ) }
      'Kinetic::Util::Exception::Fatal::InvalidClass',
      '... as should trying to create a new formatter with an invalid class';

    ok my $formatter = $FORMAT->new( { format => 'json' } ),
      '... and calling it should succeed';

    isa_ok $formatter, $JSON, '... and the object it returns';
}

sub interface : Test(4) {
    my $test      = shift;
    my $formatter = bless {}, $FORMAT;

    can_ok $formatter, 'serialize';
    throws_ok { $formatter->serialize }
      'Kinetic::Util::Exception::Fatal::Unimplemented',
      '... and calling it should fail';

    can_ok $formatter, 'deserialize';
    throws_ok { $formatter->deserialize }
      'Kinetic::Util::Exception::Fatal::Unimplemented',
      '... and calling it should fail';
}

1;
