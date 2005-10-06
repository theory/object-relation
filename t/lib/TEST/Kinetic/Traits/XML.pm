package TEST::Kinetic::Traits::XML;

#use Class::Trait 'base';
# required url() from Traits::HTML
# required domain() from Traits::HTML
# required path() from Traits::HTML

use strict;
use warnings;

# note that the following is a stop-gap measure until Class::Trait has
# a couple of bugs fixed.  Bugs have been reported back to the author.
#
# Traits would be useful here as the REST and REST::Dispatch classes are
# coupled, but not by inheritance.  The tests need to share functionality
# but since inheritance is not an option, I will be importing these methods
# directly into the required namespaces.

use HTML::Entities qw/encode_entities/;
use Kinetic::Util::Constants qw/:xslt/;
use Exporter::Tidy default => [
    qw/
      instance_order
      expected_instance_xml
      header_xml
      resource_list_xml
      search_data_xml
      /
];

##############################################################################

=head1 Available methods

=head2 Instance methods

The following methods are are methods related to the production of XML
documents.

=cut

##############################################################################

=head3 instance_order

  my @order = $test->instance_order( $xml, [$key] );

This method returns the attributes values from XSLT generated XML for a
given attribute C<$key> in the order found in the XML.  C<$key> is optional
and defaults to I<name> if not supplied.

This method is useful when the order of objects returned from the data store
is unknown but you need to specify that order in C<expected_instance_xml>.

=cut

sub instance_order {
    my ( $test, $xml, $key ) = @_;
    $key ||= 'name';
    my @order = $xml =~ /<kinetic:attribute name="$key">([^<]*)/g;
    return wantarray ? @order : \@order;
}

##############################################################################

=head3 expected_instance_xml

  my $xml_snippet = $test->expected_instance_xml( \@objects, [\@order], [$key] );

This method will return an XML snippet for the given objects.  This snippet
should match the XML returned by the XSLT REST type.

The order of objects listed in the XML is the same as the order of objects
passed in.  If this is unknown, you may pass in a second argument, an array
reference, with a list of the object "keys".  The objects will be sorted in the
same order as the objects "key" values.  The name of the key defaults to "name"
unless otherwise noted.

=cut

sub expected_instance_xml {
    my ( $test, $objects, $order_ref, $key ) = @_;
    $key ||= 'name';
    my $class_key = $objects->[0]->my_class->key;
    unless ($order_ref) {
        @$order_ref = map { $_->$key } @$objects;
    }
    my %instance_for = map { $_->$key, _instance_data( $test, $_ ) } @$objects;
    my $url          = $test->url;
    my @attributes   = $test->desired_attributes;
    my $instance_xml = <<"    END_INSTANCE_XML";
    <kinetic:instance id="%s" xlink:href="${url}${class_key}/lookup/uuid/%s">
    END_INSTANCE_XML
    foreach my $attr (@attributes) {
        $instance_xml .=
          qq'<kinetic:attribute name="$attr">%s</kinetic:attribute>\n';
    }
    $instance_xml .= "    </kinetic:instance>\n";
    my $result = '';
    foreach my $instance (@$order_ref) {
        $result .= sprintf $instance_xml,
          map { defined $_ ? $_ : '' } ( $instance_for{$instance}{uuid} ) x 2,
          map { $instance_for{$instance}{$_} } @attributes;
    }
    return $result;
}

sub _instance_data {
    my ( $test, $object ) = @_;
    my @attributes = $test->desired_attributes;
    my %values_of;
    @values_of{@attributes} = map { $object->$_ } @attributes;
    $values_of{uuid} = $object->uuid;
    return \%values_of;
}

##############################################################################

=head3 header_xml

 my $header = $test->header_xml($title);

Given a title for an XML document, this method will return the "header" of xml
that matches the XML returned by C<Kinetic::REST::Dispatch>.

=cut

sub header_xml {
    my ( $test, $title ) = @_;
    my $xslt   = $title =~ /resources/ ? RESOURCES_XSLT: SEARCH_XSLT;
    my $server = $test->url;
    my $domain = $test->domain;
    my $path   = $test->path;
    my $query  = $test->query_string;
    my ($type) = $query =~ /type=([[:word:]]+)/;
    $type ||= '';
    return <<"    END_XML";
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="$xslt"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>$title</kinetic:description>
      <kinetic:domain>$domain</kinetic:domain>
      <kinetic:path>$path</kinetic:path>
      <kinetic:type>$type</kinetic:type>
    END_XML
}

##############################################################################

=head3 resource_list_xml

 my $resource_list_xml = $test->resource_list_xml([$no_namespaces]);

This method will return the current resource list for an XML document.

If passed a true value, the returned XML will not have namespaces.  This is
due to an apparent limitation in L<XML::Genx|XML::Genx>.

=cut

sub resource_list_xml {
    my ( $test, $no_namespaces ) = @_;
    my $url       = $test->url;
    my $resources = '';
    my ( $kinetic, $xlink ) = qw( kinetic: xlink: );
    if ($no_namespaces) {
        ( $kinetic, $xlink ) = ( '', '' );
    }
    foreach my $key ( sort Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $resources .=
          qq'<${kinetic}resource id="$key" ${xlink}href="$url$key/search"/>';
    }
    return $resources;
}

##############################################################################

=head3 search_data_xml

  my $search_xml = $test->search_data_xml({
    key        => $class_key,
    search     => $search_string, # optional.  Should be unencoded if supplied.
    limit      => $limit,         # optional.  Defaults to 20
    order_by   => $order_by,      # optional
    sort_order => $sort_order     # optional.  Defaults to ASC
  });

This method returns the search parameters XML snippet that is built by the
REST dispatch class.  C<$sort_order>, if present, should be I<ASC> or 
I<DESC>.

=cut

sub search_data_xml {
    my ( $test, $value_for ) = @_;
    $value_for->{search}     = ''    unless exists $value_for->{search};
    $value_for->{limit}      = 20    unless exists $value_for->{limit};
    $value_for->{order_by}   = ''    unless exists $value_for->{order_by};
    $value_for->{sort_order} = 'ASC' unless exists $value_for->{sort_order};

    foreach my $key ( keys %$value_for ) {
        $value_for->{$key} = encode_entities( $value_for->{$key} );
    }

    my $xml = <<"    END_XML";
        <kinetic:class_key>$value_for->{key}</kinetic:class_key>
        <kinetic:search_parameters>
    END_XML
    foreach my $arg (qw/ search limit order_by /) {
        $xml .=
qq[<kinetic:parameter type="$arg">$value_for->{$arg}</kinetic:parameter>\n];
    }
    $xml .= '<kinetic:parameter type="sort_order" widget="select">';
    foreach my $order ( [ ASC => 'Ascending' ], [ DESC => 'Descending' ] ) {
        my $selected =
          $value_for->{sort_order} eq $order->[0]
          ? (' selected="selected"')
          : ('');
        $xml .=
qq{<kinetic:option name="$order->[0]"$selected>$order->[1]</kinetic:option>};
    }
    $xml .= "</kinetic:parameter></kinetic:search_parameters>";
    return $xml;
}

1;