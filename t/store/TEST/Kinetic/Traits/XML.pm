package TEST::Kinetic::Traits::XML;

#use Class::Trait 'base';

use strict;
use warnings;

# note that the following is a stop-gap measure until Class::Trait has
# a couple of bugs fixed.  Bugs have been reported back to the author.
#
# Traits would be useful here as the REST and REST::Dispatch classes are
# coupled, but not by inheritance.  The tests need to share functionality
# but since inheritance is not an option, I will be importing these methods
# directly into the required namespaces.

use Exporter::Tidy default => [
    qw/
      instance_data
      instance_order
      expected_instance_xml
      /
];

sub instance_data {
    my ( $test, $object ) = @_;
    my @attributes = $test->desired_attributes;
    my %values_of;
    @values_of{@attributes} = map { $object->$_ } @attributes;
    $values_of{uuid} = $object->uuid;
    return \%values_of;
}

sub instance_order {
    my ( $test, $xml ) = @_;
    my @order = $xml =~ /<kinetic:attribute name="name">([^<]*)/g;
    return wantarray ? @order : \@order;
}

sub expected_instance_xml {
    my ( $test, $url, $class_key, $instance_ref, $order_ref ) = @_;
    my @attributes = $test->desired_attributes;
    my $instance_xml = <<"    END_INSTANCE_XML";
    <kinetic:resource id="%s" xlink:href="${url}${class_key}/lookup/uuid/%s">
    END_INSTANCE_XML
    foreach my $attr (@attributes) {
        $instance_xml .= qq'<kinetic:attribute name="$attr">%s</kinetic:attribute>\n';
    }
    $instance_xml .= "    </kinetic:resource>\n";
    my $result = '';
    foreach my $instance (@$order_ref) {
        $result .= sprintf $instance_xml,
          map { defined $_ ? $_ : '' } 
            ( $instance_ref->{$instance}{uuid} ) x 2,
            map { $instance_ref->{$instance}{$_} } 
              @attributes;
    }
    return $result;
}

1;
