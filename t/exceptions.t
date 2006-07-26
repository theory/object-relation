#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 75;
use Test::NoWarnings; # Adds an extra test.
use DBI;

BEGIN {
    use_ok('Object::Relation::Exceptions') or die;
}

##############################################################################

IMPORT: { # 6 tests.
    package Object::Relation::Exceptions::TestImport;
    use Object::Relation::Exceptions qw(:all);
    use Test::More;

    eval { throw_fatal 'Attribute must be defined' };
    ok( my $err = $@, 'Catch exception' );
    isa_ok( $err, 'Object::Relation::Exception');
    isa_ok( $err, 'Object::Relation::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( isa_exception($err), "is an exception" );
    ok( isa_obj_rel_exception($err), "is a obj_rel exception" );
    ok( isa_obj_rel_exception($err, 'Fatal'), "is a fatal obj_rel exception" );
    eval { isa_obj_rel_exception($err, '_Bogus_') };
    ok( $err = $@, "Caught bogus exception class name exception" );
    ok( isa_obj_rel_exception($err, 'Fatal'), "is a fatal obj_rel exception" );
    ok( !isa_obj_rel_exception(undef), "Undef is not a obj_rel exception" );
}

NOIMPORT: { # 22 tests.
    package Object::Relation::Exceptions::TestNoImport;
    use Object::Relation::Exceptions;
    use Test::More;

    eval { throw_fatal('Attribute must be defined') };
    ok( my $err = $@, 'Catch invalid l10n' );
    ok( Object::Relation::Exceptions::isa_obj_rel_exception($err),
        "is a obj_rel exception" );
    ok( Object::Relation::Exceptions::isa_exception($err),
        "is an exception" );
    isa_ok $err, 'Object::Relation::Exception::ExternalLib';
    isa_ok $err, 'Object::Relation::Exception';
    isa_ok $err, "Exception::Class::Base";
    like( $err->error,
          qr{\AUndefined subroutine &Object::Relation::Exceptions::TestNoImport::throw_fatal},
          "Is a Perl exception passed to ExternalLib");

    eval {
        Object::Relation::Exception::Fatal->throw([
            'Attribute "[_1]" is not unique',
            'booyah',
        ]);
    };
    ok( $err = $@, 'Catch exception' );
    isa_ok( $err, 'Object::Relation::Exception' );
    isa_ok( $err, 'Object::Relation::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Object::Relation::Exceptions::isa_obj_rel_exception($err),
        "is a obj_rel exception" );
    ok( Object::Relation::Exceptions::isa_exception($err),
        "is an exception" );

    ok $err = Object::Relation::Exception::Fatal->new([
        'Attribute "[_1]" is not unique',
        'booyah',
    ]), 'New, unthrown exception';
    isa_ok( $err, 'Object::Relation::Exception' );
    isa_ok( $err, 'Object::Relation::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Object::Relation::Exceptions::isa_obj_rel_exception($err),
        "is a obj_rel exception" );
    ok( Object::Relation::Exceptions::isa_exception($err),
        "is an exception" );

    ok( $err = Object::Relation::Exception::Fatal->new(
        error => [ 'Attribute "[_1]" is not unique', 'booyah' ],
    ), 'New, unthrown exception' );
    isa_ok( $err, 'Object::Relation::Exception' );
    isa_ok( $err, 'Object::Relation::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Object::Relation::Exceptions::isa_obj_rel_exception($err),
        "is a obj_rel exception" );
    ok( Object::Relation::Exceptions::isa_exception($err),
        "is an exception" );
}

L10N: { # 7 tests.
    package Object::Relation::Exceptions::TestL10N;
    use Object::Relation::Exceptions qw(:all);
    use Test::More;

    # Test an unlocalized error message. It should throw a fatal
    # language exception.
    eval { throw_error 'Ouch!' };
    ok( my $err = $@, 'Catch exception' );
    isa_ok( $err, 'Object::Relation::Exception' );
    isa_ok( $err, 'Object::Relation::Exception::Fatal' );
    isa_ok( $err, 'Object::Relation::Exception::Fatal::Language' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( isa_exception($err), "isa_exception" );
    ok( isa_obj_rel_exception($err), "isa_obj_rel_exception" );
}

STRING: {
    package Object::Relation::Exceptions::TestString;
    use Object::Relation::Exceptions qw(:all);
    use Test::More;
    ok(my $err = Object::Relation::Exception::Fatal->new(
        [ 'Attribute "[_1]" is not unique', 'booyah' ]
    ), 'Get an exception object');
    is( ($err->_filtered_frames)[-1]->filename, __FILE__,
        "We should get this file in the last frame in the stack");
    like $err->trace_as_text, qr{^\[t/exceptions\.t:\d+\]$},
      "We should get the correct string from trace_as_text()";
    ok my $str = "$err", "Get the stringified version";
    is $str, $err->as_string,
      "The stringified version should be the same as that returned by as_string";
    like $str, qr{\AAttribute \x{201c}booyah\x{201d} is not unique}ms,
      "The error message should be the first thing in the output";
    like $str, qr{^\[t/exceptions\.t:\d+\]\Z}ms,
      "The stack trace should be the last thing in the output";
}

GLOBAL: {
    package Object::Relation::Exceptions::TestGlobal;
    use Object::Relation::Exceptions qw(:all);
    use Test::More;
    use Test::Output;
    eval { die "Ouch!" };
    ok my $err = $@, "Catch die";
    isa_ok $err, 'Object::Relation::Exception::ExternalLib';
    isa_ok $err, 'Object::Relation::Exception';
    isa_ok $err, "Exception::Class::Base";
}

DBI: {
    package Object::Relation::Exceptions::TestDBI;
    use Object::Relation::Exceptions;
    use Test::More;
    ok my $err = Object::Relation::Exception::DBI->new('DBI error'),
      "Create DBI error";
    isa_ok $err, 'Object::Relation::Exception::DBI';
    isa_ok $err, 'Object::Relation::Exception::ExternalLib';
    isa_ok $err, 'Object::Relation::Exception';
    isa_ok $err, 'Exception::Class::DBI';
    isa_ok $err, 'Exception::Class::Base';
    ok my $str = "$err", "Get the stringified version";
    is $str, $err->as_string,
      "The stringified version should be the same as that returned by as_string";
    like $str, qr{\ADBI error}ms,
      "The error message should be the first thing in the output";
    like $str, qr{^\[t/exceptions\.t:\d+\]\Z}ms,
      "The stack trace should be the last thing in the output";

    # Make sure that the STH includes the SQL statement.
    ok my $dbh = DBI->connect('dbi:ExampleP:dummy', '', '',{
        PrintError => 0,
        RaiseError => 0,
        HandleError => Object::Relation::Exception::DBI->handler
    }), 'Connect to database';
    END { $dbh->disconnect if $dbh };

    # Trigger an exception.
    eval { $dbh->prepare("select * from foo")->execute };
    ok $err = $@, "Get exception";
    isa_ok $err, 'Exception::Class::DBI';
    isa_ok $err, 'Exception::Class::DBI::H';
    isa_ok $err, 'Exception::Class::DBI::STH';
    isa_ok $err, 'Object::Relation::Exception';
    isa_ok $err, 'Object::Relation::Exception::DBI';
    isa_ok $err, 'Object::Relation::Exception::DBI::STH';
    like $err, qr/[for Statement "select * from foo"]/,
        'The full message should include the SQL statement.';
    like $err, qr/[t.exceptions\.t:174]/, 'It should also contain a stack trace';
}

1;
__END__
