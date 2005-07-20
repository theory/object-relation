package Kinetic::Interface::REST;

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
our $VERSION = version->new('0.0.1');
use Kinetic::Util::Constants qw/:http/;
use Kinetic::Util::Exceptions qw/:all/;
use aliased 'Kinetic::View::XSLT';
use aliased 'Kinetic::Interface::REST::Dispatch';

=head1 Name

Kinetic::Interface::REST - REST services provider

=head1 Synopsis

 use Kinetic::Interface::REST;

 sub handle_request 
    # pre-processing code
    my $response = Kinetic::Interface::REST->handle_request($cgi_object);
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

  my $rest = Kinetic::Interface::REST->new(
    domain => $domain,
    path   => $path,
  );

The C<new()> constructor returns a C<Kinetic::Interface::REST> instance.  Note
that this is an object that can interpret REST (REpresentational State
Transfer).  It is B<not> a server.

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
        xslt         => XSLT->new(type => 'REST'),
    } => $class;
}

sub _validate_args {
    my %args = @_;
    my @errors;
    push @errors => 'domain' unless exists $args{domain};
    push @errors => 'path'   unless exists $args{path};
    if (@errors) {
        my $errors = join ' and ' => @errors;
        throw_required [
            'Required argument "[_1]" to [_2] not found',
            $errors,
            __PACKAGE__."::new"
        ];
    }
    $args{domain} .= '/' unless $args{domain} =~ /\/$/;
    $args{path}   .= '/' unless $args{path} =~ /\/$/;
    $args{path}    =~ s/^\///;

    return %args;
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
    my ($self, $cgi) = @_;
    $self->cgi($cgi);
    $self->status('');
    $self->response('');
    $self->content_type('');
    my ($resource, @request) = grep /\S/ => split '/' => $cgi->path_info;
    if (! $resource || (my $sub = Dispatch->can($resource))) {
        eval {
            ! $resource 
                ? Kinetic::Interface::REST::Dispatch::_class_list($self) 
                : $sub->($self)
        };
        if ($@) {
            my $info = $cgi->path_info;
            $self->status(INTERNAL_SERVER_ERROR_STATUS)
                 ->response("Fatal error handling $info: $@");
        }
        else {
            $self->status(OK_STATUS) unless $self->status;
        }
    }
    else {
        $self->status(NOT_IMPLEMENTED_STATUS)
             ->response("No resource available to handle ($resource)");
    }
    return $self;
}

##############################################################################

=head3 status

  my $status = $rest->status;

If the call to C<handle_request> succeeded, this method should return a 
status suitable for use in an http header.

=cut

sub status {
    my $self = shift;
    if (@_) {
        $self->{status} = shift;
        return $self;
    }
    $self->{status};
}

##############################################################################

=head3 response

  my $response = $rest->response;

If the call to C<handle_request> succeeded, this method will return the 
response.

=cut

sub response {
    my $self = shift;
    if (@_) {
        $self->{response} = shift;
        return $self;
    }
    $self->{response};
}

##############################################################################

=head3 content_type

  my $content_type = $rest->content_type;

If the call to C<handle_request> succeeded, this method should return a 
content-type suitable for use in an http header.

=cut

sub content_type {
    my $self = shift;
    if (@_) {
        $self->{content_type} = shift;
        return $self;
    }
    $self->{content_type};
}

##############################################################################

=head3 cgi

  my $cgi = $rest->cgi;

If the call to C<handle_request> succeeded, this method will return the 
cgi object.

In general, we wish to limit access to this as much as possible, so use
sparingly.

=cut

sub cgi {
    my $self = shift;
    if (@_) {
        $self->{cgi} = shift;
        return $self;
    }
    $self->{cgi};
}

##############################################################################

=head3 domain

  my $domain = $rest->domain;

Read only.  This method returns the domain that was set when the REST server
was instantiated.  A trailing slash will be added, if necessary.

 my $rest = Kinetic::Interface::REST->new(
    domain => 'http://someserver',
    path   => 'rest/'
 );
 print $rest->domain; # http://someserver/
=cut

sub domain { shift->{domain} }

##############################################################################

=head3 path

  my $path = $rest->path;

Read only.  This method returns the path that was set when the REST server was
instantiated.  Path must be relative to the url set in the constructor.
Leading forward slashes will be stripped and a trailing slash will be added, if
necessary.

 my $rest = Kinetic::Interface::REST->new(
    domain => 'http://someserver/',
    path   => '/rest'
 );
 print $rest->path; # rest/

=cut

sub path { shift->{path} }

##############################################################################

=head3 path_info

  my $path_info = $rest->path_info;

Read only.  This method returns the path_info used when C<&handle_request>
was called.

=cut

sub path_info { 
    my $self = shift;
    return unless my $cgi = $self->cgi;
    $cgi->path_info;
}

##############################################################################

=head3 resource_path

  my $resource_path = $rest->resource_path;

Read only.  This method returns the path info starting at the resource (assumes
that $rest->path should be removed from path_info).

Returns the empty string if no resource path is found.

=cut

sub resource_path { 
    my $self = shift;
    my $resource_path = $self->path_info;
    return '' unless $resource_path;
    my $path = $self->path;
    $resource_path  =~ s/^$path//;
    $resource_path  =~ s/^\///;
    $resource_path .= '/' unless $resource_path =~ /\/$/;
    return '/' eq $resource_path ? '' : $resource_path;
}

##############################################################################

=head3 stylesheet

  my $stylesheet = $rest->stylesheet;

Returns XSLT stylesheet for the requested resource.

=cut

sub stylesheet {
    my $self = shift;
    my $sheet = $self->cgi->param('stylesheet') || return; # XXX not implemented?
    eval {$self->xslt->type($sheet)};
    return $self->xslt->stylesheet unless $@;
}


##############################################################################

=head3 stylesheet_url

  my $url = $rest->stylesheet_url('instance');

Returns a URL which will return the requested stylesheet type.  Supported
stylesheet types are listed in L<Kinetic::View::XSLT|Kinetic::View|XSLT>.

=cut

sub stylesheet_url {
    my ($rest, $sheet) = @_;
    # XXX has side-effect of setting xslt stylesheet type.  Bad?
    eval {$rest->xslt->type($sheet)};
    unless ($@) {
        return $rest->domain.$rest->path.'?stylesheet='.$sheet;
    }
    else {
        $rest->status(NOT_IMPLEMENTED_STATUS)
             ->content_type(TEXT_CT)
             ->response("Unknown stylesheet ($sheet)");
        return;
    }
}

##############################################################################

=head3 xslt

  my $xslt = $rest->xslt;

Read only.  This method returns the L<Kinetic::View::XSLT|Kinetic::View::XSLT>
object that was set when the REST server was instantiated.

=cut

sub xslt { shift->{xslt} }

##############################################################################

=begin private

=head2 Private Instance Methods

=cut

=end private

=cut

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
