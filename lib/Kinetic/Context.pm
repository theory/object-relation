package Kinetic::Context;

# $Id$

use strict;
use Kinetic::Meta;
use Kinetic::Config qw(:api);
use Kinetic::Cache;
use Kinetic::Language;

=head1 Name

Kinetic::Context - Kinetic utility object context

=head1 Synopsis

  use Kinetic::Context;

  # Use class methods.
  my $user = Kinetic::Context->current_user;
  my $lang = Kinetic::Context->language;
  my $cache = Kinetic::Context->cache;

  # Use the singleton object.
  my $cx = $cx->new;
  $user = $cx->current_user;
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
    current_user => undef, # XXX TBD.
    language     => Kinetic::Language->get_handle,
    cache        => undef, # XXX TBD.
}, __PACKAGE__;

##############################################################################
# Instance Methods.
##############################################################################

=head1 Class Interface

=head2 Constructor

=head3 new

  my $cx = Kinetic::Context->new;

Returns a singleton object that can provide a handy shortcut for accessing
the class methods.

=cut

sub new { $cx }

=head2 Accessor Methods

=head3 language

  my $language = $cx->language;

Returns the L<Kinetic::Language|Kinetic::Language> object to
be used for all localization. The language object will be appropriate to the
user logged in.

=cut

sub language {
    shift;
    return $cx->{language} unless @_;
    UNIVERSAL::isa($_[0], 'Kinetic::Language')
      or throw_invalid(['Value "[_1]" is not a [_2] object', $_[0],
                        'Kinetic::Language']);
    return $cx->{language} = shift;
}

##############################################################################

=head3 cache

  my $cache = $cx->cache;

Returns the L<Kinetic::Cache|Kinetic::Cache> object to
be used for all non-object caching.

=cut

sub cache {
    shift;
    return $cx->{cache} unless @_;
    UNIVERSAL::isa($_[0], 'Kinetic::Cache')
      or throw_invalid(['Value "[_1]" is not a [_2] object', $_[0],
                        'Kinetic::Cache']);
    return $cx->{cache} = shift;
}

##############################################################################

=head3 current_user

  my $current_user = $cx->current_user;

Returns the
L<Kinetic::Party::Person::User|Kinetic::Party::Person::User>
object to be used for all authorization. This object will be considered the
currently logged in user, and must be set before much can be done with
Kinetic.

=cut

sub current_user {
    shift;
    return $cx->{current_user} unless @_;
    UNIVERSAL::isa($_[0], 'Kinetic::Party::Person::User')
      or throw_invalid(['Value "[_1]" is not a [_2] object', $_[0],
                        'Kinetic::Party::Person::User']);
    return $cx->{current_user} = shift;
}

##############################################################################

if (AFFORDANCE_ACCESSORS) {
    *get_language     = \&language;
    *set_language     = \&language;
    *get_cache        = \&cache;
    *set_cache        = \&cache;
    *get_current_user = \&current_user;
    *set_current_user = \&current_user;
}

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Language|Kinetic::Language>

The Kinetic localization class.

=item L<Kinetic::Cache|Kinetic::Cache>

The Kinetic caching class.

=item L<Kinetic::Party::Person::User|Kinetic::Party::Person::User>

The Kinetic user class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. See
L<Kinetic::License|Kinetic::License> for complete license terms and
conditions.

=cut
