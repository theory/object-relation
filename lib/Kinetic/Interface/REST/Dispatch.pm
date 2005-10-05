package Kinetic::Interface::REST::Dispatch;

# $Id: REST.pm 1544 2005-04-16 01:13:51Z theory $

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;
use Data::Pageset;
use HTML::Entities qw/encode_entities/;
use Params::Validate qw/validate/;
use XML::Genx::Simple;

use Kinetic::Meta;
use Kinetic::XML;
use Kinetic::Store;
use Kinetic::Util::Constants qw/:http :xslt :labels :rest/;
use Kinetic::View::XSLT;

our $VERSION = version->new('0.0.1');

use Readonly;
Readonly my $XML_DECLARATION     => '<?xml version="1.0"?>';
Readonly my %DONT_DISPLAY        => ( uuid => 1 );
Readonly my $MAX_ATTRIBUTE_INDEX => 4;
Readonly my $PLACEHOLDER         => 'null';
Readonly my $DEFAULT_LIMIT       => 20;
Readonly my $DEFAULT_SEARCH_ARGS =>
  [ 'STRING', '', 'limit', $DEFAULT_LIMIT, 'offset', 0 ];

=head1 Name

Kinetic::REST - REST services provider

=head1 Synopsis

 use Kinetic::Interface::REST::Dispatch;

 if (my $sub = Kinetic::Interface::REST::Dispatch->can($method)) {
   $sub->($rest);
 }

=head1 Description

This is the dispatch class to which
L<Kinetic::Interface::REST|Kinetic::Interface::REST> will dispatch methods.
This is kept in a separate class to ensure that REST servers do not call these
methods directly.

=cut

##############################################################################

=head3 new

  my $dispatch = Kinetic::Interface::REST::Dispatch->new;

The constructor.  Currently takes no arguments;

=cut

sub new {
    my ($class) = @_;
    bless {}, $class;
}

##############################################################################

=head3 rest

 $dispatch->rest([$rest]);

Getter/setter for REST object.

=cut

sub rest {
    my $self = shift;
    return $self->{rest} unless @_;
    $self->{rest} = shift;
    return $self;
}

##############################################################################

=head3 class_key

  $dispatch->class_key([$class_key]);

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

  my $class = $self->class([$class]);

This method will return the current class object we're searching on.  If the 
class object has not been explicitly set with this method, it will attempt to
build a class object for using the current class key.

=cut

sub class {
    my $self = shift;
    unless (@_) {
        $self->{class} ||= Kinetic::Meta->for_key( $self->class_key );
        return $self->{class};
    }
    return $self;
}

##############################################################################

=head3 method

 $dispatch->method([$method]); 

Getter/setter for method to be sent to class created from class key.

=cut

sub method {
    my $self = shift;
    return $self->{method} unless @_;
    $self->{method} = shift;
    return $self;
}

##############################################################################

=head3 args

  $dispatch->arg([\@args]);

Getter/setter for args to accompany C<method>.  If the supplied argument
reference is emtpy, it will set a default of an empty string search, a
default limit and a default offset to 0.

=cut

sub args {
    my $self = shift;

    if (@_) {
        my $args = shift;
        foreach my $curr_arg (@$args) {
            $curr_arg = '' if $PLACEHOLDER eq $curr_arg;
        }
        if ( 'search' eq ( $self->method || '' ) ) {
            if (@$args) {
                if ( !grep { $_ eq 'limit' } @$args ) {
                    push @$args, 'limit', $DEFAULT_LIMIT;
                }
                if ( !grep { $_ eq 'offset' } @$args ) {
                    push @$args, 'offset', 0;
                }
            }
            else {
                $args = [];
                push @$args, $_ foreach @$DEFAULT_SEARCH_ARGS;
            }
        }
        $self->{args} = $args;
        return $self;
    }
    unless ( $self->{args} ) {
        $self->{args} = [];
        if ( 'search' eq $self->method ) {
            push @{ $self->{args} }, $_ foreach @$DEFAULT_SEARCH_ARGS;
        }
    }
    return $self->{args};
}

##############################################################################

=head3 get_args

  my @args = $dispatch->get_args( 0, 1 );

This method will return method arguments by index, starting with zero.  If no
arguments are supplied to this method, all method arguments will be returned.
Can take one or more arguments.  Returns a list of the arguments.

=cut

sub get_args {
    my $self = shift;
    return @{ $self->{args} } unless @_;
    return @{ $self->{args} }[@_];
}

sub _query_string {
    my $self = shift;
    my $type = lc $self->rest->cgi->param(TYPE_PARAM) || return '';
    return '' if 'xml' eq $type;    # because this is the default
    return "?" . TYPE_PARAM . "=$type";
}

##############################################################################

=head3 class_list

  $dispatch->class_list($rest);

This function takes a L<Kinetic::Interface::REST|Kinetic::Interface::REST>
instance and sets its content-type to C<text/xml> and its response to an XML
list of all classes registered with L<Kinetic::Meta|Kinetic::Meta>.

=cut

sub class_list {
    my ($self) = @_;

    my $response =
      $XML_DECLARATION . "\n" . $self->_class_list_xml(AVAILABLE_RESOURCES);
    return $self->rest->set_response($response);
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

sub _handle_constructor {
    my ( $self, $ctor ) = @_;
    my $obj  = $ctor->call( $self->class->package, $self->get_args );
    my $rest = $self->rest;
    my $xml  = Kinetic::XML->new(
        {
            object         => $obj,
            stylesheet_url => INSTANCE_XSLT,
            resources_url  => $self->_rest_base_url,
        }
    )->dump_xml;
    return $rest->set_response( $xml, 'instance' );
}

sub _handle_method {
    my ( $self, $method ) = @_;

    if ( $method->context == Class::Meta::CLASS ) {
        my $response = $method->call( $self->class->package, @{ $self->args } );
        if ( 'search' eq $method->name ) {
            $self->rest->xslt('search');
            return $self->_instance_list($response);
        }
        else {

            # XXX
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
    $rest->status(HTTP_NOT_IMPLEMENTED)
      ->response("No resource available to handle ($info)");
}

##############################################################################

=head3 _instance_list

  $dispatch->_instance_list($iterator);

This function takes an iterator.  It sets the rest instance's content-type to
C<text/xml> and its response to an XML list of all resources in the iterator,
keyed by uuid.

=cut

sub _instance_list_xml {
    my ( $self, $iterator ) = @_;

    my $rest        = $self->rest;
    my $stylesheet  = Kinetic::View::XSLT->location( $rest->xslt );
    my $output_type = lc $self->rest->cgi->param(TYPE_PARAM) || '';

    my $xml = XML::Genx::Simple->new;
    $xml->StartDocString;

    # declare namespaces
    my $kinetic_ns =
      $xml->DeclareNamespace( 'http://www.kineticode.com/rest' => 'kinetic' );
    my $xlink_ns =
      $xml->DeclareNamespace( 'http://www.w3.org/1999/xlink' => 'xlink' );

    # declare search metadata
    my $desc   = $xml->DeclareElement( $kinetic_ns => 'description' );
    my $domain = $xml->DeclareElement( $kinetic_ns => 'domain' );
    my $path   = $xml->DeclareElement( $kinetic_ns => 'path' );
    my $type   = $xml->DeclareElement( $kinetic_ns => 'type' );

    # instance list
    my $resources = $xml->DeclareElement( $kinetic_ns => 'resources' );
    my $resource  = $xml->DeclareElement( $kinetic_ns => 'resource' );
    my $instance  = $xml->DeclareElement( $kinetic_ns => 'instance' );
    my $attribute = $xml->DeclareElement( $kinetic_ns => 'attribute' );

    # page sets
    my $pages = $xml->DeclareElement( $kinetic_ns => 'pages' );
    my $page  = $xml->DeclareElement( $kinetic_ns => 'page' );

    # search parameters
    my $class_key  = $xml->DeclareElement( $kinetic_ns => 'class_key' );
    my $parameters = $xml->DeclareElement( $kinetic_ns => 'search_parameters' );
    my $parameter  = $xml->DeclareElement( $kinetic_ns => 'parameter' );
    my $option_elem = $xml->DeclareElement( $kinetic_ns => 'option' );

    # attributes
    my $href      = $xml->DeclareAttribute( $xlink_ns => 'href' );
    my $id        = $xml->DeclareAttribute('id');
    my $type_attr = $xml->DeclareAttribute('type');
    my $name_attr = $xml->DeclareAttribute('name');
    my $widget    = $xml->DeclareAttribute('widget');
    my $selected  = $xml->DeclareAttribute('selected');

    # add search metadata
    $xml->PI( 'xml-stylesheet', qq{type="text/xsl" href="$stylesheet"} );
    $resources->StartElement;
    $xlink_ns->AddNamespace;
    $xml->Element( $desc   => AVAILABLE_INSTANCES );
    $xml->Element( $domain => $rest->domain );
    $xml->Element( $path   => $rest->path );
    $xml->Element( $type   => $output_type );

    # add the resources
    my $base_url     = $self->_rest_base_url;
    my $query_string = $self->_query_string;
    foreach my $key ( sort Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $resource->StartElement;
        $id->AddAttribute($key);
        $href->AddAttribute("${base_url}$key/search$query_string");
        $xml->EndElement;
    }

    # add the instances

    my $instance_count = 0;
    my $key            = $self->class_key;
    my @attributes;
    while ( my $curr_instance = $iterator->next ) {
        unless (@attributes) {
            @attributes =
              grep { !$_->references && !exists $DONT_DISPLAY{ $_->name } }
              $curr_instance->my_class->attributes;
            my $i =
              $MAX_ATTRIBUTE_INDEX < $#attributes
              ? $MAX_ATTRIBUTE_INDEX
              : $#attributes;

            # don't list all attributes
            @attributes = @attributes[ 0 .. $i ];
        }
        $instance_count++;
        my $uuid = $curr_instance->uuid;
        my $url  = "$base_url$key/lookup/uuid/$uuid$query_string";
        $instance->StartElement;
        $id->AddAttribute($uuid);
        $href->AddAttribute($url);
        foreach my $instance_attribute (@attributes) {
            my $method = $instance_attribute->name;
            my $value = ( $curr_instance->$method || '' );
            $attribute->StartElement;
            $name_attr->AddAttribute($method);
            $xml->AddText($value);
            $xml->EndElement;
        }
        $xml->EndElement;
    }

    if ($instance_count) {

        # add pageset
        my %arg_for = @{ $self->args };
        my $pageset = $self->_pageset(
            {
                count  => $instance_count,
                limit  => $arg_for{limit},
                offset => $arg_for{offset},
            }
        );
        if ($pageset) {
            my @args = $self->get_args;

            my $url = "$base_url@{ [ $self->class_key ] }/search/";
            $url .= join '/', map { '' eq $_ ? $PLACEHOLDER : $_ } @args;
            $url =~ s{offset/\d+}{offset/\%d};
            $url .= $query_string;

            $pages->StartElement;
            foreach my $set ( $pageset->first_page .. $pageset->last_page ) {

                $page->StartElement;
                $id->AddAttribute("[ Page $set ]");
                if ( $set == $pageset->current_page ) {
                    $href->AddAttribute(CURRENT_PAGE);
                }
                else {
                    my $current_offset = ( $set - 1 ) * $arg_for{limit};
                    my $link_url = sprintf $url, $current_offset;
                    $href->AddAttribute($link_url);
                }
                $xml->EndElement;
            }
            $xml->EndElement;
        }

        my ( $order_by, $sort_order ) = ( 0, 0 );
        $xml->Element( $class_key, $self->class_key );
        $parameters->StartElement;
        $parameter->StartElement;
        $type_attr->AddAttribute('search');
        $xml->AddText( $arg_for{STRING} );
        $xml->EndElement;
        $parameter->StartElement;
        $type_attr->AddAttribute('limit');
        $xml->AddText( $arg_for{limit} );
        $xml->EndElement;

        my @sort_options = ( ASC => 'Ascending', DESC => 'Descending' );
        my $args    = $self->args;
        while ( defined( my $arg = shift @$args ) ) {
            next unless 'order_by' eq $arg || 'sort_order' eq $arg;
            my $value = shift @$args;
            if ( 'order_by' eq $arg && !$order_by ) {
                $order_by = 1;
                $parameter->StartElement;
                $type_attr->AddAttribute($arg);
                $xml->AddText($value);
                $xml->EndElement;
            }
            if ( 'sort_order' eq $arg && !$sort_order ) {
                $sort_order = 1;
                $parameter->StartElement;
                $type_attr->AddAttribute($arg);
                $widget->AddAttribute('select');
                for ( my $i = 0 ; $i < @sort_options ; $i += 2 ) {
                    my ( $option, $label ) = @sort_options[ $i, $i + 1 ];
                    $option_elem->StartElement;
                    $name_attr->AddAttribute($option);
                    if ( $option eq $value ) {
                        $selected->AddAttribute('selected');
                    }
                    $xml->AddText($label);
                    $xml->EndElement;
                }
                $xml->EndElement;
            }

           # XXX We last out of this as we only want the first order_by for this
            last if $order_by && $sort_order;
        }

        # must have default order_by
        if ( !$order_by ) {
            $parameter->StartElement;
            $type_attr->AddAttribute('order_by');
            $xml->EndElement;
        }

        # make Ascending sort order the default
        if ( !$sort_order ) {
            $parameter->StartElement;
            $type_attr->AddAttribute('sort_order');
            $widget->AddAttribute('select');
            for ( my $i = 0 ; $i < @sort_options ; $i += 2 ) {
                my ( $option, $label ) = @sort_options[ $i, $i + 1 ];
                $option_elem->StartElement;
                $name_attr->AddAttribute($option);
                if ( $option eq 'ASC' ) {
                    $selected->AddAttribute('selected');
                }
                $xml->AddText($label);
                $xml->EndElement;
            }
            $xml->EndElement;
        }
        $xml->EndElement;
    }
    else {
        $instance->StartElement;
        $id->AddAttribute('No resources found');
        $href->AddAttribute(CURRENT_PAGE);
        $xml->EndElement;
    }

    $xml->EndElement;
    $xml->EndDocument;
    return $xml->GetDocString;
}

sub _instance_list {
    my ( $self, $iterator ) = @_;

    my $response =
      $XML_DECLARATION . "\n" . $self->_instance_list_xml($iterator);
    return $self->rest->set_response($response);
}

##############################################################################

=head3 _pageset

  my $pageset = _pageset(\%pageset_info);

This function examines the arguments provided, the current pageset limit and
the current offset to determine if a pageset must be provided in the XML.
Pageset info keys are defined as follows:

=over 4

=item * count

The number of items on the current page.

=item * limit

The number of items per page.

=item * offset

The C<offset> supplied to the initial search.

=back

=cut

sub _pageset {
    my $self = shift;
    my $page = validate(
        @_,
        {
            count  => { default => 0 },
            limit  => { default => 0 },
            offset => { default => 0 },
        }
    );

    # current page == page number
    my $current_page =
      $page->{limit} ? 1 + int( $page->{offset} / $page->{limit} ) : 1;

    return if $current_page == 1 && $page->{count} < $page->{limit};

    # the first two dispatch->args should be the search string.  After that
    # are constraints for limit, order_by, etc.  These constraints are not
    # relevant to the count and may cause it to fail.
    my ($total_entries) =
      $self->class->package->count( $self->get_args( 0, 1 ) );

    # don't create a pageset if there is only one page
    return if $current_page == 1 && $page->{limit} == $total_entries;

    # by setting the pages_per_set to '1', we defer annoyance of dealing
    # with complicated page sets until such time we have enough data for
    # this to be an issue
    my $pageset = Data::Pageset->new(
        {
            total_entries    => $total_entries,
            entries_per_page => $page->{limit},
            pages_per_set    => 1,
            current_page     => $current_page,
        }
    );
    return $pageset;
}

##############################################################################

=head3 _rest_base_url

  my $rest_url_format = $self->_rest_base_url;

Returns a URL suitable for embedding in XML or XHTML hrefs.  Format is the in
the form of C<$url%s$query_string>.  This allows setting additional REST path
info items.

=cut

sub _rest_base_url {
    my $self = shift;
    my $rest = $self->rest;
    return join '' => map $rest->$_ => qw/domain path/;
}

sub _class_list_xml {
    my ( $self, $title ) = @_;

    my $rest        = $self->rest;
    my $stylesheet  = Kinetic::View::XSLT->location( $rest->xslt );
    my $output_type = lc $self->rest->cgi->param(TYPE_PARAM) || '';

    my $xml = XML::Genx::Simple->new;
    $xml->StartDocString;

    # declare namespaces
    my $kinetic_ns =
      $xml->DeclareNamespace( 'http://www.kineticode.com/rest' => 'kinetic' );
    my $xlink_ns =
      $xml->DeclareNamespace( 'http://www.w3.org/1999/xlink' => 'xlink' );

    # declare elements
    my $resources = $xml->DeclareElement( $kinetic_ns => 'resources' );
    my $desc      = $xml->DeclareElement( $kinetic_ns => 'description' );
    my $domain    = $xml->DeclareElement( $kinetic_ns => 'domain' );
    my $path      = $xml->DeclareElement( $kinetic_ns => 'path' );
    my $type      = $xml->DeclareElement( $kinetic_ns => 'type' );
    my $resource  = $xml->DeclareElement( $kinetic_ns => 'resource' );
    my $href      = $xml->DeclareAttribute( $xlink_ns => 'href' );
    my $id        = $xml->DeclareAttribute('id');

    # metadata
    $xml->PI( 'xml-stylesheet', qq{type="text/xsl" href="$stylesheet"} );
    $resources->StartElement;
    $xlink_ns->AddNamespace;
    $xml->Element( $desc   => $title );
    $xml->Element( $domain => $rest->domain );
    $xml->Element( $path   => $rest->path );
    $xml->Element( $type   => $output_type );

    # add the resources
    my $base_url     = $self->_rest_base_url;
    my $query_string = $self->_query_string;
    foreach my $key ( sort Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $resource->StartElement;
        $id->AddAttribute($key);
        $href->AddAttribute("${base_url}$key/search$query_string");
        $xml->EndElement;
    }
    $xml->EndElement;
    $xml->EndDocument;
    return $xml->GetDocString;
}

1;

__END__

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
