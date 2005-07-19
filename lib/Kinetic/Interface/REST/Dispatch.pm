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

use aliased 'XML::LibXML';
use aliased 'XML::LibXSLT';

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

=head3 echo

  Kinetic::Interface::REST::Dispatch->echo($rest);

This is a debugging resource.  It always sets the REST content type to
C<text/plain>.  Path info (after the echo request) is set in the response
with individual patch components joined with dots.

If parameters are supplied (via query strings or POST), they will be appended
the response as name/value pairs, sorted on name, but using dots as separators.

Examples:

  http://someserver/rest/echo/foo/bar/
  Response: foo.bar

  http://someserver/rest/echo/foo/bar/?this=that;a=b
  Response: foo.bar.a.b.this.that

=cut

sub _path_sub {
    my $rest = shift;
    my @path = grep /\S/ => split /\// => $rest->resource_path;
    shift @path; # get rid of resource
    return \@path;
}

sub echo {
    my ($rest) = @_;
    my $cgi = $rest->cgi;
    my $path = _path_sub($rest);
    my $response = join '.' => @$path;
    foreach my $param (sort $cgi->param) {
        $response .= ".$param.@{[$cgi->param($param)]}";
    }
    $rest->content_type(TEXT_CT)
         ->response($response);
}

sub _query_string {
    my $rest = shift;
    my $type = lc $rest->cgi->param('type') || return '';
    return '' if 'xml' eq $type; # because this is the default
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
    if (my $stylesheet = $rest->cgi->param('stylesheet')) {
        my $xml = $rest->stylesheet;
        $rest->content_type(XML_CT)
             ->response($xml);
        return;
    }
    my $response = _xml_header($rest, 'Available resources');

    my $rest_url_format = _rest_url_format($rest);
    foreach my $key (sort Kinetic::Meta->keys) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $response .= sprintf <<END_RESPONSE => $key,  $key;
      <kinetic:resource id="%s" xlink:href="$rest_url_format"/>
END_RESPONSE
    }
    $response .= "</kinetic:resources>";
    $rest->content_type(XML_CT)
         ->response($response);
}

##############################################################################

=head3 _resource_list

  Kinetic::Interface::REST::Dispatch::_resource_list($rest);

This function takes a L<Kinetic::Interface::REST|Kinetic::Interface::REST>
instance and an iterator.  It sets the rest instance's content-type to C<text/xml>
and its response to an XML list of all resources in the iterator, keyed by
guid.

=cut

my $STORE = Kinetic::Store->new;
sub _resource_list {
    my ($rest, $iterator) = @_;

    my $response = _xml_header($rest, 'Available instances');

    my $rest_url_format = _rest_url_format($rest);
    my $num_resources = 0;
    while (my $resource = $iterator->next) {
        $num_resources++;
        $response .= sprintf <<END_RESPONSE => $resource->guid,  $resource->guid;
      <kinetic:resource id="%s" xlink:href="$rest_url_format"/>
END_RESPONSE
    }
    unless ($num_resources) {
        $response .= '       <kinetic:resource id="No resources found" xlink:href=""/>';
    }
    $response .= "</kinetic:resources>";
    $rest->content_type(XML_CT)
         ->response($response);
}

##############################################################################

=head3 _rest_url_format

  my $rest_url_format = _rest_url_format($rest);

Takes a L<Kinetic::Interface::REST|Kinetic::Interface::REST> instance as an
argument.  Returns a URL suitable for embedding in XML or XHTML hrefs.
Format is the in the form of C<$url%s$query_string>.  This allows setting
additional REST path info items.

=cut

sub _rest_url_format {
    my $rest = shift;
    my $query_string = _query_string($rest);
    my $rest_url_format = join '' => map $rest->$_ => qw/domain path resource_path/;
    $rest_url_format   .= "%s$query_string";
    return $rest_url_format;
}

##############################################################################

=head3 _xml_header

  my $response = _xml_header($rest, $title);

Given a rest instance title, this method returns an XML header for REST
responses.

=cut

sub _xml_header {
    my ($rest, $title) = @_;
    my $stylesheet = $rest->stylesheet_url('browse');
    return <<"    END_HEADER";
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="$stylesheet"?>
<kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                   xmlns:xlink="http://www.w3.org/1999/xlink">
<kinetic:description>$title</kinetic:description>
    END_HEADER
}

##############################################################################

=head3 can

  if (my $sub = Kinetic::Interface::REST::Dispatch->can($resource)) {
    $sub->($rest);
  }

Yup, we've overridden C<can>.  Resources are loaded on demand.  This method
will return a subroutine representing the requested resource.  The subroutine
should be called directly with the
L<Kinetic::Interface::REST|Kinetic::Interface::REST> instance as an argument.  It
is B<not> a method because REST is stateless and calling methods does not make
any sense.

Returns false if the requested resource is not found.

Functions built on the fly to request a resource are added to the 
C<Kinetic::Interface::REST::Dispatch::_> package to minimize conflicts
with functions in this class.

=cut

sub can {
    my ($class, $resource) = @_;
    return unless $resource;
    # if for some stupid reason a resource begins with an underscore, don't
    # check to see if it's in this package
    if (
        $resource !~ /^_/ 
            && 
        'can' ne $resource # we don't want this sub called for resource named 'can'
            && 
        (my $method = $class->SUPER::can($resource))
    ) {
        return $method;
    }
    my $dispatch_package = __PACKAGE__.'::_';
    if (my $method = $dispatch_package->SUPER::can($resource)) {
        return $method;
    }
    my $kinetic_class = Kinetic::Meta->for_key($resource) or return;
    my $method = sub {
        my ($rest) = @_;
        my $path = _path_sub($rest);
        my $iterator = Kinetic::Store->new->search(Kinetic::Meta->for_key($resource));
        unless (@$path) {
            _resource_list($rest, $iterator);
        }
        if (1 == @$path && $path->[0] =~ GUID_RE) {
            my $instance = Kinetic::Store->new->lookup(
                $kinetic_class,
                guid => $path->[0]
            );
            if ($instance) {
                my $url = $rest->stylesheet_url('instance');
                my $xml = Kinetic::XML->new({
                    stylesheet_url => $url,
                    object         => $instance
                });
                $rest->content_type(XML_CT)
                     ->response($xml->dump_xml);
                return;
            }
        }
    };
    package Kinetic::Interface::REST::Dispatch::_;
    no strict 'refs';
    *$resource = $method;
    return $method;
}

sub _transform {
    my ($xml, $rest) = @_;

    my $parser    = LibXML->new;
    my $xslt      = LibXSLT->new;
    my $doc       = $parser->parse_string($xml);
    my $style_doc = $parser->parse_string($rest->stylesheet);
    my $sheet     = $xslt->parse_stylesheet($style_doc);
    my $html      = $sheet->transform($doc);
    return $sheet->output_string($html);
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
