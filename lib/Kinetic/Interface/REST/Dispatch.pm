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
use Array::AsHash;
use Scalar::Util qw/blessed/;

use Kinetic::Meta;
use Kinetic::XML;
use Kinetic::Store;
use Kinetic::Util::Constants qw/:http :xslt :labels :rest/;
use Kinetic::Util::Exceptions qw/throw_fatal/;
use Kinetic::View::XSLT;

our $VERSION = version->new('0.0.1');

use Readonly;
Readonly my $XML_DECLARATION     => '<?xml version="1.0"?>';
Readonly my %DONT_DISPLAY        => ( uuid => 1 );
Readonly my $MAX_ATTRIBUTE_INDEX => 4;
Readonly my $PLACEHOLDER         => 'null';
Readonly my $DEFAULT_LIMIT       => 20;
Readonly my $DEFAULT_SEARCH_ARGS => {
    array => [ 'STRING', '', 'limit', $DEFAULT_LIMIT, 'offset', 0 ],
    clone => 1,
};

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
    return ( $self->{method} || 0 ) unless @_;
    $self->{method} = shift;
    return $self;
}

##############################################################################

=head3 args

  $dispatch->arg(Array::AsHash->new({array=>\@args});

Getter/setter for args to accompany C<method>.  If the supplied argument
reference is emtpy, it will set a default of an empty string search, a
default limit and a default offset to 0.

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
            $args->put( $k, '' ) if $PLACEHOLDER eq $v;
        }
        if ( 'search' eq $self->method ) {
            if ($args) {
                $args->default(
                    STRING => $PLACEHOLDER,
                    limit  => $DEFAULT_LIMIT,
                    offset => 0,
                );
                if ( $args->exists('order_by') ) {
                    $args->default( sort_order => 'ASC' );
                }
                $args = Array::AsHash->new(
                    {
                        array => [
                            $args->get_pairs(
                                qw/STRING limit offset order_by sort_order/)
                        ],
                    }
                );
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
        if ( 'search' eq $self->method ) {
            $args = $DEFAULT_SEARCH_ARGS;
        }
        $self->{args} = Array::AsHash->new($args);
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
      $XML_DECLARATION . "\n" . $self->_build_xml(AVAILABLE_RESOURCES);
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
        my $response =
          $method->call( $self->class->package, $self->args->get_array );
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

sub _xml {
    my $self = shift;
    return $self->{xml}{generator} unless @_;
    $self->{xml}{generator} = shift;
    return $self;
}

sub _xml_ns {
    my $self = shift;
    $self->_xml_prop_handler( 'ns', 'XML namespace', @_ );
}

sub _xml_attr {
    my $self = shift;
    $self->_xml_prop_handler( 'attr', 'XML attribute', @_ );
}

sub _xml_elem {
    my $self = shift;
    $self->_xml_prop_handler( 'elem', 'XML element', @_ );
}

sub _xml_prop_handler {
    my $self       = shift;
    my $prop       = shift;
    my $identifier = shift;
    return $self->{xml}{$prop} unless @_;
    my $name = shift;
    if ( !defined $name ) {
        delete $self->{xml}{$prop};
    }
    if ( 'HASH' eq ref $name ) {
        while ( my ( $curr_prop, $value ) = each %$name ) {
            $self->{xml}{$prop}{$curr_prop} = $value;
        }
        return $self;
    }
    unless (@_) {
        unless ( exists $self->{xml}{$prop}{$name} ) {
            throw_fatal [ 'No such attribute "[_1]" for [_2]', $name,
                $identifier ];
        }
        return $self->{xml}{$prop}{$name};
    }
    $self->{xml}{ns}{$name} = shift;
}

##############################################################################

=head3 _xml_setup

  my $xml = $self->_xml_setup;

This method sets up all available namespaces, tag elements and attributes for 
Kinetic REST XML.  Returns an L<XML::Genx> object.

It caches the XML object but also returns it as a convenience.

=cut

sub _xml_setup {
    my $self = shift;

    my $xml = XML::Genx::Simple->new;
    $self->_xml($xml);

    my %ns_for = (
        kinetic => $xml->DeclareNamespace(
            'http://www.kineticode.com/rest' => 'kinetic'
        ),
        xlink =>
          $xml->DeclareNamespace( 'http://www.w3.org/1999/xlink' => 'xlink' ),
    );
    $self->_xml_ns( \%ns_for );

    my @search_metadata   = qw/description domain path type/;
    my @instance_list     = qw/resources sort resource instance attribute/;
    my @search_parameters = qw/search_parameters parameter option class_key/;
    my %elem_for          =
      map { $_ => $xml->DeclareElement( $self->_xml_ns('kinetic') => $_ ) }
      @search_metadata, @instance_list, @search_parameters;
    $self->_xml_elem( \%elem_for );

    # attributes
    my %attr_for =
      map { $_ => $xml->DeclareAttribute($_) }
      qw/ id type name widget selected /;
    $attr_for{href} =
      $xml->DeclareAttribute( $self->_xml_ns('xlink') => 'href' );
    $self->_xml_attr( \%attr_for );
    return $xml;
}

##############################################################################

=head3 _add_rest_metadata

  $self->_add_rest_metadata($title);

Adds the REST metadata to the XML document.  The REST metadata is used by
XSLT to understand how to build URLs for the REST resources.

=cut

sub _add_rest_metadata {
    my ( $self, $title ) = @_;
    my $rest        = $self->rest;
    my $xml         = $self->_xml;
    my $output_type = lc $rest->cgi->param(TYPE_PARAM) || '';
    $xml->Element( $self->_xml_elem('description') => $title );
    $xml->Element( $self->_xml_elem('domain')      => $rest->domain );
    $xml->Element( $self->_xml_elem('path')        => $rest->path );
    $xml->Element( $self->_xml_elem('type')        => $output_type );
    return $self;
}

##############################################################################

=head3 _build_xml

  my $xml = $self->_build_xml( $title, [$callback] );

This method builds most XML pages.  It accepts a "title" for the document and
an optional callback.  If the callback is a coderef, it assumes that it's an
XML building snippet which will add new XML after the resource list.

If callback is not present or not a CODEREF, it's ignored.

=cut

sub _build_xml {
    my ( $self, $title, $callback ) = @_;
    my $xml = $self->_xml_setup;
    $xml->StartDocString;

    my $stylesheet = Kinetic::View::XSLT->location( $self->rest->xslt );
    $xml->PI( 'xml-stylesheet', qq{type="text/xsl" href="$stylesheet"} );
    $self->_xml_elem('resources')->StartElement;
    $self->_xml_ns('xlink')->AddNamespace;

    $self->_add_rest_metadata($title);
    $self->_add_resource_list;

    $callback->() if $callback && 'CODE' eq ref $callback;

    $xml->EndElement;
    $xml->EndDocument;
    return $xml->GetDocString;
}

##############################################################################

=head3 _add_resource_list

  $self->_add_resource_list;

Adds the list of resources (Kinetic classes) to the current XML document.

=cut

sub _add_resource_list {
    my $self         = shift;
    my $base_url     = $self->_rest_base_url;
    my $query_string = $self->_query_string;
    foreach my $key ( sort Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $self->_xml_elem('resource')->StartElement;
        $self->_xml_attr('id')->AddAttribute($key);
        $self->_xml_attr('href')
          ->AddAttribute("${base_url}$key/search$query_string");
        $self->_xml->EndElement;
    }
    return $self;
}

##############################################################################

=head3 _add_search_data

  $xml->_add_search_data($instance_count);

This method adds the search data to the XML document.  This is used by XSLT
to create the search form.

=cut

sub _add_search_data {
    my ( $self, $instance_count ) = @_;
    my $xml = $self->_xml;

    my $args = $self->args;

    $self->_add_pageset($instance_count);

    $xml->Element( $self->_xml_elem('class_key'), $self->class_key );
    $self->_xml_elem('search_parameters')->StartElement;

    # Add search string arguments
    $self->_xml_elem('parameter')->StartElement;
    $self->_xml_attr('type')->AddAttribute('search');
    $xml->AddText( $args->get('STRING') );
    $xml->EndElement;

    # add limit
    $self->_xml_elem('parameter')->StartElement;
    $self->_xml_attr('type')->AddAttribute('limit');
    $xml->AddText( $args->get('limit') );
    $xml->EndElement;

    # add order_by
    $self->_xml_elem('parameter')->StartElement;
    $self->_xml_attr('type')->AddAttribute('order_by');
    $xml->AddText( $args->get('order_by') ) if $args->exists('order_by');
    $xml->EndElement;

    # add sort_order
    my @sort_options = ( ASC => 'Ascending', DESC => 'Descending' );
    my $sort_order = $args->get('sort_order') || 'ASC';
    $self->_add_select_widget( 'sort_order', $sort_order, \@sort_options );
    $xml->EndElement;

    return $self;
}

##############################################################################

=head3 _add_select_widget

  $self->_add_select_widget($name, $selected, \@options);

This method adds a select widget to the XML being built.  C<$name> is the name
of the select widget.  C<$selected> is the name of the option currently
selected, if any.  C<@options> should be an ordered list of key/value pairs
where the the keys are the names of the options and the values are the labels
which should be displayed.

=cut

sub _add_select_widget {
    my ( $self, $name, $selected, $options ) = @_;
    my $xml = $self->_xml;
    $self->_xml_elem('parameter')->StartElement;
    $self->_xml_attr('type')->AddAttribute($name);
    $self->_xml_attr('widget')->AddAttribute('select');
    for ( my $i = 0 ; $i < @$options ; $i += 2 ) {
        my ( $option, $label ) = @$options[ $i, $i + 1 ];
        $self->_xml_elem('option')->StartElement;
        $self->_xml_attr('name')->AddAttribute($option);
        if ( $option eq $selected ) {
            $self->_xml_attr('selected')->AddAttribute('selected');
        }
        $xml->AddText($label);
        $xml->EndElement;
    }
    $xml->EndElement;
}

##############################################################################

=head3 _add_instances

  $self->_add_instances($iterator);

This method adds a list of instances to the current XML document.  The
instances are taken from an iterator returned by a Kinetic object search.

=cut

sub _add_instances {
    my ( $self, $iterator ) = @_;
    my $instance_count = 0;
    my $base_url       = $self->_rest_base_url;
    my $query_string   = $self->_query_string;
    my $xml            = $self->_xml;

    while ( my $instance = $iterator->next ) {
        $instance_count++;
        my $uuid = $instance->uuid;
        my $url  =
          "$base_url" . $self->class_key . "/lookup/uuid/$uuid$query_string";
        $self->_xml_elem('instance')->StartElement;
        $self->_xml_attr('id')->AddAttribute($uuid);
        $self->_xml_attr('href')->AddAttribute($url);
        foreach my $attribute ( $self->_desired_attributes ) {
            my $value = ( $instance->$attribute || '' );
            $self->_xml_elem('attribute')->StartElement;
            $self->_xml_attr('name')->AddAttribute($attribute);
            $xml->AddText($value);
            $xml->EndElement;
        }
        $xml->EndElement;
    }

    unless ($instance_count) {
        $self->_xml_elem('instance')->StartElement;
        $self->_xml_attr('id')->AddAttribute('No resources found');
        $self->_xml_attr('href')->AddAttribute(CURRENT_PAGE);
        $xml->EndElement;
    }
    return $instance_count;
}

##############################################################################

=head3 _add_column_sort_info

  $self->_add_column_sort_info

This method adds a <kinetic:sort/> tag to the XML document for each desired
attributes (see C<_desired_attributes>).  This tag will contain a URL which
determines how that column should be sorted if the column header is clicked
in XHTML.

=cut

sub _add_column_sort_info {
    my $self         = shift;
    my $base_url     = $self->_rest_base_url;
    my $query_string = $self->_query_string;
    my $xml          = $self->_xml;

    # list "sort" urls to be used in XHTML column headers
    my $args      = $self->args;
    my $sort_args = $args->clone;
    foreach my $attribute ( $self->_desired_attributes ) {
        my $url = "$base_url@{ [ $self->class_key ] }/search/";
        if ( $sort_args->exists('order_by') ) {
            $sort_args->put( 'order_by', $attribute );
        }
        else {
            $sort_args->insert_after( 'offset', order_by => $attribute );
        }
        my $order = 'ASC';
        if ( $attribute eq ( $args->get('order_by') || '' )
            && 'ASC' eq ( $args->get('sort_order') || '' ) )
        {
            $order = 'DESC';
        }
        if ( $sort_args->exists('sort_order') ) {
            $sort_args->put( 'sort_order', $order );
        }
        else {
            $sort_args->insert_after( 'order_by', sort_order => $order );
        }
        $url .= join '/',
          map { '' eq $_ ? $PLACEHOLDER : $_ } $sort_args->get_array;
        $url .= $query_string;

        $self->_xml_elem('sort')->StartElement;
        $self->_xml_attr('name')->AddAttribute($attribute);
        $xml->AddText($url);
        $xml->EndElement;
    }
}

##############################################################################

=head3 _desired_attributes

  my @attributes = $self->_desired_attributes;

Returns the attributes for the current search class which will be listed in the
REST search interface.

=cut

sub _desired_attributes {
    my $self = shift;
    unless ( $self->{attributes} ) {
        my @attributes =
          grep { !$_->references && !exists $DONT_DISPLAY{ $_->name } }
          $self->class->attributes;
        my $i =
          $MAX_ATTRIBUTE_INDEX < $#attributes
          ? $MAX_ATTRIBUTE_INDEX
          : $#attributes;

        # don't list all attributes
        @attributes = map { $_->name } @attributes[ 0 .. $i ];
        $self->{attributes} = \@attributes;
    }
    return wantarray ? @{ $self->{attributes} } : $self->{attributes};
}

##############################################################################

=head3 _add_pageset

  $self->_add_pageset($instance_count);

Given a count of how many instances were found in the last search, this method
will add "paging" information to the XML.  This is used by the XSLT to create
page links to the various documents.

=cut

sub _add_pageset {
    my ( $self, $instance_count ) = @_;

    my $args    = $self->args;
    my $pageset = $self->_pageset(
        {
            count  => $instance_count,
            limit  => ( $args->get('limit') || '' ),
            offset => ( $args->get('offset') || '' ),
        }
    );
    return unless $pageset;

    my $base_url     = $self->_rest_base_url;
    my $query_string = $self->_query_string;
    my $url          = "$base_url@{ [ $self->class_key ] }/search/";
    $url .= join '/', map { '' eq $_ ? $PLACEHOLDER : $_ } $args->get_array;
    $url .= $query_string;

    # page sets
    my $xml   = $self->_xml;
    my $pages = $xml->DeclareElement( $self->_xml_ns('kinetic') => 'pages' );
    my $page  = $xml->DeclareElement( $self->_xml_ns('kinetic') => 'page' );

    $pages->StartElement;
    foreach my $set ( $pageset->first_page .. $pageset->last_page ) {

        $page->StartElement;
        $self->_xml_attr('id')->AddAttribute("[ Page $set ]");
        if ( $set == $pageset->current_page ) {
            $self->_xml_attr('href')->AddAttribute(CURRENT_PAGE);
        }
        else {
            my $current_offset = ( $set - 1 ) * $args->get('limit');
            $url =~ s{offset/\d+}{offset/$current_offset};
            $self->_xml_attr('href')->AddAttribute($url);
        }
        $xml->EndElement;
    }
    $xml->EndElement;
}

##############################################################################

=head3 _instance_list

  $dispatch->_instance_list($iterator);

This function takes an iterator.  It sets the rest instance's content-type to
C<text/xml> and its response to an XML list of all resources in the iterator,
keyed by uuid.

=cut

sub _instance_list {
    my ( $self, $iterator ) = @_;

    my $response = $XML_DECLARATION . "\n" . $self->_build_xml(
        AVAILABLE_INSTANCES,
        sub {
            $self->_add_column_sort_info;
            my $instance_count = $self->_add_instances($iterator);
            $self->_add_search_data($instance_count);
        },
    );
    return $self->rest->set_response($response);
}

##############################################################################

=head3 _pageset

  my $pageset = _pageset(\%pageset_info);

This function examines the arguments provided, the current pageset limit and
the current offset to determine if a pageset must be provided in the XML.

Returns false if no pageset needs to be created.  Otherwise it returns a
L<Data::Pageset> object.

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
            count  => { default => 0 },    # number of items on current page
            limit  => { default => 0 },
            offset => { default => 0 },
        }
    );
    $page->{offset} ||= 0;    # XXX sometimes this is undef.  Find out why

    # current page == page number
    my $current_page =
      $page->{limit} ? 1 + int( $page->{offset} / $page->{limit} ) : 1;

    #{
    #    use Data::Dumper::Names;
    #    my $count = $self->_count;
    #    warn Dumper( $current_page, $page, $count );
    #}
    return if $current_page == 1 && $page->{count} < $page->{limit};

    my $total_entries = $self->_count;

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

sub _count {
    my $self = shift;

    # the first two dispatch->args should be the search string.  After that
    # are constraints for limit, order_by, etc.  These constraints are not
    # relevant to the count and may cause it to fail.
    my ($count) = $self->class->package->count( $self->get_args( 0, 1 ) );
    return $count;
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
