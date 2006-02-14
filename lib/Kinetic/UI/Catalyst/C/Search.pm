package Kinetic::UI::Catalyst::C::Search;

# $Id: Catalyst.pm 2582 2006-02-07 02:27:45Z theory $

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

# XXX the following is a temporary cheat, approved by David.  We need the
# Dispatch class's ability to handle arbitrary method calls.  Rather than
# break this into a separate class, we're assuming that Catalyst will
# eventually rely on REST calls and we won't be using a traditional interface.
use aliased 'Kinetic::UI::REST::Dispatch';
use URI::Escape qw/uri_unescape/;

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::UI::Catalyst::C::Search - Catalyst Controller

=head1 Synopsis

See L<Kinetic::UI::Catalyst>

=head1 Description

Catalyst Controller.

=head1 Methods

=head2 search

  $c->forward('Kinetic::UI::Catalyst::C::Search', 'search');

For a URL in the form C</search/$class_key>, this method will set the search
template and class key.

=cut

sub search : Regex( '^search/([[:alpha:]]\w*)(?:/(squery|slookup)(?:/(.*))?)?$') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'search.tt';
    my $key = $c->request->snippets->[0];
    my @results;
    if ( my $method = $c->request->snippets->[1] ) {
        my @args;
        if ( defined( my $args = $c->request->snippets->[2] ) ) {
            @args = map { uri_unescape($_) } split /\/_?/ => $args;
            if ( '_' eq substr $args, 0, 1 ) {

                # we've begun with a constraint so we need an empty search
                # string
                unshift @args, '';
            }
        }
        my $dispatch = Dispatch->new;    # XXX see the comment at the top
        $dispatch->class_key($key);
        my @attributes;
        my $count = 0;
        foreach my $attr ( $dispatch->class->attributes ) {
            next if $attr->acts_as || $attr->references;
            push @attributes => $attr->name unless 'uuid' eq $attr->name;
            last if $count++ > 3;
        }
        $c->stash->{attributes} = \@attributes;
        $c->stash->{iterator}   = $dispatch->_execute_method( $method, @args );
    }
    $c->stash->{key} = $key;

    $c->stash->{path} = '/';    # XXX just for now ...
    if ( my $class = Kinetic::Meta->for_key($key) ) {
        $c->stash->{class} = $class;
    }
    $c->stash->{mode} = 'search';
    $c->stash->{debug} = [ $c->request->snippets, \@results ];
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
