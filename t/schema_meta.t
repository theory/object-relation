#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::Pg' };
use Test::More tests => 180;

{
    # Fake out loading of Pg store.
    package Kinetic::Store::DB::Pg;
    use File::Spec::Functions 'catfile';
    $INC{catfile qw(Kinetic Store DB Pg.pm)} = __FILE__;
    sub _add_store_meta { 1 }
}

BEGIN { use_ok 'Kinetic::Build::Schema' };

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';

ok $sg->load_classes('t/sample/lib', qr/Relation\.pm/),
    'Load all sample classes except Relation.pm';
for my $class ($sg->classes) {
    ok $class->is_a('Kinetic'), $class->package . ' is a Kinetic';
    isa_ok($class, 'Class::Meta::Class');
    isa_ok($class, 'Kinetic::Meta::Class');
    isa_ok($class, 'Kinetic::Meta::Class::Schema');
    for my $attr ($class->attributes) {
        isa_ok($attr, 'Class::Meta::Attribute');
        isa_ok($attr, 'Kinetic::Meta::Attribute');
        isa_ok($attr, 'Kinetic::Meta::Attribute::Schema');
    }
}

# Test the schema attributes of the simple class attributes.
my $simple_class = test_class('simple', '_simple', 4);
test_attr($simple_class, 'uuid', 'uuid', 'idx_simple_uuid');
test_attr($simple_class, 'name', 'name', 'idx_simple_name');
test_attr($simple_class, 'description', 'description');
test_attr($simple_class, 'state', 'state', 'idx_simple_state');

# Test the schema attributes of the one class attributes.
my $one_class = test_class('one', 'simple_one', 1, $simple_class);
test_attr($one_class, 'bool', 'bool');

# Test the schema attributes of the two class attributes.
my $two_class = test_class('two', 'simple_two', 3, $simple_class);
test_attr($two_class, 'one', 'one_id', 'idx_two_one_id', $one_class);

# Test the schema attributes of the composed class attributes.
my $composed_class = test_class('composed', '_composed', 4);
test_attr($composed_class, 'one', 'one_id', 'idx_composed_one_id', $one_class);

sub test_class {
    my ($key, $table, $table_attrs, @parents) = @_;
    ok my $class = Kinetic::Meta->for_key($key), "Get $key class";
    is $class->table, $table, "... its table name should be '$table'";
    my $view = $class->key;
    is $class->view, $view, "... its view name should be '$view'";
    ok my @attr = $class->table_attributes, "... it has table attributes";
    is scalar @attr, $table_attrs, "... it has $table_attrs table attributes";
    if (@parents) {
        is $class->parent, $parents[0], "... its parent is " . $parents[0]->key;
        is_deeply [ map { $_->key } $class->parents ],
          [ map { $_->key } @parents ],
          "... it has all the concrete parents that it should";
        for my $parent (@parents) {
            ok $class->parent_attributes($parent),
              "... it has attributes from parent " . $parent->key;
        }
    } else {
        is $class->parent, undef, "... it has no parent";
    }
    return $class;
}

sub test_attr {
    my ($class, $name, $column, $index, $ref) = @_;
    ok my $attr = $class->attributes($name), "... can get $name attribute";
    is $attr->column, $column, "...... $name column should be '$column'";
    my $label = defined $index ? "'$index'" : 'undefined';
    is $attr->index($class), $index, "...... $name index should be $label";
    $label = $ref ? $ref->key : 'no';
    is $attr->references, $ref, "...... $name references $label class";
}
