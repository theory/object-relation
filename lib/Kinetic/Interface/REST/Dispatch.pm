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

use 5.008003;
use strict;
use version;
use Kinetic::Meta;
use Kinetic::XML;
use Kinetic::Meta::XML;
use Kinetic::Store;
use Kinetic::Util::Constants qw/:http :data_store/;

our $VERSION = version->new('0.0.1');

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

sub _query_string {
    my $rest = shift;
    my $type = lc $rest->cgi->param('type') || return '';
    return '' if 'xml' eq $type;    # because this is the default
    return "?type=$type";
}

##############################################################################

=head3 _class_list

  Kinetic::Interface::REST::Dispatch::_class_list($rest);

This function takes a L<Kinetic::Interface::REST|Kinetic::Interface::REST>
instance and sets its content-type to C<text/xml> and its response to an XML
list of all classes registered with L<Kinetic::Meta|Kinetic::Meta>.

=cut

sub _class_list {
    my ($rest) = @_;
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

sub _handle_rest_request {
    my ( $rest, $class_key, $message, $args ) = @_;
    $args ||= [];

    my $class;
    eval { $class = Kinetic::Meta->for_key($class_key) };
    if ( !$class || !$message ) {
        return _not_implemented($rest);
    }
    if ( my $method = $class->methods($message) ) {
        if ( $method->context == Class::Meta::CLASS ) {
            my $response = $method->call( $class->package->new, @$args );
            if ( 'search' eq $message ) {
                return _instance_list( $rest, $class_key, $response );
            }
        }
        else {

            # XXX we're not actually doing anything with this yet.
            my $obj = $class->contructors('lookup')->call(@$args)
              or die;
            $method->call( $obj, @$args );
        }
    }
    elsif ( my $ctor = $class->constructors($message) ) {
        my $obj = $ctor->call( $class->package, @$args );
        my $xml = Kinetic::XML->new(
            {
                object         => $obj,
                stylesheet_url => $rest->stylesheet_url('instance'),
            }
        )->dump_xml;
        return $rest->set_response($xml, 'instance');
    }
    else {
        return _not_implemented($rest);
    }
}

sub _not_implemented {
    my $rest = shift;
    my $info = $rest->path_info;
    $rest->status(NOT_IMPLEMENTED_STATUS)
      ->response("No resource available to handle ($info)");
}

##############################################################################

=head3 _instance_list

  Kinetic::Interface::REST::Dispatch::_instance_list($rest);

This function takes a L<Kinetic::Interface::REST|Kinetic::Interface::REST>
instance and an iterator.  It sets the rest instance's content-type to
C<text/xml> and its response to an XML list of all resources in the iterator,
keyed by guid.

=cut

my $STORE = Kinetic::Store->new;

sub _instance_list {
    my ( $rest, $key, $iterator ) = @_;

    my $response     = _xml_header( $rest, 'Available instances' );
    my $base_url     = _rest_base_url($rest);
    my $query_string = _query_string($rest);

    my $num_resources = 0;
    while ( my $resource = $iterator->next ) {
        $num_resources++;
        my $guid = $resource->guid;
        $response .=
qq'<kinetic:resource id="$guid" xlink:href="$base_url$key/lookup/guid/$guid$query_string"/>'
          ,;
    }
    unless ($num_resources) {
        $response .=
          '       <kinetic:resource id="No resources found" xlink:href="#"/>';
    }
    $response .= "</kinetic:resources>";
    return $rest->set_response($response);
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
