#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 74;
use Test::NoWarnings; # Adds an extra test.
use DBI;

BEGIN {
    use_ok('Kinetic::Util::Exceptions') or die;
}

##############################################################################

IMPORT: { # 6 tests.
    package Kinetic::Util::Exceptions::TestImport;
    use Kinetic::Util::Exceptions qw(:all);
    use Test::More;

    eval { throw_fatal 'Attribute must be defined' };
    ok( my $err = $@, 'Catch exception' );
    isa_ok( $err, 'Kinetic::Util::Exception');
    isa_ok( $err, 'Kinetic::Util::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( isa_exception($err), "is an exception" );
    ok( isa_kinetic_exception($err), "is a kinetic exception" );
    ok( isa_kinetic_exception($err, 'Fatal'), "is a fatal kinetic exception" );
    eval { isa_kinetic_exception($err, '_Bogus_') };
    ok( $err = $@, "Caught bogus exception class name exception" );
    ok( isa_kinetic_exception($err, 'Fatal'), "is a fatal kinetic exception" );
    ok( !isa_kinetic_exception(undef), "Undef is not a kinetic exception" );
}

NOIMPORT: { # 22 tests.
    package Kinetic::Util::Exceptions::TestNoImport;
    use Kinetic::Util::Exceptions;
    use Test::More;

    eval { throw_fatal('Attribute must be defined') };
    ok( my $err = $@, 'Catch invalid l10n' );
    ok( Kinetic::Util::Exceptions::isa_kinetic_exception($err),
        "is a kinetic exception" );
    ok( Kinetic::Util::Exceptions::isa_exception($err),
        "is an exception" );
    isa_ok $err, 'Kinetic::Util::Exception::ExternalLib';
    isa_ok $err, 'Kinetic::Util::Exception';
    isa_ok $err, "Exception::Class::Base";
    like( $err->error,
          qr{\AUndefined subroutine &Kinetic::Util::Exceptions::TestNoImport::throw_fatal},
          "Is a Perl exception passed to ExternalLib");

    eval {
        Kinetic::Util::Exception::Fatal->throw([
            'File "[_1]" not found',
            'booyah',
        ]);
    };
    ok( $err = $@, 'Catch exception' );
    isa_ok( $err, 'Kinetic::Util::Exception' );
    isa_ok( $err, 'Kinetic::Util::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Kinetic::Util::Exceptions::isa_kinetic_exception($err),
        "is a kinetic exception" );
    ok( Kinetic::Util::Exceptions::isa_exception($err),
        "is an exception" );

    ok $err = Kinetic::Util::Exception::Fatal->new([
        'File "[_1]" not found',
        'booyah',
    ]), 'New, unthrown exception';
    isa_ok( $err, 'Kinetic::Util::Exception' );
    isa_ok( $err, 'Kinetic::Util::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Kinetic::Util::Exceptions::isa_kinetic_exception($err),
        "is a kinetic exception" );
    ok( Kinetic::Util::Exceptions::isa_exception($err),
        "is an exception" );

    ok( $err = Kinetic::Util::Exception::Fatal->new(
        error => [ 'File "[_1]" not found', 'booyah' ],
    ), 'New, unthrown exception' );
    isa_ok( $err, 'Kinetic::Util::Exception' );
    isa_ok( $err, 'Kinetic::Util::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Kinetic::Util::Exceptions::isa_kinetic_exception($err),
        "is a kinetic exception" );
    ok( Kinetic::Util::Exceptions::isa_exception($err),
        "is an exception" );
}

L10N: { # 7 tests.
    package Kinetic::Util::Exceptions::TestL10N;
    use Kinetic::Util::Exceptions qw(:all);
    use Test::More;

    # Test an unlocalized error message. It should throw a fatal
    # language exception.
    eval { throw_error 'Ouch!' };
    ok( my $err = $@, 'Catch exception' );
    isa_ok( $err, 'Kinetic::Util::Exception' );
    isa_ok( $err, 'Kinetic::Util::Exception::Fatal' );
    isa_ok( $err, 'Kinetic::Util::Exception::Fatal::Language' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( isa_exception($err), "isa_exception" );
    ok( isa_kinetic_exception($err), "isa_kinetic_exception" );
}

STRING: {
    package Kinetic::Util::Exceptions::TestString;
    use Kinetic::Util::Exceptions qw(:all);
    use Test::More;
    ok(my $err = Kinetic::Util::Exception::Fatal->new(
        [ 'File "[_1]" not found', 'booyah' ]
    ), 'Get an exception object');
    is( ($err->_filtered_frames)[-1]->filename, __FILE__,
        "We should get this file in the last frame in the stack");
    like $err->trace_as_text, qr{^\[t/exceptions\.t:\d+\]$},
      "We should get the correct string from trace_as_text()";
    ok my $str = "$err", "Get the stringified version";
    is $str, $err->as_string,
      "The stringified version should be the same as that returned by as_string";
    like $str, qr{\AFile .booyah. not found}ms,
      "The error message should be the first thing in the output";
    like $str, qr{^\[t/exceptions\.t:\d+\]\Z}ms,
      "The stack trace should be the last thing in the output";
}

GLOBAL: {
    package Kinetic::Util::Exceptions::TestGlobal;
    use Kinetic::Util::Exceptions qw(:all);
    use Test::More;
    use Test::Output;
    eval { die "Ouch!" };
    ok my $err = $@, "Catch die";
    isa_ok $err, 'Kinetic::Util::Exception::ExternalLib';
    isa_ok $err, 'Kinetic::Util::Exception';
    isa_ok $err, "Exception::Class::Base";
}

DBI: {
    package Kinetic::Util::Exceptions::TestDBI;
    use Kinetic::Util::Exceptions;
    use Test::More;
    ok my $err = Exception::Class::DBI->new('DBI error'),
      "Create DBI error";
    isa_ok $err, 'Kinetic::Util::Exception::DBI';
    isa_ok $err, 'Kinetic::Util::Exception::Fatal';
    isa_ok $err, 'Kinetic::Util::Exception';
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
        HandleError => Kinetic::Util::Exception::DBI->handler
    }), 'Connect to database';
    END { $dbh->disconnect if $dbh };

    # Trigger an exception.
    eval { $dbh->prepare("select * from foo")->execute };
    ok $err = $@, "Get exception";
    isa_ok $err, 'Exception::Class::DBI';
    isa_ok $err, 'Exception::Class::DBI::H';
    isa_ok $err, 'Exception::Class::DBI::STH';
    isa_ok $err, 'Kinetic::Util::Exception';
    isa_ok $err, 'Kinetic::Util::Exception::DBI';
    like $err, qr/[for Statement "select * from foo"]/,
        'The full message should include the SQL statement.';
    like $err, qr/[t.exceptions\.t:174]/, 'It should also contain a stack trace';
}

1;
__END__
