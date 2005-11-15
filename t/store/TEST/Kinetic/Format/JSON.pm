package TEST::Kinetic::Format::JSON;

# $Id: JSON.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';

use Test::JSON;
use Test::More;
use Test::Exception;

use TEST::Kinetic::Traits::Store qw/:all/;

use Kinetic::Util::Constants qw/UUID_RE/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(0) }

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

use Readonly;
Readonly my $JSON => 'Kinetic::Format::JSON';

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub setup : Test(setup) {
    my $test  = shift;
    $test->mock_dbh;
    $test->create_test_objects;
}

sub teardown : Test(teardown) {
    my $test = shift;
    $test->unmock_dbh;
}

sub constructor : Test(3) {
    my $test = shift;
    can_ok $JSON, 'new';
    ok my $formatter = $JSON->new, '... and calling it should succeed';
    isa_ok $formatter, $JSON, '... and the object it returns';
}

sub render : Test(4) {
    my $test = shift;
    my $formatter = $JSON->new( { pretty => 1, indent => 2 } );
    my ( $foo, $bar, $baz ) = $test->test_objects;
    can_ok $formatter, 'render';
    ok my $json = $formatter->render($foo),
      '... and rendering an object should succeed';
    is_valid_json $json, '... and it should return valid json';
    $json =~ s/@{[UUID_RE]}/XXX/g;
    my $expected = <<'    END_EXPECTED';
        {
            "_key"        : "one",
            "bool"        : 1,
            "description" : null,
            "name"        : "foo",
            "state"       : 1,
            "uuid"        : "XXX"
        }
    END_EXPECTED
    is_json $json, $expected, '... and it should return the correct JSON';
}

sub restore : Test(3) {
    my $test = shift;
    my $formatter = $JSON->new( { pretty => 1, indent => 2 } );
    my ( $foo, $bar, $baz ) = $test->test_objects;
    can_ok $formatter, 'restore';
    my $json = $formatter->render($foo);

    my $bad_key = $json;
    $bad_key =~ s/one/no_such_key/;

    throws_ok { $formatter->restore($bad_key) }
      'Kinetic::Util::Exception::Fatal::InvalidClass',
      '... and it should throw an exception if it finds an invalid key';

    my $new_foo = $formatter->restore($json);
    foreach ( $new_foo, $foo ) {

        # XXX we have to do this because id exists in the objects, but not in
        # the json so it doesn't persist and is therefore not returned.
        delete $_->{id};
    }

    is_deeply $new_foo, $foo,
      '... and it should be able to restore a Kinetic object from JSON';
}

sub save : Test(no_plan) {
    my $test = shift;
    my $formatter = $JSON->new( { pretty => 1, indent => 2 } );
    my ( $foo, $bar, $baz ) = $test->test_objects;
    can_ok $formatter, 'save';

    # update an existing object

    my $json        = $formatter->render($foo);
    my $value_for   = $formatter->jsonToObj($json);
    my $description = 'This is a new description';
    $value_for->{description} = $description;
    $json = $formatter->objToJson($value_for);
    ok my $new_foo = $formatter->save($json),
      '... and saving an object should succeed';
    is $new_foo->{id}, $foo->{id},
      '... and the new object should have the correct id';
    is $new_foo->uuid, $foo->uuid, '... and we should get the same object back';
    is $new_foo->description, $description,
      '... and it should have a new description';
    my $new_foo2 = One->lookup( uuid => $foo->uuid );
    is_deeply $new_foo2, $new_foo,
      '... and the object should be in the data store';

    # save a new object

    my $name     = "Ovid";
    my $new_desc = 'new description';
    {
        my $new_object = One->new;
        $new_object->name($name);
        $new_object->description($new_desc);
        $json = $formatter->render($new_object);
    }
    ok my $new_object = $formatter->save($json),
      'We should be able to save a new object';
    is $new_object->name, $name, '... and it should have the correct name';
    is $new_object->description, $new_desc,
      '... and it should have the correct description';
}

1
