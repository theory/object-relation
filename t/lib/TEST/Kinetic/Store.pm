package TEST::Kinetic::Store;

# $Id: SQLite.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Store' => 'Store', ':all';
__PACKAGE__->runtests;

sub constructor : Test(4) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    can_ok $class => 'new';
    ok my $store = $class->new;
    isa_ok $store, $class;
    isa_ok $store, 'Kinetic::Store';
}

sub save : Test(2) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    can_ok $class, 'save';
    throws_ok { Store->save }
        qr/Kinetic::Store::save must be overridden in a subclass/,
        'but calling it directly should croak()';
}

sub does_import : Test(66) {
    can_ok Store, 'import';
    # comparison
    foreach my $sub (qw/EQ NOT LIKE GT LT GE LE NE/) {
        can_ok __PACKAGE__, $sub;
        no strict 'refs';
        my $result = [$sub->(7)->()];
        is_deeply $result, [$sub, 7],
            'and it should return its name and args';
    }
    # sorting
    foreach my $sub (qw/ASC DESC/) {
        can_ok __PACKAGE__, $sub;
        no strict 'refs';
        my $result = [$sub->()->()];
        is_deeply $result, [$sub],
            'and it should return its name and args';
    }
    # logical
    foreach my $sub (qw/AND OR ANY/) {
        can_ok __PACKAGE__, $sub;
        no strict 'refs';
        my $result = [$sub->(qw/foo bar/)->()];
        is_deeply $result, [$sub, [qw/foo bar/]],
            'Not yet sure of the semantics of the logical operators';
    }
    {
        package Foo;
        use Kinetic::Store ':comparison';
        foreach my $sub (qw/EQ NOT LIKE GT LT GE LE NE/) {
            TEST::Kinetic::Store::ok UNIVERSAL::can(Foo => $sub),
                '":comparison" should export the correct methods';
        }
        foreach my $sub (qw/AND OR ANY ASC DESC/) {
            TEST::Kinetic::Store::ok ! UNIVERSAL::can(Foo => $sub),
                '":comparison" should not export unrequested methods';
        }
    }
    {
        package Bar;
        use Kinetic::Store ':logical';
        foreach my $sub (qw/AND OR ANY/) {
            TEST::Kinetic::Store::ok UNIVERSAL::can(Bar => $sub),
                '":logical" should export the correct methods';
        }
        foreach my $sub (qw/EQ NOT LIKE GT LT GE LE ASC DESC NE/) {
            TEST::Kinetic::Store::ok ! UNIVERSAL::can(Bar => $sub),
                '":logical" should not export unrequested methods';
        }
    }
    {
        package Baz;
        use Kinetic::Store ':sorting';
        foreach my $sub (qw/ASC DESC/) {
            TEST::Kinetic::Store::ok UNIVERSAL::can(Baz => $sub),
                '":sorting" should export the correct methods';
        }
        foreach my $sub (qw/EQ NOT LIKE GT LT GE LE AND OR ANY NE/) {
            TEST::Kinetic::Store::ok ! UNIVERSAL::can(Baz => $sub),
                '":sorting" should not export unrequested methods';
        }
    }
}

1;
