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
use Kinetic::Meta::XML;
our $VERSION = version->new('0.0.1');

use Kinetic::Store;

use constant TEXT => 'text/plain';
use constant XML  => 'text/xml';
use constant HTML => 'text/html';

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

my $path_sub = sub {
    my $rest = shift;
    my @path = grep /\S/ => split /\// => $rest->resource_path;
    shift @path; # get rid of resource
    return \@path;
};

sub echo {
    my ($rest) = @_;
    my $cgi = $rest->cgi;
    my $path = $path_sub->($rest);
    my $response = join '.' => @$path;
    foreach my $param (sort $cgi->param) {
        $response .= ".$param.@{[$cgi->param($param)]}";
    }
    $rest->content_type(TEXT)
         ->response($response);
}

sub _query_string {
    my $rest = shift;
    my $type = $rest->cgi->param('type') || return '';
    return "?type=$type";
}

##############################################################################

=head3 class_list

  Kinetic::Interface::REST::Dispatch::classlist($rest);

This function takes a L<Kinetic::Interface::REST|Kinetic::Interface::REST>
object and sets its content-type to C<text/xml> and its response to an XML
list of all classes registered with L<Kinetic::Meta|Kinetic::Meta>.

=cut

sub class_list {
    my ($rest) = @_;
    my $response = <<END_RESPONSE;
<?xml version="1.0"?>
<kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                 xmlns:xlink="http://www.w3.org/1999/xlink">   
END_RESPONSE
    $response .= "<kinetic:description>Available resourcees</kinetic:description>\n";
    my $url = join '' => map $rest->$_ => qw/domain path/;
    my $query_string = _query_string($rest);
    foreach my $key (sort Kinetic::Meta->keys) {
        $response .= sprintf <<END_RESPONSE => $key,  $key;
      <kinetic:resource id="%s" xlink:href="$url%s$query_string"/>
END_RESPONSE
    }
    $response .= "</kinetic:resources>";
    $rest->content_type(XML)
         ->response($response);
}

##############################################################################

=head3 can

  if (my $sub = Kinetic::Interface::REST::Dispatch->can($resource)) {
    $sub->($rest);
  }

Yup, we've overridden C<can>.  Resources are loaded on demand.  This method
will return a subroutine representing the requested resource.  The subroutine
should be called directly with the
L<Kinetic::Interface::REST|Kinetic::Interface::REST> object as an argument.  It
is B<not> a method because REST is stateless and calling methods does not make
any sense.

Returns false if the requested resource is not found.

=cut

my $STORE = Kinetic::Store->new;
use B::Deparse;
my $deparse = B::Deparse->new("-p", "-sC");
my $simple_list_sub = sub {
    my ($rest, $iterator) = @_;

    my $response = <<'    END_RESPONSE';
<?xml version="1.0"?>
<kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                   xmlns:xlink="http://www.w3.org/1999/xlink">
<kinetic:description>Available objects</kinetic:description>
    END_RESPONSE

    my $url = join '' => map $rest->$_ => qw/domain path resource_path/;
    my $query_string = _query_string($rest);
    while (my $resource = $iterator->next) {
        $response .= sprintf <<END_RESPONSE => $resource->guid,  $resource->guid;
      <kinetic:resource id="%s" xlink:href="$url%s$query_string"/>
END_RESPONSE
    }
    $response .= "</kinetic:resources>";
    $rest->content_type(XML)
         ->response($response);
};

sub can {
    my ($class, $resource) = @_;
    return unless $resource;
    if (my $method = $class->SUPER::can($resource)) {
        return $method;
    }
    my $kinetic_class = Kinetic::Meta->for_key($resource) or return;
    my $method = sub {
        my ($rest) = @_;
        my $path = $path_sub->($rest);
        my $iterator = Kinetic::Store->new->search(Kinetic::Meta->for_key('one'));
        unless (@$path) {
            $simple_list_sub->($rest, $iterator);
        }
    };
    no strict 'refs';
    *$resource = $method;
    return $method;
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
