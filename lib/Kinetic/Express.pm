package Kinetic::Express;

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

our $VERSION = version->new('0.0.2');

use base 'Class::Meta::Express';
use Kinetic::Meta;

sub meta {
    splice @_, 1, 4, meta_class => 'Kinetic::Meta', default_type => 'string';
    goto &Class::Meta::Express::meta;
}

1;

=head1 Name

Kinetic::Express - Fast and Easy Kinetic class creation

=head1 Synopsis

  package MyApp::Thingy;
  use Kinetic::Express;
  BEGIN {
      meta 'thingy';
      has  'provenence';
      build;
  }

=head1 Description

This package makes it dead simple to create Kinetic classes. It overrides the
funcions in L<Class::Meta::Express|Class::Meta::Express> so that the class is
always built by L<Kinetic::Meta|Kinetic::Meta> and so that attributes are
strings by default. Of course, these settings can be overriddent by using the
explicitly passing the C<meta_class> and and C<default_type> parameters to
C<meta()>:

  package MyApp::SomethingElse;
  use Kinetic::Express;
  BEGIN {
      meta else => (
          meta_class   => 'My::Meta,
          default_type => 'binary',
      );
  }

Or, for attribute types, you can set them on a case-by-case basis by passing
the C<type> parameter to C<has()>:

  has image => ( type => 'binary' );

=head1 Interface

The functions exported by this module are:

=over

=item meta

Creates the L<Kinetic::Meta|Kinetic::Meta> object used to construct the class.

=item ctor

Creates a constructor for the class. Note that all classes created by
L<Kinetic::Meta|Kinetic::Meta> automatically inherit from L<Kinetic|Kinetic>,
and therefore already have a C<new()> constructor, among other methods.

=item has

Creates an attribute of the class.

=item method

Creates a method of the class.

=item build

Builds the class and removes the above functions from its namespace.

=back

=head1 See Also

=over 4

=item L<Kinetic::Meta|Kinetic::Meta>

Subclass of L<Class::Meta|Class::Meta> that defines Kinetic classes
created with Kinetic::Express.

=item L<Class::Meta::Express|Class::Meta::Express>

The module that Kinetic::Express overrides, and from which it inherits its
interface. See its documentation for a more complete explication of the
exported functions and their parameters.

=item L<Kinetic|Kinetic>

The base class from which all classes created by Kinetic::Express inherit.

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
