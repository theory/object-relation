package Kinetic::UI::Catalyst::C::View;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use warnings;
use base 'Catalyst::Controller';

use Kinetic::Util::Constants qw/$UUID_RE/;
use Kinetic::Meta;

use version;
our $VERSION = version->new('0.0.2');

=head1 Name

Kinetic::UI::Catalyst::C::View - Catalyst Controller

=head1 Synopsis

See L<Kinetic::UI::Catalyst>

=head1 Description

Catalyst Controller.

=head1 Methods

=cut

=head2 view

Displays a given Kinetic object

=cut

sub view : Regex('^view/([[:alpha:]]\w*)/(.*)$') {
    my ( $self, $c ) = @_;

    my $key  = $c->request->snippets->[0];
    my $uuid = $c->request->snippets->[1];
    my $class = Kinetic::Meta->for_key($key);
    my $object = $class->package->new->lookup( uuid => $uuid );

    my @attributes;
    foreach my $attr ( $class->attributes ) {
        #next if $attr->acts_as || $attr->references;
        push @attributes => $attr->name;
    }

    $c->stash->{template}   = 'view.tt';
    $c->stash->{class}      = $class;
    $c->stash->{key}        = $key;
    $c->stash->{mode}       = 'view';
    $c->stash->{object}     = $object;
    $c->forward('Kinetic::UI::Catalyst::V::TT');
}

1;
__END__

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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
