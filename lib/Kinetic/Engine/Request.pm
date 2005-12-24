package Kinetic::Engine::Request;

# $Id: Request.pm 2414 2005-12-22 07:21:05Z theory $

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
use Kinetic::Engine;
use Kinetic::Util::Exceptions qw(throw_fatal);
use Class::BuildMethods qw/engine/;

use version;
our $VERSION = version->new('0.0.1');

##############################################################################

=head3 new

  my $req = Kinetic::Engine::Request->new;

XXX ...

=cut

{
    my %factory_for = (
        'Apache2::Request' => 'Kinetic::Engine::Request::Apache2',
        'Apache::Request'  => 'Kinetic::Engine::Request::Apache',
        'CGI'              => 'Kinetic::Engine::Request::CGI',
        'CLI'              => 'Kinetic::Engine::Request::CLI',
    );

    sub new {
        my $class   = shift;
        my $engine  = Kinetic::Engine->new;
        my $factory = $factory_for{ $engine->type }
          or throw_fatal [ 'Unknown Kinetic::Engine type "[_1]"',
            $engine->type ];
        eval "use $factory";
        if ( my $error = $@ ) {
            throw_fatal [ 'I could not load the class "[_1]": [_2]', $factory,
                $error ];
        }
        my $self = $factory->new;
        $self->engine($engine);
        return $self;
    }
}

##############################################################################

=head3 param

  # similar to CGI.pm

  my $value  = $req->param('foo');
  my @values = $req->param('foo');
  my @params = $req->param;

  # the following differ slightly from CGI.pm

  # assigns multiple values to 'foo'
  $req->param('foo' => [qw(one two three)]);

=cut

sub param {
    throw_fatal [ '"[_1]" must be overridden in a subclass', 'param' ];
}

##############################################################################

=head3 engine

  my $engine = $req->engine;

Returns the current Kinetic::Engine object.

=cut

##############################################################################

=head3 handler

  my $handler = $req->handler;

Returns the handler object such as C<Apache::Request> or C<CGI>.  This should
only be used if you need fine-grained control over the request object.

=cut

sub handler { shift->engine->handler }

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

