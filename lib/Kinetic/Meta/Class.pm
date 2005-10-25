package Kinetic::Meta::Class;

# $Id$

use strict;
use base 'Class::Meta::Class';
use Kinetic::Util::Context;
use Kinetic::Util::Exceptions qw/throw_fatal/;
use List::Util qw(first);

=head1 Name

Kinetic::Meta::Class - Kinetic class metadata class.

=head1 Synopsis

  my $class = MyThingy->my_class;
  my $thingy = MyThingy->new;

  print "Examining object of ", ($class->abstract ? "abstract " : ''),
    "class ", $class->package, $/;

  print "\nConstructors:\n";
  for my $ctor ($class->constructors) {
      print "  o ", $ctor->name, $/;
  }

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, " => ", $attr->get($thingy) $/;
  }

  print "\nMethods:\n";
  for my $meth ($class->methods) {
      print "  o ", $meth->name, $/;
  }

=head1 Description

This class inherits from L<Class::Meta::Class|Class::Meta::Class> to provide
class metadata for Kinetic classes. See the L<Class::Meta|Class::Meta>
documentation for details on meta classes. See the L<"Accessor Methods"> for
the additional attributes.

=cut

=for private

The C<import()> method is merely a placeholder to ensure that
L<Kinetic::Meta|Kinetic::Meta> can dispatch its import symbols to a variety
of classes and "just work".  This class is specifically documented as accepting
those symbols.  See the documentation for L<Kinetic::Meta|Kinetic::Meta> for
more information.

=cut

sub import {
    my ( $pkg, $symbol ) = @_;
    return unless $symbol;

    # currently a no-op
    return if ( ':with_dbstore_api' eq $symbol );
    throw_fatal [ 'Unknown import symbol "[_1]"', shift ];
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 name

  my $name = $class->name;

Returns the localized form of the name of the class, such as "Thingy".

=cut

sub name {
    Kinetic::Util::Context->language->maketext( shift->SUPER::name );
}

##############################################################################

=head3 plural_name

  my $plural_name = $class->plural_name;

Returns the localized plural form of the name of the class, such as
"Thingies".

=cut

sub plural_name {
    Kinetic::Util::Context->language->maketext( shift->{plural_name} );
}

##############################################################################

=head3 sort_by

  my $sort_by  = $class->sort_by;
  my @sort_bys = $class->sort_by;

Returns the nam of the attribute to use when sorting a list of objects of this
class. If more than one attribute has been specified for sorting, they can all
be retreived by calling C<sort_by()> in an array context.

=cut

sub sort_by {
    my $self = shift;
    return wantarray ? @{ $self->{sort_by} } : $self->{sort_by}[0];
}

##############################################################################

=head2 Instance Methods

=head3 ref_attributes

  my @ref_attrs = $class->ref_attributes;

Returns a list of attributes that reference other Kinetic::Meta objects.
Equivalent to

  my @ref_attrs = grep { $_->references } $self->attributes;

only more efficient, thanks to build-time caching.

=cut

sub ref_attributes { @{ shift->{ref_attrs} } }

##############################################################################

=head3 direct_attributes

  my @direct_attrs = $class->direct_attributes;

Returns a list of attributes that do not reference other Kinetic::Meta objects.
Equivalent to

  my @direct_attrs = grep { ! $_->references } $self->attributes;

only more efficient, thanks to build-time caching.

=cut

sub direct_attributes { @{ shift->{direct_attrs} } }

##############################################################################

=head3 build

This private method overrides the parent C<build()> method in order to cache
the a list of thereferenced attributes for use by C<ref_attributes()>.

=cut

sub build {
    my $self = shift->SUPER::build(@_);
    $self->{ref_attrs}    = [ grep { $_->references } $self->attributes ];
    $self->{direct_attrs} = [ grep { !$_->references } $self->attributes ];
    if (my $sort_by = $self->{sort_by}) {
        $sort_by = [$sort_by] unless ref $sort_by;
        my %attrs = map { $_->name => undef } @{ $self->{direct_attrs} };
        for my $attr ( @{ $sort_by } ) {
            throw_fatal [ 'No direct attribute "[_1]" to sort by', $attr ]
                unless exists $attrs{$attr};
        }
        $self->{sort_by} = $sort_by;
    } else {
        $self->{sort_by} = [
            first { $_ ne 'uuid' && $_ ne 'state' }
            map   { $_->name }
            @{ $self->{direct_attrs} }
        ];
    }
    return $self;
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
