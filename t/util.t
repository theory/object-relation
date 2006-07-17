#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 19;
#use Test::More 'no_plan';
use Test::Exception;
use Test::NoWarnings; # Adds an extra test.
use File::Spec;

BEGIN { use_ok('Kinetic::Store::Functions') or die; }

NOIMPORT: { # 1 test.
    package MyTest1;
    use Kinetic::Store::Functions;
    use Test::More;
    ok !defined(&create_uuid), 'create_uuid() should not have been imported';
}

UUID: { # 10 tests.
    package MyTest2;
    use Kinetic::Store::Functions qw(:uuid);
    use Test::More;
    can_ok __PACKAGE__, 'create_uuid';
    can_ok __PACKAGE__, 'uuid_to_bin';
    can_ok __PACKAGE__, 'uuid_to_hex';
    can_ok __PACKAGE__, 'uuid_to_b64';

    ok my $uuid = create_uuid(), 'Create a UUID';
    my $ouuid = OSSP::uuid->new;
    ok $ouuid->import(str => $uuid ), 'It should be a valid UUID';

    # Test uuid_to_hex().
    (my $hex = $uuid) =~ s/-//g;
    is uuid_to_hex($uuid), "0x$hex", 'uuid_to_hex should work';

    # Test uuid_to_bin().
    my $ug = OSSP::uuid->new;
    $ug->import(str => $uuid);
    my $bin = $ug->export('bin');
    is uuid_to_bin($uuid), $bin, 'uuid_to_bin should work';

    # Test uuid_to_b64().
    is uuid_to_b64($uuid), MIME::Base64::encode($bin),
        'uuid_to_b64 should work';
}

class: { # 6 tests.
    package MyTest3;
    use Kinetic::Store::Functions qw(:class);
    use Test::More;

    can_ok __PACKAGE__, 'file_to_mod';

    main::throws_ok { file_to_mod( '', 'not/a/module.pl') }
      'Kinetic::Store::Exception::Fatal',
      'Passing non-modules to file_to_mod() should throw an exception';

    is file_to_mod('', 'Some/Module.pm'), 'Some::Module',
      'file_to_mod() should convert a path to a module name';
    is file_to_mod('some', 'some/Module.pm'), 'Module',
      '... and it should remove the search directories';
    is file_to_mod('some/path/', 'some/path/To/Module.pm'), 'To::Module',
      '... and it should remove the search directories';

    is_deeply [sort map { $_->key } load_classes( 't/sample/lib') ],
        [qw(comp_comp composed extend one relation simple two types_test yello)],
        'load_classes should work properly';

    my $rule = File::Find::Rule->or(
        File::Find::Rule->directory
                        ->name( '.svn', 'CVS' )
                        ->prune
                        ->discard,
        File::Find::Rule->name( qr/\.pm$/ )
                        ->not_name( qr/#/ )
                        ->not_name( 'Yello.pm' )
    );

    is_deeply [sort map { $_->key } load_classes( 't/sample/lib', $rule) ],
        [qw(comp_comp composed extend one relation simple two types_test)],
        'load_classes should work properly with a custom rule';

}
