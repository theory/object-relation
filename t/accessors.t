#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 70;

package Kinetic::TestAccessors;
use strict;

BEGIN {
    Test::More->import;
    # We need to load Kinetic first, or else things just won't work!
    use_ok('Kinetic');
    use_ok('Kinetic::Meta');
}

BEGIN {
    ok( my $cm = Kinetic::Meta->new(
        key     => 'accessors',
        name    => 'Testing Accessors',
    ), "Create new CM object" );

    ok( $cm->add_constructor(name => 'new'), "Create new() constructor" );

    # Add a READ-only attribute.
    ok( $cm->add_attribute( name     => 'ro',
                            view     => Class::Meta::PUBLIC,
                            type     => 'whole',
                            required => 1,
                            default  => 1,
                            authz    => Class::Meta::READ,
                          ),
        "Add read-only attribute" );

    # Add a READWRITE attribute.
    ok( $cm->add_attribute( name     => 'rw',
                            view     => Class::Meta::PUBLIC,
                            type     => 'whole',
                            required => 1,
                            default  => 3,
                          ),
        "Add READWRITE attribute" );

    # Add a data type with no validation checks.
    ok( Class::Meta::Type->add(
        key     => "nocheck",
        name    => 'nocheck',
        builder => 'Kinetic::Meta::AccessorBuilder',
    ), "Create nocheck data type" );

    # Add a nocheck attribute.
    ok( $cm->add_attribute( name     => 'nc',
                            view     => Class::Meta::PUBLIC,
                            type     => 'nocheck',
                            default  => 'foo',
                          ),
        "Add nocheck attribute" );
    # Add a READ-only class attribute.
    ok( $cm->add_attribute( name     => 'cro',
                            context  => Class::Meta::CLASS,
                            view     => Class::Meta::PUBLIC,
                            type     => 'whole',
                            required => 1,
                            default  => 1,
                            authz    => Class::Meta::READ,
                          ),
        "Add read-only attribute" );

    # Add a READWRITE attribute.
    ok( $cm->add_attribute( name     => 'crw',
                            context  => Class::Meta::CLASS,
                            view     => Class::Meta::PUBLIC,
                            type     => 'whole',
                            required => 1,
                            default  => 3,
                          ),
        "Add READWRITE attribute" );

    # Add a nocheck class attribute.
    ok( $cm->add_attribute( name     => 'cnc',
                            context  => Class::Meta::CLASS,
                            view     => Class::Meta::PUBLIC,
                            type     => 'nocheck',
                            default  => 'whee',
                          ),
        "Add nocheck attribute" );


    ok( $cm->build, "Build class" );
}

##############################################################################
# Do the tests.
##############################################################################
package main;
# Instantiate an object and test its accessors.
ok( my $t = Kinetic::TestAccessors->new,
    'Kinetic::TestAccessors->new');
ok( my $class = $t->my_class, "Get class object" );

# Try the read-only attribute.
is( $t->ro, 1, "Check ro" );
eval { $t->get_ro };
ok( $@, "Cannot use affordance accessor" );
eval { $t->ro(2) };
ok( $@, "Cannot set ro attribute" );
ok( my $attr = $class->attributes('ro'), "Get ro attribute" );
is( $attr->get($t), 1, "Check ro via attribute object" );
eval { $attr->set($t, 2) };
ok( $@, "Cannot set ro attribute via object" );

# Try the read/write attribute.
is( $t->rw, 3, "Check rw" );
eval { $t->get_rw };
ok( $@, "Cannot get_rw" );
ok( $t->rw(2), "Set rw to 2" );
is( $t->rw, 2, "Check rw for 2" );
eval { $t->set_rw(3) };
ok( $@, "Cannot set_rw" );
ok( $attr = $class->attributes('rw'), "Get rw attribute" );
is( $attr->get($t), 2, "Check rw via attribute object" );
ok( $attr->set($t, 3), "Set rw via attribue object" );
is( $attr->get($t), 3, "Check rw via attribute object for new value" );

# Try nocheck attribute.
is( $t->nc, 'foo', "Check nocheck" );
eval { $t->get_nc };
ok( $@, "Cannot get_nc" );
ok( $t->nc('bar'), "Set nocheck" );
is( $t->nc, 'bar', "Check new nocheck value" );
eval { $t->set_nc('bat') };
ok( $@, "Cannot set_nc" );
ok( $attr = $class->attributes('nc'), "Get nc attribute" );
is( $attr->get($t), 'bar', "Check nc via attribute object" );
ok( $attr->set($t, 'bif'), "Set nc via attribue object" );
is( $attr->get($t), 'bif', "Check nc via attribute object for new value" );

# Try the read-only class attribute.
is( Kinetic::TestAccessors->cro, 1, "Check cro" );
eval {Kinetic::TestAccessors->get_cro };
ok( $@, "Cannot get_cro" );
is( $t->cro, 1, "Check cro via object" );
eval { $t->get_cro };
ok( $@, , "Cannot get_cro via object" );
eval { Kinetic::TestAccessors->cro(2) };
ok( $@, "Cannot set cro attribute" );
ok( $attr = $class->attributes('cro'), "Get cro attribute" );
is( $attr->get('Kinetic::TestAccessors'), 1,
 "Check cro via attribute object" );
eval { $attr->set('Kinetic::TestAccessors', 'fan') };
ok( $@, "Cannot set cro attribute via attribute" );

# Try the read/write class attribute.
is( Kinetic::TestAccessors->crw, 3, "Check crw" );
eval {Kinetic::TestAccessors->get_crw };
ok( $@, "Cannot get_crw" );
ok( Kinetic::TestAccessors->crw(2), "Set crw to 2" );
is( Kinetic::TestAccessors->crw, 2, "Check crw for 2" );
eval { Kinetic::TestAccessors->set_crw(3) };
ok( $@, "Cannot set_crw" );
is( $t->crw, 2, "Check crw for 2 via object" );
eval { $t->get_crw };
ok( $@, "Cannot get_crw via object" );
ok( $attr = $class->attributes('crw'), "Get crw attribute" );
is( $attr->get('Kinetic::TestAccessors'), 2,
 "Check crw via attribute object" );
ok( $attr->set('Kinetic::TestAccessors', 4),
    "Set crw via attribue object" );
is( $attr->get('Kinetic::TestAccessors'), 4,
    "Check crw via attribute object for new value" );
is( $attr->get($t), 4,
    "Check crw via attribute object for new value via object" );

# Try nocheck class attribute.
is( Kinetic::TestAccessors->cnc, 'whee', "Check class nocheck" );
eval { Kinetic::TestAccessors->get_cnc };
ok( $@, "Cannot get_cnc" );
ok( Kinetic::TestAccessors->cnc('fun'), "Set class nocheck" );
is( Kinetic::TestAccessors->cnc, 'fun', "Check new class nocheck value" );
eval { Kinetic::TestAccessors->set_cnc('fug') };
ok( $@, "Cannot set_cnc" );
is( $t->cnc, 'fun', "Check new class nocheck value via object" );
eval { $t->get_cnc };
ok( $@, "Cannot get_cnc via object" );
ok( $attr = $class->attributes('cnc'), "Get cnc attribute" );
is( $attr->get('Kinetic::TestAccessors'), 'fun',
 "Check cnc via attribute object" );
ok( $attr->set('Kinetic::TestAccessors', 'fan'),
    "Set cnc via attribue object" );
is( $attr->get('Kinetic::TestAccessors'), 'fan',
    "Check cnc via attribute object for new value" );
is( $attr->get($t), 'fan',
    "Check cnc via attribute object for new value via object" );

1;
__END__
