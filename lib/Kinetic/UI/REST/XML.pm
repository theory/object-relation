package Kinetic::UI::REST::XML;

# $Id: REST.pm 1544 2005-04-16 01:13:51Z theory $

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;

use version;
our $VERSION = version->new('0.0.1');

use Array::AsHash;
use Scalar::Util qw/blessed/;

use Kinetic::Meta;
use Kinetic::XML;
use Kinetic::XML::REST;
use Kinetic::Store;
use Kinetic::Util::Constants qw/:http :xslt :labels :rest/;
use Kinetic::Util::Exceptions qw/throw_fatal throw_invalid_class/;

use Readonly;
Readonly my %DONT_DISPLAY => ( uuid => 1 );
Readonly my $MAX_ATTRIBUTE_INDEX => 4;
Readonly my $PLACEHOLDER         => 'null';
Readonly my $DEFAULT_LIMIT       => 20;
Readonly my $DEFAULT_SEARCH_ARGS => {
    array => [ $SEARCH_TYPE, '', $LIMIT_PARAM, $DEFAULT_LIMIT, $OFFSET_PARAM, 0 ],
    clone => 1,
};

=head1 Name

Kinetic::UI::REST::XML - XML REST services provider

=head1 Synopsis

 use Kinetic::UI::REST::XML;

 if (my $sub = Kinetic::UI::REST::XML->can($method)) {
   $sub->($rest);
 }

=head1 Description

This is the dispatch class to which
L<Kinetic::UI::REST|Kinetic::UI::REST> will dispatch methods.
This is kept in a separate class to ensure that REST servers do not call these
methods directly.

=cut

##############################################################################

=head3 new

  my $dispatch = Kinetic::UI::REST::XML->new({ rest => $rest });

The constructor. The C<rest> parameter should be an object conforming to the
C<Kinetic::UI::Rest> interface.

=cut

sub new {
    my ( $class, $arg_for ) = @_;
    my $self = bless {}, $class;
    $self->rest( $arg_for->{rest} );
    $self->_xml( Kinetic::XML::REST->new({ rest => $arg_for->{rest} }) );
    return $self;
}

##############################################################################

=head3 rest

  my $rest = $dispatch->rest;
  $dispatch->rest($rest);

Getter/setter for REST object.

=cut

sub rest {
    my $self = shift;
    return $self->{rest} unless @_;
    $self->{rest} = shift;
    return $self;
}

sub _xml {
    my $self = shift;
    return $self->{xml}{generator} unless @_;
    $self->{xml}{generator} = shift;
    return $self;
}

##############################################################################

=head3 class_key

  my $class_key = $dispatch->class_key;
  $dispatch->class_key($class_key);

Getter/setter for class key we're working with.

=cut

sub class_key {
    my $self = shift;
    return $self->{class_key} unless @_;
    $self->{class_key} = shift;
    return $self;
}

##############################################################################

=head3 class

  my $class = $dispatch->class;
  $dispatch->class($class);

This method will return the current class object we're searching on. If the
class object has not been explicitly set with this method, it will attempt to
build a class object for using the current class key.

=cut

sub class {
    my $self = shift;
    if (@_) {
        $self->{class} = shift;
        return $self;
    }
    $self->{class} ||= Kinetic::Meta->for_key( $self->class_key );
    return $self->{class};
}

##############################################################################

=head3 method

  my $method = $dispatch->method;
  $dispatch->method($method);

Getter/setter for method to be sent to class created from class key.

=cut

sub method {
    my $self = shift;
    return ( $self->{method} || 0 ) unless @_;
    $self->{method} = shift;
    return $self;
}

##############################################################################

=head3 args

  $dispatch->args(Array::AsHash->new({ array=>\@args });
  my $args = $dispatch->args;

Getter/setter for args to accompany C<method>. If the supplied argument
reference is emtpy, it will set a default of an empty string search, a default
limit and a default offset to 0.

=begin comment

XXX This seems very specific to the query() method. Surely it doesn't apply
to other methods! IOW, it shouldn't devfault to an empty string, methinks. Or
am I missing something?

=end comment

=cut

sub args {
    my $self = shift;

    if (@_) {
        my $args = shift;
        unless ( blessed $args && $args->isa('Array::AsHash') ) {
            throw_fatal [
                'Argument "[_1]" is not a valid [_2] object', 1,
                'Array::AsHash'
            ];
        }
        $args->reset_each;
        while ( my ( $k, $v ) = $args->each ) {
            # XXX Why is this necessary?
            $args->put( $k, '' ) if $PLACEHOLDER eq $v;
        }
        # XXX Perhaps we should dispatch to anothe method or a hash that lists
        # defaults for all methods?
        if ( 'query' eq $self->method ) {
            if ($args) { # XXX Seems pretty clear above that it exists.
                $args->default( $SEARCH_TYPE, $PLACEHOLDER, $LIMIT_PARAM,
                    $DEFAULT_LIMIT, $OFFSET_PARAM, 0, );
                if ( $args->exists($ORDER_BY_PARAM) ) {
                    $args->default( $SORT_PARAM, 'ASC' );
                }
                $args = Array::AsHash->new({
                    array => [
                        $args->get_pairs(
                            $SEARCH_TYPE,  $LIMIT_PARAM,
                            $OFFSET_PARAM, $ORDER_BY_PARAM,
                            $SORT_PARAM
                        ),
                    ],
                });
            }
            else {
                $args = Array::AsHash->new($DEFAULT_SEARCH_ARGS);
            }
        }
        $self->{args} = $args;
        return $self;
    }

    unless ( $self->{args} ) {
        my $args = {};
        if ( 'query' eq $self->method ) {
            $args = $DEFAULT_SEARCH_ARGS;
        }
        $self->{args} = Array::AsHash->new($args);
    }
    return $self->{args};
}

##############################################################################

=head3 get_args

  my @args = $dispatch->get_args( 0, 1 );

This method returns method arguments by index, starting with zero. If no index
arguments are supplied to this method, I<all> method arguments will be
returned. Can take one or more arguments. Returns a list of the arguments.

=cut

sub get_args {
    my $self = shift;
    my $args = $self->args;
    my @args;
    while ( my ( $k, $v ) = $args->each ) {
        if ( !$args->first ) {    # first method arg can always be false
            next if '' eq $v;
        }
        push @args => $k, $v;
    }
    return @_ ? @args[@_] : @args;
}

=head3 handle_rest_request

 $dispatch->handle_rest_request

=cut

sub handle_rest_request {
    my ($self) = @_;

    my ( $class, $method_object, $ctor );
    eval { $class = Kinetic::Meta->for_key( $self->class_key ) };
    my $method = $self->method;
    if ( $class && $method ) {
        $self->class($class);
        $method_object = $class->methods($method);
        $ctor = $method_object ? '' : $class->constructors($method);
    }

    return $ctor       ? $self->_handle_constructor($ctor)
      : $method_object ? $self->_handle_method($method_object)
      : $self->_not_implemented;
}

# decouple REST param names from Kinetic::Store interface
my @renames = (
    [ $LIMIT_PARAM,    'limit' ],
    [ $OFFSET_PARAM,   'offset' ],
    [ $ORDER_BY_PARAM, 'order_by' ],
    [ $SORT_PARAM,     'sort_order' ],
);

sub _args_for_store {
    my $self = shift;
    my $args = $self->args->clone;
    foreach my $rename (@renames) {
        $args->rename(@$rename) if $args->exists( $rename->[0] );
    }
    return $args->get_array;
}

sub _handle_constructor {
    my ( $self, $ctor ) = @_;
    my $obj  = $ctor->call( $self->class->package, $self->_args_for_store );
    my $rest = $self->rest;
    # XXX We really should pass a file handle to print to here.
    my $xml  = Kinetic::XML->new({
        object         => $obj,
        stylesheet_url => $INSTANCE_XSLT,
        resources_url  => $rest->base_url,
    })->dump_xml;
    return $rest->set_response( $xml, 'instance' );
}

# XXX Why is there so much special casing for query? Is it really necessary?
# Would other interfaces (SOAP, JSON) need to do the same?
sub _search_request {
    my $self = shift;
    if (@_) {
        my $request = shift;
        if ( ref $request ) {
            # they're setting the request
            $self->{search_request} = $request;
            return $self;
        }

        else {
            # they're asking for the request object for a given attribute
            return $self->{search_request}{$request};
        }
    }
    return $self->{_search_request};
}

sub _handle_method {
    my ( $self, $method ) = @_;

    if ( $method->context == Class::Meta::CLASS ) {
        my $response = $method->call(
            $self->class->package,
            $self->_args_for_store,
        );
        if ( 'query' eq $method->name ) {
            $self->rest->xslt('search');
            return $self->_search_request( $response->request )
              ->_instance_list($response);
        }
        else {
            # XXX ???
        }
    }
    else {
        # XXX we're not actually doing anything with this yet.
        #my $obj = $self->class->contructors('lookup')->call(@$args)
        #  or die;
        #$method->call( $obj, @$args );
    }
}

sub _not_implemented {
    my $self = shift;
    my $rest = $self->rest;
    my $info = $rest->path_info;
    $rest->status($HTTP_NOT_IMPLEMENTED)
      ->response("No resource available to handle ($info)");
}

##############################################################################

=head3 _desired_attributes

  my @attributes = $self->_desired_attributes;

Returns the attributes for the current search class that will be listed in
the REST search interface.

Passing a true value will result in all non-referenced attributes being
returned.

=cut

sub _max_attribute_index {
    my $self = shift;
    unless (@_) {
        return $self->{max_attribute_index} || $MAX_ATTRIBUTE_INDEX;
    }
    $self->{max_attribute_index} = shift;
    return $self;
}

sub _all_attributes {
    my $self = shift;
    unless ( $self->{all_attributes} ) {
        my @attributes = grep {
            !$_->references && ( !exists $DONT_DISPLAY{ $_->name } )
        } $self->class->attributes;
        $self->{all_attributes} = \@attributes;
    }
    return wantarray ? @{ $self->{all_attributes} } : $self->{all_attributes};
}

sub _desired_attributes {
    my $self = shift;

    if ( !$self->{desired_attributes} ) {
        my $index      = $self->_max_attribute_index;
        my @attributes = grep {
            !$_->references && ( !exists $DONT_DISPLAY{ $_->name } )
        } $self->class->attributes;
        my $i =
            $index < $#attributes
            ? $index
            : $#attributes;

        # don't list all attributes
        @attributes = map { $_->name } @attributes[ 0 .. $i ];
        $self->{desired_attributes} = \@attributes;
    }
    return wantarray
        ? @{ $self->{desired_attributes} }
        : $self->{desired_attributes};
}

##############################################################################

=head3 _add_search_data

  $xml->_add_search_data($instance_count, $total);

This method adds the search data to the XML document. This is used by XSLT to
create the search form.

C<$instance_count> is how many instances were found. C<$total> is how many
instances meet the search criteria regardless of "limit" parameters.

=cut

# XXX Why is there XSLT-specific code here?

sub _add_search_data {
    my ( $self, $instance_count, $total ) = @_;
    my $xml = $self->_xml;

    my $args = $self->args;

    $self->_xml->add_pageset({
        args      => $args,
        class_key => $self->class_key,
        instances => $instance_count,
        total     => $total,
    });

    $xml->Element( $xml->elem('class_key'), $self->class_key );
    $xml->elem('search_parameters')->StartElement;

    # Add search string arguments
    foreach my $attribute ( $self->_all_attributes ) {
        my $name = $attribute->name;
        $xml->elem('parameter')->StartElement;
        $xml->attr('type')->AddAttribute($name);

        my $request = $self->_search_request($name);
        if ( $request && 'BETWEEN' eq $request->operator ) {
            my $data = $request->data;
            $xml->attr('between_1')->AddAttribute( $data->[0] );
            $xml->attr('between_2')->AddAttribute( $data->[1] );
        }
        else {
            my $widget = $attribute->widget_meta;
            if ( 'dropdown' eq $widget->type ) {
                $xml->add_select_widget(
                    {
                        element  => 'value',
                        name     => $name,
                        selected => '',
                        options  => $widget->options
                    }
                );
            }
            else {
                my $value = $request ? $request->formatted_data : '';
                $xml->attr('value')->AddAttribute($value);
            }
        }
        $self->_add_comparison_information($name);
        $xml->EndElement;
    }

    # add limit
    $xml->elem('parameter')->StartElement;
    $xml->attr('type')->AddAttribute($LIMIT_PARAM);
    $xml->attr('colspan')->AddAttribute(3);
    $xml->AddText( $args->get($LIMIT_PARAM) );
    $xml->EndElement;

    # add order_by
    my @options = map { [ $_ => ucfirst $_ ] } $self->_desired_attributes;
    my $order_by = $args->get($ORDER_BY_PARAM) || '';

    $xml->add_select_widget(
        {
            element  => 'parameter',
            name     => $ORDER_BY_PARAM,
            selected => $order_by,
            options  => \@options,
            colspan  => 3
        }
    );

    # add sort_order
    my @sort_options = ( [ ASC => 'Ascending' ], [ DESC => 'Descending' ] );
    my $sort_order = $args->get($SORT_PARAM) || 'ASC';

    $xml->add_select_widget(
        {
            element  => 'parameter',
            name     => $SORT_PARAM,
            selected => $sort_order,
            options  => \@sort_options,
            colspan  => 3
        }
    );
    $xml->EndElement;

    return $self;
}

{
    my @logical_options = ( [ '' => 'is' ], [ 'NOT' => 'is not' ] );
    # XXX These really need to be localized...and defined elsewhere.
    my @comparison_options = (
        [ EQ      => 'equal to' ],
        [ LIKE    => 'like' ],
        [ LT      => 'less than' ],
        [ GT      => 'greater than' ],
        [ LE      => 'less than or equal' ],
        [ GE      => 'greater than or equal' ],
        [ NE      => 'not equal' ],
        [ BETWEEN => 'between' ],
        [ ANY     => 'any of' ],
    );

    sub _add_comparison_information {
        my ( $self, $attribute ) = @_;
        my $xml     = $self->_xml;
        my $request = $self->_search_request($attribute);
        $xml->elem('comparisons')->StartElement;
        my $selected;
        if ($request) {
            $selected = $request->negated || "";
        }
        $xml->add_select_widget({
            element  => 'comparison',
            name     => "_${attribute}_logical",
            selected => $selected,
            options  => \@logical_options
        });
        if ($request) {
            $selected = $request->original_operator || "";
        }
        $xml->add_select_widget({
            element  => 'comparison',
            name     => "_${attribute}_comp",
            selected => $selected,
            options  => \@comparison_options
        });
        $xml->EndElement;
    }

}

##############################################################################

=head3 _add_instances

  $self->_add_instances($iterator);

This method adds a list of instances to the current XML document. The
instances are taken from an iterator returned by a Kinetic object search.

=cut

sub _add_instances {
    my ( $self, $iterator ) = @_;
    my $instance_count = 0;
    my $base_url       = $self->rest->base_url;
    my $query_string   = $self->rest->query_string;
    my $xml            = $self->_xml;

    while ( my $instance = $iterator->next ) {
        $instance_count++;
        my $uuid = $instance->uuid;
        my $url  = "$base_url" . $self->class_key
                 . "/lookup/uuid/$uuid$query_string";
        $xml->elem('instance')->StartElement;
        $xml->attr('id')->AddAttribute($uuid);
        $xml->attr('href')->AddAttribute($url);
        foreach my $attribute ( $self->_desired_attributes ) {
            my $value = ( $instance->$attribute || '' );
            $xml->elem('attribute')->StartElement;
            $xml->attr('name')->AddAttribute($attribute);
            $xml->AddText($value);
            $xml->EndElement;
        }
        $xml->EndElement;
    }

    unless ($instance_count) {
        $xml->elem('instance')->StartElement;
        $xml->attr('id')->AddAttribute('No resources found');
        $xml->attr('href')->AddAttribute($CURRENT_PAGE);
        $xml->EndElement;
    }
    return $instance_count;
}

##############################################################################

=head3 _add_column_sort_info

  $self->_add_column_sort_info

This method adds a <kinetic:sort/> tag to the XML document for each desired
attributes (see C<_desired_attributes>). This tag will contain a URL which
determines how that column should be sorted if the column header is clicked in
XHTML.

=cut

sub _add_column_sort_info {
    my $self         = shift;
    my $base_url     = $self->rest->base_url;
    my $query_string = $self->rest->query_string;
    my $xml          = $self->_xml;

    # list "sort" urls to be used in XHTML column headers
    my $args      = $self->args;
    my $sort_args = $args->clone;
    foreach my $attribute ( $self->_desired_attributes ) {
        my $url = "$base_url@{ [ $self->class_key ] }/query/";
        if ( $sort_args->exists($ORDER_BY_PARAM) ) {
            $sort_args->put( $ORDER_BY_PARAM, $attribute );
        }
        else {
            $sort_args->insert_after( $OFFSET_PARAM, $ORDER_BY_PARAM,
                $attribute );
        }
        my $order = 'ASC';
        if ( $attribute eq ( $args->get($ORDER_BY_PARAM) || '' )
            && 'ASC' eq ( $args->get($SORT_PARAM) || '' ) )
        {
            $order = 'DESC';
        }
        if ( $sort_args->exists($SORT_PARAM) ) {
            $sort_args->put( $SORT_PARAM, $order );
        }
        else {
            $sort_args->insert_after( $ORDER_BY_PARAM, $SORT_PARAM, $order );
        }
        $url .= join '/',
          map { '' eq $_ ? $PLACEHOLDER : $_ } $sort_args->get_array;
        $url .= $query_string;

        $xml->elem('sort')->StartElement;
        $xml->attr('name')->AddAttribute($attribute);
        $xml->AddText($url);
        $xml->EndElement;
    }
}

##############################################################################

=head3 class_list

  $dispatch->class_list($rest);

This function takes a L<Kinetic::UI::REST|Kinetic::UI::REST>
object and sets its content-type to C<text/xml> and its response to an XML
list of all classes registered with L<Kinetic::Meta|Kinetic::Meta>.

=cut

# XXX Again, this seems like something that should be defined elsewhere.

sub class_list {
    my ($self) = @_;

    my $response = $self->_xml->build($AVAILABLE_RESOURCES);
    return $self->rest->set_response($response);
}

##############################################################################

=head3 _instance_list

  $dispatch->_instance_list($iterator);

This function takes an iterator. It sets the rest instance's content-type to
C<text/xml> and its response to an XML list of all resources in the iterator,
keyed by UUID.

=cut

sub _instance_list {
    my ( $self, $iterator ) = @_;

    my $response = $self->_xml->build(
        $AVAILABLE_INSTANCES,
        sub {
            $self->_add_column_sort_info;
            my $instance_count = $self->_add_instances($iterator);
            $self->_add_search_data( $instance_count, $self->_count );
        },
    );
    return $self->rest->set_response($response);
}

sub _count {
    my $self = shift;

    # the first two dispatch->args should be the search string.  After that
    # are constraints for limit, order_by, etc.  These constraints are not
    # relevant to the count and may cause it to fail.
    my ($count) = $self->class->package->count( $self->get_args( 0, 1 ) );
    return $count;
}

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut

1;

