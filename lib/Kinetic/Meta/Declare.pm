package Kinetic::Meta::Declare;

# $Id: Type.pm 2488 2006-01-04 05:17:14Z theory $

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
use aliased 'Array::AsHash';

use Kinetic::Meta;
use base 'Class::Meta::Declare';
BEGIN { Class::Meta::Declare->import(':all') }

=head1 Name

Kinetic::Meta::Declare - Declarative interface for Kinetic classes.

=head1 Synopsis

 use Kinetic::Meta::Declare ':all';
 Kinetic::Meta::Declare->new(
     meta => [
         key         => 'contact',
         plural_name => 'Contacts',
         type_of     => 'contact_type',
     ],
     attributes => [
         value => {
             widget_meta => Kinetic::Meta::Widget->new(
                 type => 'text',
                 tip  => "The description of the contact"
             )
         },
     ],
 );

=head1 Description

This subclass of C<Class::Meta::Declare> sets reasonable defaults for
C<Kinetic> objects.

=head1 Defaults

=over 4

=item * C<meta>

=over 4

=item * C<< use => 'Kinetic::Meta' >>

All classes built with C<Kinetic::Meta::Declare> automatically use
C<Kinetic::Meta> to build them.

Unlike the other defaults, this one cannot be overridden.  Do not use this
class if you need a different class to build your objects.

=item * C<< name => ucfirst $key >>

If the name of a class is not supplied, the key will be used and the first
letter will be upper-cased.  Additionally, underscores will be converted to
spaces.

=back

=item * C<attributes>

=over 4

=item * C<< type => $TYPE_STRING >>

If a type is not specified, C<$TYPE_STRING> is used.

=item * C<< label => ucfirst $attribute_name >>

The label for an attribute will be set to the attribute name with the first
character upper-cased.

=back

=item * C<methods>

No defaults are currently provided for methods.

=back

=cut

my %handler_for = (
    meta       => '_handle_meta',
    attributes => '_handle_attribute',
    methods    => '_handle_method',
);

sub import {
    goto &Class::Meta::Declare::import;
}

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

 use Kinetic::Meta::Declare ':all';
 Kinetic::Meta::Declare->new(
     meta => [
         key         => 'contact',
         plural_name => 'Contacts',
         type_of     => 'contact_type',
     ],
     attributes => [
         value => {
             widget_meta => Kinetic::Meta::Widget->new(
                 type => 'text',
                 tip  => "The description of the contact"
             )
         },
     ],
 );

The C<new> constructor takes the same arguments as C<Class::Meta::Declare>'s
constructor.  See that class for details.

Many values are optional as reasonable defaults are provided.

=head3 new


=cut

sub new {
    my ( $class, @declare ) = @_;
    my @declare_with_defaults;
    while ( my ( $section, $declaration ) = splice @declare, 0, 2 ) {
        if ( my $handle = $handler_for{$section} ) {
            $declaration = $class->$handle($declaration);
            push @declare_with_defaults => $section, $declaration;
        }
    }
    return $class->SUPER::new(@declare_with_defaults);
}

##############################################################################

=begin private

=head2 Private Class Methods

=head3 _handle_meta

  Kinetic::Meta::Declare->_handle_meta(\@meta_declaration);

Accepts the C<meta> declaration from a typical C<Class::Meta::Declare>
constructor argument and adds C<< use => 'Kinetic::Meta' >> and defaults the
C<name> to be a C<ucfirst> of the name with the underscores converted to
spaces.

Returns an array or an arrayref if it's called in list or scalar context,
respectively.

=cut

sub _handle_meta {
    my ( $class, $declaration ) = @_;
    $declaration = AsHash->new( { array => $declaration } );
    $declaration->put( use => 'Kinetic::Meta' );
    unless ( $declaration->exists('name') ) {
        my $name = $declaration->get('key');
        $name =~ s/_/ /g;
        $declaration->put( name => ucfirst $name );
    }
    return $declaration->get_array;
}

=head3 _handle_attribute 

  Kinetic::Meta::Declare->_handle_attribute(\@atttribute_declaration);

Accepts the C<attributes> declaration from a typical C<Class::Meta::Declare>
constructor argument and defaults the C<label> to be a C<ucfirst> of the
attribute name with the underscores converted to spaces.

Defaults C<type> to be C<$TYPE_STRING>.

Returns an array or an arrayref if it's called in list or scalar context,
respectively.

=cut

sub _handle_attribute {
    my ( $class, $declaration ) = @_;
    $declaration = AsHash->new( { array => $declaration } );
    while ( my ( $attribute_name, $value_for ) = $declaration->each ) {
        unless ( exists $value_for->{type} ) {
            $value_for->{type} = $TYPE_STRING;
        }
        unless ( exists $value_for->{label} ) {
            $value_for->{label} = ucfirst $attribute_name;
            $value_for->{label} =~ s/_/ /g;
        }
    }
    return $declaration->get_array;
}

=head3 _handle_method 

  Kinetic::Meta::Declare->_handle_method(\@method_declaration);

Accepts the C<methods> declaration from a typical C<Class::Meta::Declare>
constructor argument but is currently a no-op.  Included for completeness.

Returns an array or an arrayref if it's called in list or scalar context,
respectively.

=end private

=cut

sub _handle_method {
    my ( $class, $declaration ) = @_;
    $declaration = AsHash->new( { array => $declaration } );
    return $declaration->get_array;
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
