package TEST::Class::Kinetic;

use strict;
use warnings;
use utf8;
use base 'Test::Class';
use Test::More;

my $builder;
sub builder {
    my $test = shift;
    return $builder unless @_;
    $builder = shift;
    return $test;
}

sub a_test_load : Test(startup => 1) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    return ok 1, "TEST::Class::Kinetic loaded" if $class eq 'Class::Kinetic';
    use_ok $class or die;
    $test->{test_class} = $class;
}

sub test_class { shift->{test_class} }

1;
__END__
