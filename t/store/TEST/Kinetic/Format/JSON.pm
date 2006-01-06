package TEST::Kinetic::Format::JSON;

# $Id: JSON.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';

use Test::JSON;
use Test::More;
use Test::Exception;
use Class::Trait qw(
  TEST::Kinetic::Traits::Store
  TEST::Kinetic::Traits::SampleObjects
);

use Kinetic::Util::Constants qw/$UUID_RE/;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'Kinetic::DateTime';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';   # contains a TestApp::Simple::One object

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
    my $test = shift;
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

sub serialize : Test(7) {
    my $test = shift;
    my $formatter = $JSON->new( { pretty => 1, indent => 2 } );
    my ( $foo, $bar, $baz ) = $test->test_objects;
    $foo->_save_prep;    # Force UUID generation.
    can_ok $formatter, 'serialize';
    ok my $json = $formatter->serialize($foo),
      '... and serializing an object should succeed';
    is_valid_json $json, '... and it should return valid JSON';
    $json =~ s/$UUID_RE/XXX/g;
    my $expected = <<'    END_EXPECTED';
        {
            "Key"        : "one",
            "bool"        : 1,
            "description" : null,
            "name"        : "foo",
            "state"       : 1,
            "uuid"        : "XXX"
        }
    END_EXPECTED
    is_json $json, $expected, '... and it should return the correct JSON';

    # test contained object serialization

    my $two = Two->new;
    $two->_save_prep;    # Force UUID generation.
    $two->name('june17');
    $two->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $two->one($foo);
    $ENV{DEBUG} = 1;
    ok $json = $formatter->serialize($two),
      'Serializing an object with a contained object should succeed';
    $ENV{DEBUG} = 0;
    is_valid_json $json, '... and it should return valid JSON';
    $json =~ s/$UUID_RE/XXX/g;

    $expected = <<'    END_EXPECTED';
    {
      "one" : {
          "bool"        : 1,
          "name"        : "foo",
          "uuid"        : "XXX",
          "description" : null,
          "state"       : 1,
          "Key"         : "one"
      },
      "date"        : "1968-06-17T00:00:00",
      "name"        : "june17",
      "Key"         : "two",
      "uuid"        : "XXX",
      "description" : null,
      "age"         : null,
      "state"       : 1
    }
    END_EXPECTED
    is_json $json, $expected, '... and the JSON should be the correct JSON';
}

sub deserialize : Test(5) {
    my $test = shift;
    my $formatter = $JSON->new( { pretty => 1, indent => 2 } );
    my ( $foo, $bar, $baz ) = $test->test_objects;
    can_ok $formatter, 'deserialize';
    my $json = $formatter->serialize($foo);

    my $bad_key = $json;
    $bad_key =~ s/one/no_such_key/;

    throws_ok { $formatter->deserialize($bad_key) }
      'Kinetic::Util::Exception::Fatal::InvalidClass',
      '... and it should throw an exception if it finds an invalid key';

    my $new_foo = $formatter->deserialize($json);
    foreach ( $new_foo, $foo ) {

        # XXX we have to do this because id exists in the objects, but not in
        # the json so it doesn't persist and is therefore not returned.
        delete $_->{id};
    }

    is_deeply $new_foo, $foo,
      '... and it should be able to deserialize a Kinetic object from JSON';

    # test contained objects

    my $two = Two->new;
    $two->name('june17');
    $two->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $two->one($foo);
    $json = $formatter->serialize($two);
    ok my $new_object = $formatter->deserialize($json),
      'We should be able to deserialize contained JSON objects';
    $test->force_inflation($new_object);

    foreach ( $two, $new_object ) {
        delete $_->{id};
        delete $_->one->{id};
    }
    is_deeply $two, $new_object,
      '... and the should return the correct object';
}

sub content_type : Test(2) {
    my $test      = shift;
    my $formatter = $JSON->new;
    can_ok $formatter, 'content_type';
    is $formatter->content_type, 'text/plain',
      '... and it should return the correct content type';
}

1
