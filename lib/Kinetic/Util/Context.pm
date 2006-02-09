package Kinetic::Util::Context;

# $Id$

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

#use Kinetic::Util::Cache;
use Kinetic::Util::Language;

=head1 Name

Kinetic::Util::Context - Kinetic utility object context

=head1 Synopsis

  use Kinetic::Util::Context;

  # Use class methods.
  my $user = Kinetic::Util::Context->user;
  my $lang = Kinetic::Util::Context->language;
  my $cache = Kinetic::Util::Context->cache;

  # Use the singleton object.
  my $cx = $cx->new;
  $user = $cx->user;
  $lang = $cx->language;
  $cache = $cx->cache;

=head1 Description

This class provides access to objects that need to be universally accessed.
Specifically, it provides access to the currently logged-in user object, the
system-wide shared cache, and the curent localization object. It should be
assumed that nothing can be done with the Kinetic API without first logging
in as a user.

=cut

my $cx = bless {
    user => undef, # XXX TBD.
    language     => Kinetic::Util::Language->get_handle,
    cache        => undef, # XXX TBD.
}, __PACKAGE__;

##############################################################################
# Instance Methods.
##############################################################################

=head1 Class Interface

=head2 Constructor

=head3 new

  my $cx = Kinetic::Util::Context->new;

Returns a singleton object that can provide a handy shortcut for accessing
the class methods.

=cut

sub new { $cx }

##############################################################################

=head2 Accessor Methods

=head3 language

  my $language = $cx->language;

Returns the L<Kinetic::Util::Language|Kinetic::Util::Language> object to be used for all
localization. The language object will be appropriate to the user logged in.

=cut

sub language {
    shift;
    return $cx->{language} unless @_;
    UNIVERSAL::isa($_[0], 'Kinetic::Util::Language')
      or throw_invalid(['Value "[_1]" is not a valid [_2] object', $_[0],
                        'Kinetic::Util::Language']);
    return $cx->{language} = shift;
}

##############################################################################

=head3 cache

  my $cache = $cx->cache;

Returns the L<Kinetic::Util::Cache|Kinetic::Util::Cache> object to be used for all
non-object caching.

=cut

sub cache {
    shift;
    return $cx->{cache} unless @_;
    UNIVERSAL::isa($_[0], 'Kinetic::Util::Cache')
      or throw_invalid(['Value "[_1]" is not a valid [_2] object', $_[0],
                        'Kinetic::Util::Cache']);
    return $cx->{cache} = shift;
}

##############################################################################

=head3 user

  my $user = $cx->user;

Returns the L<Kinetic::Party::Person::User|Kinetic::Party::Person::User>
object to be used for all authorization. This object will be considered the
currently logged in user, and must be set before much can be done with
Kinetic.

=cut

sub user {
    shift;
    return $cx->{user} unless @_;
    UNIVERSAL::isa($_[0], 'Kinetic::Party::Person::User')
      or throw_invalid(['Value "[_1]" is not a valid [_2] object', $_[0],
                        'Kinetic::Party::Person::User']);
    return $cx->{user} = shift;
}

1;
__END__

##############################################################################

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
