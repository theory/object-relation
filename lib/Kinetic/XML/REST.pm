package Kinetic::XML::REST;

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
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use Kinetic::Meta;
use Kinetic::View::XSLT;
use Kinetic::Util::Exceptions qw/throw_fatal/;
use Kinetic::Util::Constants qw/:xslt :rest/;

use Readonly;
Readonly my $PLACEHOLDER     => 'null';
Readonly my $XML_DECLARATION => '<?xml version="1.0"?>';

use XML::Genx::Simple;
use Data::Pageset;
use Params::Validate qw/validate validate_pos/;
use Class::Delegator send => [
    qw/
      AddAttribute
      AddNamespace
      AddText
      DeclareNamespace
      DeclareElement
      Element
      EndDocument
      EndElement
      GetDocString
      PI
      StartDocString
      StartElement
      /
  ],
  to => '_xml';

sub _xml { shift->{xml}{generator} }

=head1 Name

Kinetic::XML::REST - Kinetic REST XML generator

=head1 Synopsis

 use Kinetic::XML::REST;

 my $xml = Kinetic::XML::REST->new({ rest => $rest });

=head1 Description

This class generates Kinetic XML for the REST services.  It encapsulates
knowledge about the namespaces, elements and attributes used.

=cut

##############################################################################

=head3 new

  my $xml = Kinetic::XML::REST->new( { rest => $rest } );

The constructor.  The C<rest> argument should be an object conforming to the
C<Kinetic::Interface::Rest> interface.

=cut

sub new {
    my $class   = shift;
    my $arg_for = validate(
        @_,
        {
            'rest',
            { can => [qw/domain path output_type query_string base_url xslt/] }
        }
    );
    my $xml = XML::Genx::Simple->new;
    my $self = bless {
        xml  => { generator      => $xml },
        rest => $arg_for->{rest},
    }, $class;
    $self->_init;
}

sub _init {
    my $self = shift;
    $self->_init_namespaces;
    $self->_init_elements;
    $self->_init_attributes;
}

sub _init_namespaces {
    my $self   = shift;
    my %ns_for = (
        kinetic => $self->_xml->DeclareNamespace(
            'http://www.kineticode.com/rest' => 'kinetic'
        ),
        xlink => $self->_xml->DeclareNamespace(
            'http://www.w3.org/1999/xlink' => 'xlink'
        ),
    );
    $self->ns( \%ns_for );
    return $self;
}

sub _init_elements {
    my $self              = shift;
    my $xml               = $self->_xml;
    my @search_metadata   = qw/description domain path type/;
    my @instance_list     = qw/resources sort resource instance attribute/;
    my @search_parameters =
      qw/search_parameters parameter comparisons comparison option class_key value/;
    my %elem_for =
      map { $_ => $xml->DeclareElement( $self->ns('kinetic') => $_ ) }
      @search_metadata, @instance_list, @search_parameters;
    $self->elem( \%elem_for );
    return $self;
}

sub _init_attributes {
    my $self     = shift;
    my $xml      = $self->_xml;
    my %attr_for =
      map { $_ => $xml->DeclareAttribute($_) }
      qw/ id type name widget selected colspan value between_1 between_2 /;
    $attr_for{href} = $xml->DeclareAttribute( $self->ns('xlink') => 'href' );
    $self->attr( \%attr_for );
    return $self;
}

##############################################################################

=head3 ns

  my $namespace = $xml->ns($name);

Returns a namespace object. Currently supported names are:

=over 4

=item * kinetic

=item * xmlns

=back

Namespaces are used internally and are probably not required outside of this
module.

=cut

sub ns {
    my $self = shift;
    $self->_xml_prop_handler( 'ns', 'XML namespace', @_ );
}

##############################################################################

=head3 elem

  my $element = $xml->element($name);

Returns an element object.  Currently supported elements are:

=over 4

=item * attribute

=item * class_key

=item * comparison

=item * comparisons

=item * description

=item * domain

=item * instance

=item * option

=item * parameter

=item * path

=item * resource

=item * resources

=item * search_parameters

=item * sort

=item * type

=item * value

=back

=cut

sub elem {
    my $self = shift;
    $self->_xml_prop_handler( 'elem', 'XML element', @_ );
}

##############################################################################

=head3 attr

  my $attribute = $xml->attribute($name);

Returns an attribute object.  Currently supported attributes are:

=over 4

=item * between_1

=item * between_2

=item * colspan

=item * href

=item * id

=item * name

=item * selected

=item * type

=item * value

=item * widget

=back

=cut

sub attr {
    my $self = shift;
    $self->_xml_prop_handler( 'attr', 'XML attribute', @_ );
}

sub _xml_prop_handler {
    my ( $self, $property_for, $identifier, $name ) = splice @_, 0, 4;

    if ( !defined $name ) {
        throw_fatal [ 'You must supply a name for the "[_1]"', $identifier ];
    }

    if ( 'HASH' eq ref $name ) {

        # we probably got here through one of the _init methods
        while ( my ( $curr_prop, $value ) = each %$name ) {
            $self->{xml}{$property_for}{$curr_prop} = $value;
        }
        return $self;
    }

    if ( !exists $self->{xml}{$property_for}{$name} ) {
        throw_fatal [ 'No such attribute "[_1]" for [_2]', $name, $identifier ];
    }
    return $self->{xml}{$property_for}{$name};
}

##############################################################################

=head3 rest

  my $rest = $xml->rest;

Returns the REST object passed to the constructor.

=cut

sub rest {
    my $self = shift;
    return $self->{rest} unless @_;
    $self->{rest} = shift;
    return $self;
}

##############################################################################

=head3 add_rest_metadata

  $xml->add_rest_metadata($title);

Adds the REST metadata to the XML document.  The REST metadata is used by
XSLT to understand how to build URLs for the REST resources.

=cut

sub add_rest_metadata {
    my ( $self, $title ) = @_;
    my $rest = $self->rest;
    $self->Element( $self->elem('description') => $title );
    $self->Element( $self->elem('domain')      => $rest->domain );
    $self->Element( $self->elem('path')        => $rest->path );
    $self->Element( $self->elem('type')        => $rest->output_type );
    return $self;
}

##############################################################################

=head3 add_resource_list

  $self->add_resource_list;

Adds the list of resources (Kinetic classes) to the current XML document.

=cut

sub add_resource_list {
    my ($self) = @_;
    my $rest         = $self->rest;
    my $base_url     = $rest->base_url;
    my $query_string = $rest->query_string;
    foreach my $key ( sort Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $self->elem('resource')->StartElement;
        $self->attr('id')->AddAttribute($key);
        $self->attr('href')
          ->AddAttribute("${base_url}$key/search$query_string");
        $self->EndElement;
    }
    return $self;
}

##############################################################################

=head3 add_select_widget

  $xml->add_select_widget($name, $selected, \@options);

This method adds a select widget to the XML being built.  C<$name> is the name
of the select widget.  C<$selected> is the name of the option currently
selected, if any.  C<@options> should be an ordered list of key/value pair
array references where the the keys are the names of the options and the
values are the labels which should be displayed.

=cut

sub add_select_widget {
    my ( $self, $arg_for ) = @_;

    $self->elem( $arg_for->{element} )->StartElement;
    $self->attr('type')->AddAttribute( $arg_for->{name} );
    $self->attr('widget')->AddAttribute('select');
    $self->attr('colspan')->AddAttribute( $arg_for->{colspan} )
      if defined $arg_for->{colspan};
    foreach my $option ( @{ $arg_for->{options} } ) {
        my ( $value, $label ) = @$option;
        $self->elem('option')->StartElement;
        $self->attr('name')->AddAttribute($value);
        if ( $value eq ( $arg_for->{selected} || '' ) ) {
            $self->attr('selected')->AddAttribute('selected');
        }
        $self->AddText($label);
        $self->EndElement;
    }
    $self->EndElement;
    return $self;
}

##############################################################################

=head3 add_pageset

  $xml->add_pageset(
    {
        args      => $args,
        class_key => $self->class_key,
        instances => $instance_count,
        total     => $total,
    }
  );

Given a count of how many instances were found in the last search, this method
will add "paging" information to the XML.  This is used by the XSLT to create
page links to the various documents.

C<$instance_count> is how many instances were found.  C<$total> is how many
instances meet the search criteria regardless of "limit" parameters.  C<$args>
is the args object created in the REST class.

=cut

sub add_pageset {
    my ( $self, $arg_for ) = @_;

    my $args = $arg_for->{args};

    my $pageset = $self->_get_pageset(
        {
            count         => $arg_for->{instances},
            total_entries => $arg_for->{total},
            limit         => ( $args->get(LIMIT_PARAM) || '' ),
            offset        => ( $args->get(OFFSET_PARAM) || 0 ),
        }
    );
    return unless $pageset;

    my $base_url     = $self->rest->base_url;
    my $query_string = $self->rest->query_string;
    my $url          = "$base_url$arg_for->{class_key}/search/";
    $url .= join '/', map { '' eq $_ ? $PLACEHOLDER : $_ } $args->get_array;
    $url .= $query_string;

    # page sets
    my $pages = $self->DeclareElement( $self->ns('kinetic') => 'pages' );
    my $page  = $self->DeclareElement( $self->ns('kinetic') => 'page' );

    $pages->StartElement;
    foreach my $set ( $pageset->first_page .. $pageset->last_page ) {

        $page->StartElement;
        $self->attr('id')->AddAttribute("[ Page $set ]");
        if ( $set == $pageset->current_page ) {
            $self->attr('href')->AddAttribute(CURRENT_PAGE);
        }
        else {
            my $current_offset = ( $set - 1 ) * $args->get(LIMIT_PARAM);
            my $offset_param   = OFFSET_PARAM;
            $url =~ s{$offset_param/\d+}{$offset_param/$current_offset};
            $self->attr('href')->AddAttribute($url);
        }
        $self->EndElement;
    }
    $self->EndElement;
}

##############################################################################

=head3 _get_pageset

  my $pageset = $xml->_get_pageset(\%pageset_info);

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

=item * total_entries

The total number of items which match the search criteria, regardless of limit
constraints.

=back

=cut

sub _get_pageset {
    my $self = shift;
    my $page = validate(
        @_,
        {
            count         => { default => 0 }, # number of items on current page
            limit         => { default => 0 },
            offset        => { default => 0 },
            total_entries => { default => 0 },
        }
    );
    $page->{offset} ||= 0;    # XXX sometimes this is undef.  Find out why

    # current page == page number
    my $current_page =
      $page->{limit} ? 1 + int( $page->{offset} / $page->{limit} ) : 1;

    return if $current_page == 1 && $page->{count} < $page->{limit};

    # don't create a pageset if there is only one page
    return if $current_page == 1 && $page->{limit} == $page->{total_entries};

    # by setting the pages_per_set to '1', we defer annoyance of dealing
    # with complicated page sets until such time we have enough data for
    # this to be an issue
    my $pageset = Data::Pageset->new(
        {
            total_entries    => $page->{total_entries},
            entries_per_page => $page->{limit},
            pages_per_set    => 1,
            current_page     => $current_page,
        }
    );
    return $pageset;
}

##############################################################################

=head3 build

  my $xml = $xml->build( $title, [$callback] );

This method builds most XML pages.  It accepts a "title" for the document and
an optional callback.  If the callback is a coderef, it assumes that it's an
XML building snippet which will add new XML after the resource list.

The title is not an abritrary title.  It's also an identifier which is used to
determine which XML document is built.

If callback is not present or not a CODEREF, it's ignored.

=cut

# XXX should $title be removed in favor of us calling different instance
# methods indicating with XML document should be built?  I think so.

sub build {
    my ( $self, $title, $callback ) = @_;
    my $rest = $self->rest;
    $self->StartDocString;

    my $stylesheet = Kinetic::View::XSLT->location( $rest->xslt ) || '';
    $self->PI( 'xml-stylesheet', qq{type="text/xsl" href="$stylesheet"} );
    $self->elem('resources')->StartElement;
    $self->ns('xlink')->AddNamespace;

    $self->add_rest_metadata($title);
    $self->add_resource_list;

    $callback->() if $callback && 'CODE' eq ref $callback;

    $self->EndElement;
    $self->EndDocument;
    return $XML_DECLARATION . "\n" . $self->GetDocString;
}

##############################################################################

=head1 Delegated methods

The following methods all add to the current XML document being built.
Currently they are delegated to C<XML::Genx::Simple>.

=over 4

=item * AddAttribute

=item * AddNamespace

=item * AddText

=item * DeclareNamespace

=item * DeclareElement

=item * Element

=item * EndDocument

=item * EndElement

=item * GetDocString

=item * PI

=item * StartDocString

=item * StartElement

=back

=cut

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
