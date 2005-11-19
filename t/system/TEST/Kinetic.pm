package TEST::Kinetic;

# $Id$

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;

sub class_key { 'kinetic' }
sub class_pkg {
    my $self = shift;
    (my $pkg = ref $self || $self) =~ s/^TEST:://;
    return $pkg;
}
sub class     { Kinetic::Meta->for_key(shift->class_key) };

sub _test_load : Test(1) {
    my $self = shift;
    my $class_pkg = $self->class_pkg;
    use_ok $class_pkg or die;
}

sub test_new : Test(6) {
    my $self = shift;
    my $key  = $self->class_key;
    ok my $class = Kinetic::Meta->for_key($key), "Get $key class object";
    return qq{abstract class "$key"} if $class->abstract;

    ok my $pkg = $class->package, "Get $key package";
    ok my $obj = $pkg->new,       "Construct new $pkg object";

    isa_ok $obj, $pkg;
    isa_ok $obj, 'Kinetic';
    is $obj->uuid, undef,   '...Its UUID should be undef';

    # Test attributes.
}

sub test_save : Test(6) {
    my $self = shift;
    my $key  = $self->class_key;
    ok my $class = Kinetic::Meta->for_key($key), "Get $key class object";
    return qq{abstract class "$key"} if $class->abstract;

    ok my $pkg   = $class->package, "Get $key package";
    ok my $obj   = $pkg->new,       "Construct new $pkg object";
    is $obj->uuid, undef,           'UUID should be undef';

    return 'Not testing Data Stores'
        unless $self->any_supported(qw/pg sqlite/);

    ok $obj->save,                  "Save the $pkg object";
    ok $obj->uuid,                  'UUID should be defined';
}

1;
__END__
