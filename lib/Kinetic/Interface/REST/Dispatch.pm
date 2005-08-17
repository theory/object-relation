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
use version;
use Data::Pageset;
use Params::Validate;

use Kinetic::Meta;
use Kinetic::XML;
use Kinetic::Meta::XML;
use Kinetic::Store;
use Kinetic::Util::Constants qw/:http :data_store :xslt/;

our $VERSION = version->new('0.0.1');

use constant DEFAULT_LIMIT => 20;
use constant DEFAULT_ARGS  =>
  [ 'STRING', '', 'limit', DEFAULT_LIMIT, 'offset', 0 ];

=head1 Name

Kinetic::REST - REST services provider

=head1 Synopsis

 use Kinetic::Interface::REST::Dispatch;

 if (my $sub = Kinetic::Interface::REST::Dispatch->can($method)) {
   $sub->($rest);
 }

=head1 Description

This is the dispatch class to which
L<Kinetic::Interface::REST|Kinetic::Interface::REST> will dispatch messages.
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

=head3 message

 $dispatch->message([$message]); 

Getter/setter for message to be sent to class created from class key.

=cut

sub message {
    my $self = shift;
    return $self->{message} unless @_;
    $self->{message} = shift;
    return $self;
}

##############################################################################

=head3 args

  $dispatch->arg([\@args]);

Getter/setter for args to accompany C<message>.  If the supplied argument
reference is emtpy, it will set a default of an empty string search, a
default limit and a default offset to 0.

=cut

sub args {
    my $self = shift;
    if (@_) {
        my $args = shift;
        if (@$args) {
            if ( !grep { $_ eq 'limit' } @$args ) {
                push @$args, 'limit', DEFAULT_LIMIT;
            }
            if ( !grep { $_ eq 'offset' } @$args ) {
                push @$args, 'offset', 0;
            }
        }
        else {
            $args = DEFAULT_ARGS;
        }
        $self->{args} = $args;
        return $self;
    }
    $self->{args} ||= DEFAULT_ARGS;
    return $self->{args};
}

##############################################################################

=head3 get_args

  my @args = $dispatch->get_args( 0, 1 );

This method will return message arguments by index, starting with zero.  If no
arguments are supplied to this method, all message arguments will be returned.
Can take one or more arguments.  Returns a list of the arguments.

=cut

sub get_args {
    my $self = shift;
    return @{ $self->{args} } unless @_;
    return @{ $self->{args} }[@_];
}

sub _query_string {
    my $rest = shift;
    my $type = lc $rest->cgi->param('type') || return '';
    return '' if 'xml' eq $type;    # because this is the default
    return "?type=$type";
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

    my $rest = $self->rest;
    if ( my $stylesheet = $rest->cgi->param('stylesheet') ) {
        my $xml = $rest->stylesheet;
        $rest->content_type(XML_CT)->response($xml);
        return;
    }
    my $response = _xml_header( $rest, 'Available resources' );

    my $base_url     = _rest_base_url($rest);
    my $query_string = _query_string($rest);
    foreach my $key ( sort Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $response .=
qq'<kinetic:resource id="$key" xlink:href="${base_url}$key/search$query_string"/>';
    }
    $response .= "</kinetic:resources>";
    return $rest->set_response($response);
}

=head3 handle_rest_request

 $dispatch->handle_rest_request

=cut

sub handle_rest_request {
    my ($self) = @_;

    my ( $class, $method, $ctor );
    eval { $class = Kinetic::Meta->for_key( $self->class_key ) };
    my $message = $self->message;
    if ( $class && $message ) {
        $self->class($class);
        $method = $class->methods($message);
        $ctor = $method ? '' : $class->constructors($message);
    }

    return $ctor ? $self->_handle_constructor($ctor)
      : $method  ? $self->_handle_method($method)
      : $self->_not_implemented;
}

sub _handle_constructor {
    my ( $self, $ctor ) = @_;
    my $obj  = $ctor->call( $self->class->package, $self->get_args );
    my $rest = $self->rest;
    my $xml  = Kinetic::XML->new(
        {
            object         => $obj,
            stylesheet_url => $rest->stylesheet_url('instance'),
        }
    )->dump_xml;
    return $rest->set_response( $xml, 'instance' );
}

sub _handle_method {
    my ( $self, $method ) = @_;
    my $args = _normalize_args( $method, $self->args );
    if ( $method->context == Class::Meta::CLASS ) {
        my $response = $method->call( $self->class->package, @$args );
        if ( 'search' eq $method->name ) {
            return $self->_instance_list($response);
        }
        else {

            # XXX
        }
    }
    else {

        # XXX we're not actually doing anything with this yet.
        my $obj = $self->class->contructors('lookup')->call(@$args)
          or die;
        $method->call( $obj, @$args );
    }
}

# since // is effectively a no-op in a path, the URL may have
# "null" in the path to hold that segment open.  Here's where
# we convert it to a space.
#
# we also set the limit on searches, if necessary
sub _normalize_args {
    my ( $method, $args ) = @_;
    my @args;
    my $limit_found = 0;
    foreach my $arg (@$args) {
        $arg = '' if 'null' eq $arg;
        push @args, $arg;
        $limit_found++ if 'limit' eq $arg;
    }
    if ( !$limit_found && 'search' eq $method->name ) {

        # we push 'STRING', '' for a string search if we have no arguments
        # because $object->search will fail with a limit as the first argument
        # as Kinetic::Store::DB::search will assume the first argument is CODE
        # search unless it's a defined search type name.
        push @args, 'STRING', '' unless @args;
        push @args, 'limit', DEFAULT_LIMIT;
    }
    return \@args;
}

sub _not_implemented {
    my $self = shift;
    my $rest = $self->rest;
    my $info = $rest->path_info;
    $rest->status(NOT_IMPLEMENTED_STATUS)
      ->response("No resource available to handle ($info)");
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

    my ( $limit, $offset );
    my $args = $self->args;

    # 0 == @$args % 2 must always be true
    my %args = @$args;
    $limit  = $args{limit};
    $offset = $args{offset};

    my $rest         = $self->rest;
    my $response     = _xml_header( $rest, 'Available instances' );
    my $base_url     = _rest_base_url($rest);
    my $query_string = _query_string($rest);

    my $instance_count = 0;
    my $key            = $self->class_key;
    while ( my $resource = $iterator->next ) {
        $instance_count++;
        my $uuid = $resource->uuid;
        $response .=
qq'<kinetic:resource id="$uuid" xlink:href="$base_url$key/lookup/uuid/$uuid$query_string"/>';
    }
    unless ($instance_count) {
        $response .=
          '       <kinetic:resource id="No resources found" xlink:href="#"/>';
    }
    if ($instance_count) {
        my $pageset = $self->_pageset(
            {
                count  => $instance_count,
                limit  => $limit,
                offset => $offset,
            }
        );
        if ($pageset) {
            my @args = $self->get_args;

            my $url = "$base_url$key/search/";
            $url .= join '/', map { '' eq $_ ? 'null' : $_ } @args;
            $url =~ s{offset/\d+}{offset/\%d};
            $url .= $query_string;

            $response .= '<kinetic:pages>';
            foreach my $set ( $pageset->first_page .. $pageset->last_page ) {

                if ($set == $pageset->current_page) {
                    $response .= qq'<kinetic:page id="[ Page $set ]" xlink:href="@{[CURRENT_PAGE]}" />\n';
                }
                else {
                    my $offset = ( $set - 1 ) * $limit;
                    my $link_url = sprintf $url, $offset;
                    $response .= qq'<kinetic:page id="[ Page $set ]" '
                    . qq'xlink:href="$link_url" />\n';
                }
            }
            $response .= "</kinetic:pages>";
        }
    }
    $response .= "</kinetic:resources>";
    return $rest->set_response($response);
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

  my $rest_url_format = _rest_base_url($rest);

Takes a L<Kinetic::Interface::REST|Kinetic::Interface::REST> instance as an
argument.  Returns a URL suitable for embedding in XML or XHTML hrefs.
Format is the in the form of C<$url%s$query_string>.  This allows setting
additional REST path info items.

=cut

sub _rest_base_url {
    my $rest = shift;
    return join '' => map $rest->$_ => qw/domain path/;
}

##############################################################################

=head3 _xml_header

  my $response = _xml_header($rest, $title);

Given a rest instance title, this method returns an XML header for REST
responses.

=cut

sub _xml_header {
    my ( $rest, $title ) = @_;
    my $stylesheet = $rest->stylesheet_url('REST');
    return <<"    END_HEADER";
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="$stylesheet"?>
<kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                   xmlns:xlink="http://www.w3.org/1999/xlink">
<kinetic:description>$title</kinetic:description>
    END_HEADER
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
