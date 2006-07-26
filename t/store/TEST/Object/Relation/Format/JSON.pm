package TEST::Object::Relation::Format::JSON;

# $Id$

use strict;
use warnings;

use base 'TEST::Class::Object::Relation';

use Test::JSON;
use Test::More;
use Test::Exception;
use Class::Trait qw(
  TEST::Object::Traits::Store
  TEST::Object::Traits::SampleObjects
);

use Object::Relation::Functions qw/create_uuid/;

use aliased 'Test::MockModule';
use aliased 'Object::Relation::Handle' => 'Store', ':all';
use aliased 'Object::Relation::DataType::DateTime';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';   # contains a TestApp::Simple::One object

use aliased 'Object::Relation::Format::JSON';

BEGIN {

    # XXX This is necessary because sometimes the values in objects are
    # undefined and we really shouldn't care if they are, but this winds up
    # throwing some warnings that really aren't errors in this context
    $SIG{__WARN__} = sub {
        my $warning = shift;
        return if $warning =~ /Use of uninitialized value in subroutine entry/;
        warn $warning;
    };
}
__PACKAGE__->SKIP_CLASS(
    $ENV{OBJ_REL_CLASS}
    ? 0
    : 'Not testing live data store',
) if caller;    # so I can run the tests directly from vim
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
    can_ok JSON, 'new';
    ok my $formatter = JSON->new, '... and calling it should succeed';
    isa_ok $formatter, JSON, '... and the object it returns';
}

sub serialize : Test(7) {
    my $test = shift;

    # Force all UUIDs to be "UUID".
    my ( $foo, $bar, $baz ) = grep { $_->{uuid} = 'UUID' } $test->test_objects;

    my $formatter = JSON->new( { pretty => 1, indent => 2 } );
    can_ok $formatter, 'serialize';
    ok my $json = $formatter->serialize($foo),
      '... and serializing an object should succeed';
    is_valid_json $json, '... and it should return valid JSON';

    my $expected = <<'    END_EXPECTED';
        {
            "Key"         : "one",
            "bool"        : "1",
            "description" : null,
            "name"        : "foo",
            "state"       : "1",
            "uuid"        : "UUID"
        }
    END_EXPECTED
    is_json $json, $expected, '... and it should return the correct JSON';

    # test contained object serialization

    my $two = Two->new;
    $two->{uuid} = 'UUID';
    $two->name('june17');
    $two->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $two->one($foo);
    ok $json = $formatter->serialize($two),
      'Serializing an object with a contained object should succeed';
    is_valid_json $json, '... and it should return valid JSON';

    $expected = <<'    END_EXPECTED';
    {
      "one" : {
          "bool"        : "1",
          "name"        : "foo",
          "uuid"        : "UUID",
          "description" : null,
          "state"       : "1",
          "Key"         : "one"
      },
      "date"        : "1968-06-17T00:00:00",
      "name"        : "june17",
      "Key"         : "two",
      "uuid"        : "UUID",
      "description" : null,
      "age"         : null,
      "state"       : "1"
    }
    END_EXPECTED
    is_json $json, $expected, '... and the JSON should be the correct JSON';
}

sub deserialize : Test(5) {
    my $test = shift;
    #use Data::Dumper::Simple;
    #diag Dumper($test, JSON);
    my $formatter = JSON->new( { pretty => 1, indent => 2 } );
    my ( $foo, $bar, $baz ) = $test->test_objects;
    can_ok $formatter, 'deserialize';
    my $json = $formatter->serialize($foo);

    my $bad_key = $json;
    $bad_key =~ s/one/no_such_key/;

    throws_ok { $formatter->deserialize($bad_key) }
      'Object::Relation::Exception::Fatal::InvalidClass',
      '... and it should throw an exception if it finds an invalid key';

    my $new_foo = $formatter->deserialize($json);
    foreach ( $new_foo, $foo ) {

        # XXX we have to do this because id exists in the objects, but not in
        # the json so it doesn't persist and is therefore not returned.
        delete $_->{id};

        # XXX JSON::Syck converts undefined values to empty strings.  We lose
        # information this way.
        $_->{description} = '' unless defined $_->{description};
    }
    $test->force_inflation($new_foo);
    is_deeply $new_foo, $foo,
      '... and it should be able to deserialize a Object::Relation object from JSON';

    # test contained objects

    my $two = Two->new;
    $two->age(20);
    $two->name('june17');
    $two->description('some description');
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
    is_deeply $new_object, $two->_clear_modified,
      '... and the should return the correct object';
}

sub content_type : Test(2) {
    my $test      = shift;
    my $formatter = JSON->new;
    can_ok $formatter, 'content_type';
    is $formatter->content_type, 'text/plain',
      '... and it should return the correct content type';
}

1
