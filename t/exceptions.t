#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 40;

BEGIN {
    use_ok('Kinetic::Exceptions');
}

##############################################################################

IMPORT: { # 6 tests.
    package Kinetic::Exceptions::TestImport;
    use Kinetic::Exceptions qw(:all);
    use Test::More;

    eval { throw_fatal 'Attribute must be defined' };
    ok( my $err = $@, 'Catch exception' );
    isa_ok( $err, 'Kinetic::Exception');
    isa_ok( $err, 'Kinetic::Exception::Fatal' );
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
    package Kinetic::Exceptions::TestNoImport;
    use Kinetic::Exceptions;
    use Test::More;

    eval { throw_fatal('Attribute must be defined') };
    ok( my $err = $@, 'Catch invalid l10n' );
    ok( ! Kinetic::Exceptions::isa_kinetic_exception($err),
        "is not a kinetic exception" );
    ok( ! Kinetic::Exceptions::isa_exception($err),
        "is not an exception" );
    ok( ! ref $err, "Isn't a reference" );

    eval { Kinetic::Exception::Fatal->throw('Attribute must be defined') };
    ok( $err = $@, 'Catch exception' );
    isa_ok( $err, 'Kinetic::Exception' );
    isa_ok( $err, 'Kinetic::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Kinetic::Exceptions::isa_kinetic_exception($err),
        "is a kinetic exception" );
    ok( Kinetic::Exceptions::isa_exception($err),
        "is an exception" );

    ok( $err = Kinetic::Exception::Fatal->new('Attribute must be defined'),
        'New, unthrown exception' );
    isa_ok( $err, 'Kinetic::Exception' );
    isa_ok( $err, 'Kinetic::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Kinetic::Exceptions::isa_kinetic_exception($err),
        "is a kinetic exception" );
    ok( Kinetic::Exceptions::isa_exception($err),
        "is an exception" );

    ok( $err = Kinetic::Exception::Fatal->new(
        error => 'Attribute must be defined'
        ),
        'New, unthrown exception' );
    isa_ok( $err, 'Kinetic::Exception' );
    isa_ok( $err, 'Kinetic::Exception::Fatal' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( Kinetic::Exceptions::isa_kinetic_exception($err),
        "is a kinetic exception" );
    ok( Kinetic::Exceptions::isa_exception($err),
        "is an exception" );
}

L10N: { # 7 tests.
    package Kinetic::Exceptions::TestL10N;
    use Kinetic::Exceptions qw(:all);
    use Test::More;

    # Test an unlocalized error message. It should throw a fatal
    # language exception.
    eval { throw_error 'Ouch!' };
    ok( my $err = $@, 'Catch exception' );
    isa_ok( $err, 'Kinetic::Exception' );
    isa_ok( $err, 'Kinetic::Exception::Fatal' );
    isa_ok( $err, 'Kinetic::Exception::Fatal::Language' );
    isa_ok( $err, "Exception::Class::Base" );
    ok( isa_exception($err), "isa_exception" );
    ok( isa_kinetic_exception($err), "isa_kinetic_exception" );
}

1;
__END__
