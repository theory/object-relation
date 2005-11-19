package Kinetic::UI::REST;

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
our $VERSION = version->new('0.0.1');

use Kinetic::Util::Constants qw/:http :rest/;
use Kinetic::Util::Exceptions qw/throw_required/;
use aliased 'Kinetic::View::XSLT';
use aliased 'Kinetic::UI::REST::XML';

use aliased 'Array::AsHash';
use URI::Escape qw/uri_unescape/;

=head1 Name

Kinetic::UI::REST - REST services provider

=head1 Synopsis

 use Kinetic::UI::REST;

 sub handle_request
    # pre-processing code
    my $response = Kinetic::UI::REST->handle_request($cgi_object);
    # post-processing code
  }

=head1 Description

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $rest = Kinetic::UI::REST->new(
    domain => $domain,
    path   => $path,
  );

The C<new()> constructor returns a C<Kinetic::UI::REST> instance.  Note that
this is an object that can interpret REST (REpresentational State Transfer).
It is B<not> a server.

The C<domain> and C<path> arguments are required.  They are used internally
when building XML and examining path info.

=cut

sub new {
    my $class = shift;
    my %args  = _validate_args(@_);
    bless {
        cgi          => undef,
        response     => '',
        content_type => '',
        domain       => $args{domain},
        path         => $args{path},
        xslt         => 'search',
    } => $class;
}

sub _validate_args {
    my %arg_for = @_;
    my @errors;
    push @errors => 'domain' unless exists $arg_for{domain};
    push @errors => 'path'   unless exists $arg_for{path};
    if (@errors) {
        my $errors = join ' and ' => @errors;
        throw_required [
            'Required argument "[_1]" to [_2] not found',
            $errors, __PACKAGE__ . "::new"
        ];
    }
    $arg_for{domain} .= '/' unless $arg_for{domain} =~ /\/$/;
    $arg_for{path} .= '/'   unless $arg_for{path}   =~ /\/$/;
    $arg_for{path} =~ s/^\///;

    return %arg_for;
}

##############################################################################
# Class Methods
##############################################################################

=head2 Class Methods

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Public methods

##############################################################################

=head3 handle_request

  $rest->handle_request($cgi_object);

This is the main REST method.  It expects an object that adheres to the
L<CGI|CGI> interface.

=cut

sub handle_request {
    my ( $self, $cgi ) = @_;
    $self->cgi($cgi)->status('')->response('')->content_type('');
    $self->desired_content_type($XML_CT);
    if ( my $type = $cgi->param($TYPE_PARAM) ) {
        my $desired_content_type =
          'html'   eq lc $type ? $HTML_CT
          : 'text' eq lc $type ? $TEXT_CT
          : $XML_CT;
        $self->desired_content_type($desired_content_type);
    }

    my ( $class_key, $method, @args ) = $self->_get_request;
    $_ = uri_unescape($_) foreach @args;

    # the following variables should be case-insensitive
    $_ = lc foreach $class_key, $method;

    my $dispatch = XML->new( { rest => $self } );
    eval {
        if ($class_key)
        {
            $dispatch->class_key($class_key)->method($method)
              ->args( AsHash->new( { array => \@args } ) )->handle_rest_request;
        }
        else {
            $self->xslt('resources');
            $dispatch->class_list;
        }
    };
    if ( my $error = $@ ) {
        my $info = $cgi->path_info;
        $self->status($HTTP_INTERNAL_SERVER_ERROR)
          ->response("Fatal error handling $info: $error");
    }
    $self->status($HTTP_OK) unless $self->status;
    return $self;
}

##############################################################################

=head3 output_type

  my $output_type = $rest->output_type;

Returns the output type the client has requested. The client requests a given
output type in the query string via the "_type=$type" parameter.

=cut

sub output_type {
    my $self = shift;
    my $output_type = lc $self->cgi->param($TYPE_PARAM) || '';
}

##############################################################################

=head3 base_url

  my $base_url = $rest->base_url;

Returns the base url for the REST server.

=cut

sub base_url {
    my $self = shift;
    return join '' => $self->domain, $self->path;
}

##############################################################################

=head3 query_string

  my $query_string = $rest->query_string;

At the present time, only returns the portion of the REST query string
specifiying the content type.

=cut

sub query_string {
    my $self = shift;
    my $type = lc $self->output_type || return '';
    return '' if 'xml' eq $type;    # because this is the default
    return "?" . $TYPE_PARAM . "=$type";
}

sub _get_request {
    my $self = shift;

    my @request = $self->_get_request_from_path_info;

    # naive.  We may have more than one "basic" parameters in
    # the future (currently it's $TYPE_PARAM)
    if ( !@request || ( $self->cgi->param || 0 ) > 1 ) {
        @request = $self->_get_request_from_query_string;
    }
    return @request;
}

sub _get_request_from_path_info {
    my $self      = shift;
    my $cgi       = $self->cgi;
    my @request   = grep { /\S/ } split '/' => $cgi->path_info;
    my @base_path = split '/' => $self->path;

    # remove base path from request, if it's there
    for my $component (@base_path) {
        no warnings 'uninitialized';
        if ( $component eq $request[0] ) {
            shift @request;
        }
        else {
            last;
        }
    }
    $_ = uri_unescape($_) foreach @request;
    return @request;
}

sub _get_request_from_query_string {
    my $self = shift;
    my $cgi  = $self->cgi;

    my $class_key = $cgi->param($CLASS_KEY_PARAM);
    my $method    = 'query';

    my @args;
    foreach my $param ( $cgi->param ) {
        my $value = $cgi->param($param);
        if ( 'query' eq $param ) {
            $param = 'STRING';
            if ( !defined $value || '' eq $value ) {
                $value = 'null';
            }
        }
        next unless defined $value && '' ne $value;
        push @args, $param, $value;
    }
    return ( $class_key, $method, @args );
}

##############################################################################

=head3 status

  my $status = $rest->status;

If the call to C<handle_request> succeeded, this method should return a status
suitable for use in an HTTP header.

=cut

sub status {
    my $self = shift;
    return $self->{status} unless @_;
    $self->{status} = shift;
    return $self;
}

##############################################################################

=head3 xslt

  my $xslt = $rest->xslt;

If the call to C<handle_request()> succeeded, this method should return the
type of XSLT suitable for transforming the XML.

Available XSLT types are listed in L<Kinetic::View::XSLT|Kinetic::View::XSLT>.

=cut

sub xslt {
    my $self = shift;
    return $self->{xslt} unless @_;
    $self->{xslt} = shift;
    return $self;
}

##############################################################################

=head3 response

  my $response = $rest->response;

If the call to C<handle_request()> succeeded, this method will return the
response.

=cut

sub response {
    my $self = shift;
    return $self->{response} unless @_;
    $self->{response} = shift;
    return $self;
}

##############################################################################

=head3 desired_content_type

  my $desired_content_type = $rest->desired_content_type;

If the call to C<handle_request()> succeeded, this method will return the
content-type expected by the client.

=cut

sub desired_content_type {
    my $self = shift;
    return $self->{desired_content_type} unless @_;
    $self->{desired_content_type} = shift;
    return $self;
}

##############################################################################

=head3 content_type

  my $content_type = $rest->content_type;

If the call to C<handle_request> succeeded, this method should return a
content-type suitable for use in an HTTP header.

=cut

sub content_type {
    my $self = shift;
    return $self->{content_type} unless @_;
    $self->{content_type} = shift;
    return $self;
}

##############################################################################

=head3 cgi

  my $cgi = $rest->cgi;

If the call to C<handle_request()> succeeded, this method will return the CGI
object.

In general, we wish to limit access to this as much as possible, so use
sparingly.

=cut

sub cgi {
    my $self = shift;
    return $self->{cgi} unless @_;
    $self->{cgi} = shift;
    return $self;
}

##############################################################################

=head3 domain

  my $domain = $rest->domain;

Read only. This method returns the domain that was set when the REST server
was instantiated. A trailing slash will be added, if necessary.

 my $rest = Kinetic::UI::REST->new(
    domain => 'http://someserver',
    path   => 'rest/'
 );
 print $rest->domain; # http://someserver/

=cut

sub domain { shift->{domain} }

##############################################################################

=head3 path

  my $path = $rest->path;

Read only. This method returns the path that was set when the REST server was
instantiated. Path must be relative to the url set in the constructor. Leading
forward slashes will be stripped and a trailing slash will be added, if
necessary.

 my $rest = Kinetic::UI::REST->new(
    domain => 'http://someserver/',
    path   => '/rest'
 );
 print $rest->path; # rest/

=cut

sub path { shift->{path} }

##############################################################################

=head3 path_info

  my $path_info = $rest->path_info;

Read only. This method returns the path info used when C<handle_request()> was
called.

=cut

sub path_info {
    my $self = shift;
    return unless my $cgi = $self->cgi;
    $cgi->path_info;
}

##############################################################################

=head3 resource_path

  my $resource_path = $rest->resource_path;

Read only. This method returns the path info starting at the resource (assumes
that C<< $rest->path >> should be removed from the path info).

Returns the empty string if no resource path is found.

=cut

sub resource_path {
    my $self          = shift;
    my $resource_path = $self->path_info or return '';
    my $path          = $self->path;

    $resource_path =~ s/^$path//;
    $resource_path =~ s/^\///;
    $resource_path .= '/' unless $resource_path =~ /\/$/;

    return '/' eq $resource_path ? '' : $resource_path;
}

##############################################################################

=head3 set_response

  $rest->set_response($xml, [$type]);

This method, when passed $xml and an optional response type (defaults to
'search'), will set the content-type and entity-body of the REST response.

=cut

sub set_response {
    my ( $self, $xml, $type ) = @_;
    my $content_type = $self->desired_content_type || $XML_CT;
    my $content = $xml;
    if ( $HTML_CT eq $content_type ) {
        $type ||= $self->xslt;
        my $xslt = XSLT->new( type => $type );
        $content = $xslt->transform($xml);
    }
    $self->content_type($content_type)->response($content);
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
