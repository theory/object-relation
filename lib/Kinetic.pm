package Kinetic;

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

use 5.008003;
use strict;
use version;
use encoding 'utf8';
use Kinetic::Meta;
use Kinetic::Meta::Widget;
use Kinetic::Store;
use Kinetic::Util::State qw(:all);
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

our $VERSION = version->new('0.0.1');

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

Kinetic - The Kinetic enterprise application framework

=end comment

=head1 Name

Kinetic - The Kinetic enterprise application framework

=head1 Synopsis

  package MyApp::Thingy;
  use base qw(Kinetic);
  BEGIN {
      my $km = Kinetic::Meta->new(
          key         => 'thingy',
          name        => 'Thingy',
          plural_name => 'Thingies',
      );
      $km->add_attribute(
        name => 'provenence',
        type => 'string',
      );
      $km->build;
  }

=head1 Description

Kinetic is an enterprise application framework. It pulls together the
Class::Meta, Widget::Meta, and other modules to offer a platform for the rapid
development of enterprise applications in Perl.

This class serves as the base class for all Kinetic classes. It defines the
interface for all data access, and provides convenience methods to all of the
data store access methods required by the subclasses.

=cut

BEGIN {
    my $cm = Kinetic::Meta->new(
        key         => 'kinetic',
        name        => 'Kinetic',
        plural_name => 'Kinetics', # Oof.
        trust       => 'Kinetic::Store',
        abstract    => 1,
    );
    Kinetic::Store->_add_store_meta($cm);

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $kinetic = Kinetic->new;
  $kinetic = Kinetic->new(%init);

The universal Kinetic object constructor. It takes a list of parameters as its
arguments, constructs a new Kinetic object with its attributes set to the
values relevant to those parameters, and returns the new Kinetic object.

The C<new()> constructor is guaranteed to always be callable without
parameters. This makes it easy to create new Kinetic objects with their
parameters set to default values.

=cut

    # Create the new() constructor.
    $cm->add_constructor( name => 'new',
                          create  => 1 );

##############################################################################
# Class Methods
##############################################################################

=head2 Class Methods

=head3 my_class

  my $class = Kinetic->my_class;

Returns the Kinetic::Meta::Class object that describes this class. See
L<Class::Meta|Class::Meta> for more information.

=head3 my_key

  my $key = Kinetic->my_key;

Returns the key that uniquely identifies this class. The class key is used in
the Kinetic UI, and by the SOAP server. Equivalent to
C<< Kinetic->my_class->key >>.

=cut

    sub my_key { shift->my_class->key }

##############################################################################

=head3 lookup

  my $kinetic = Some::Kinetic::Object->lookup(uuid => $uuid);

Calling this method looks up a Kinetic object in the data store.  See the
C<lookup> method in L<Kinetic::Store|Kinetic::Store> for more information.

=cut

    sub lookup { 
        my $class = shift;
        Kinetic::Store->lookup($class->my_class, @_);
    }
    $cm->add_constructor(
        name   => 'lookup',
        create => 0,
    );

##############################################################################

=head3 search

  my $iterator = Some::Kinetic::Object->search(name => LIKE '%vid');

Calling this method searches the data store for objects meeting the search
criteria.  See the C<search> method in L<Kinetic::Store|Kinetic::Store> for
more information.

=cut

    sub search {
        my $class = shift;
        Kinetic::Store->search($class->my_class, @_);
    }
    $cm->add_method(
        name    => 'search',
        context => Class::Meta::CLASS,
    );

##############################################################################

=head3 count

  my $count = Some::Kinetic::Object->count(name => LIKE '%vid');

This method returns a count of the objects in the data store which meet the
search criteria.  See the C<count> method in L<Kinetic::Store|Kinetic::Store>
for more information.

=cut

    sub count { 
        my $class = shift;
        Kinetic::Store->count($class->my_class, @_);
    }
    $cm->add_method(
        name    => 'count',
        context => Class::Meta::CLASS,
    );

##############################################################################

=head3 search_uuids

  my $uuids = Some::Kinetic::Object->search_uuids(name => LIKE '%vid');

This method returns an array ref of uuids of the objects in the data store
which meet the search criteria.  See the C<search_uuids> method in
L<Kinetic::Store|Kinetic::Store> for more information.

=cut

    sub search_uuids { 
        my $class = shift;
        Kinetic::Store->search_uuids($class->my_class, @_);
    }
    $cm->add_method(
        name    => 'search_uuids',
        context => Class::Meta::CLASS,
    );

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessors

=head3 uuid

  my $uuid        = $kinetic->uuid;
  my $uuid_bin    = $kinetic->uuid_bin;
  my $uuid_hex    = $kinetic->uuid_hex;
  my $uuid_base64 = $kinetic->uuid_base64;

Returns the Kinetic object's globally unique identifier. All Kinetic objects
have a UUID as soon as they're created, even before they're saved to the data
store.

The UUID takes the form of a 32-bit string, such as
"12CAD854-08BD-11D9-8AF0-8AB02ED80375". It is also available in binary, hex
string, and Base64-encoded formats using the corresponding accessors:

=over 4

=item C<uuid_bin>

=item C<uuid_hex>

=item C<uuid_base64>

=back

B<Notes:> Kinetic's UUIDs are generated by Data::UUID.

=cut

    my $ug = Data::UUID->new;
    $cm->add_attribute(
        name        => 'uuid',
        label       => 'UUID',
        type        => 'uuid',
        required    => 1,
        indexed     => 1,
        unique      => 1,
        once        => 1,
        default     => sub { $ug->create_str },
        authz       => Class::Meta::RDWR,
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'The globally unique identifier for this object',
        )
    );

    sub uuid_bin    { $ug->from_string(  shift->uuid     ) }
    sub uuid_hex    { $ug->to_hexstring( shift->uuid_bin ) }
    sub uuid_base64 { $ug->to_b64string( shift->uuid_bin ) }


##############################################################################

=head3 state

  my $state = $kinetic->state;
  $kinetic->state($state);

The state of the Kinetic object. Kinetic objects always have one of the
several states representing whether they're active, inactive, or deleted. See
L<Kinetic::Util::State|Kinetic::Util::State> for details on the various supported states.

A number of shortcut methods are provided to simplify checking for whether a
Kinetic object is in a particular state, or to set it to a particular state.
Those methods are:

=over 4

=item C<is_permanent>

=item C<is_active>

=item C<is_inactive>

=item C<is_deleted>

=item C<activate>

=item C<deactivate>

=item C<delete>

=item C<purge>

=back

=cut

    $cm->add_attribute(
        name          => 'state',
        label         => 'State',
        type          => 'state',
        required      => 1,
        indexed       => 1,
        default       => Kinetic::Util::State::ACTIVE,
        widget_meta   => Kinetic::Meta::Widget->new(
            type    => 'dropdown',
            tip     => 'The state of this object',
            options => sub {[
                [ ACTIVE->value   => ACTIVE->name   ],
                [ INACTIVE->value => INACTIVE->name ],
                [ DELETED->value  => DELETED->name  ],
                [ PURGED->value   => PUGRGE->name   ],
            ]}
        )
    );

    sub is_permanent { shift->state == PERMANENT }
    sub is_active    { shift->state == ACTIVE    }
    sub is_inactive  { shift->state == INACTIVE  }
    sub is_deleted   { shift->state == DELETED   }

    sub activate     { shift->state(ACTIVE)      }
    sub deactivate   { shift->state(INACTIVE)    }
    sub delete       { shift->state(DELETED)     }
    sub purge        { shift->state(PURGED)      }

##############################################################################

=head3 save

  $kinetic->save;

Calling this method saves the Kinetic object to the data store.  See the
C<save> method in L<Kinetic::Store|Kinetic::Store> for more information.

=cut

    sub save { Kinetic::Store->save(@_) }
    $cm->add_method(
        name    => 'save',
        context => Class::Meta::OBJECT,
    );

    $cm->build;
} # BEGIN

##############################################################################

=head2 Other Instance Methods

=head3 clone

  my $clone = $bric->clone;

Creates a deep copy of the Kinetic object. Any contained objects will also be
cloned, so that a completely new object is created as an exact copy of the
existing object.

=cut

sub clone {
    my $self = shift;

    # Construct a new object and grab the UUID.
    my $class = $self->my_class;
    my $new = ref($self)->new;
    my $uuid = $new->{uuid};

    # I think it's okay to use the underlying hash, so that we're sure to
    # get all private attributes, too.
    while (my ($k, $v) = each %$self) {
        # XXX Need to account for circular references?
        $new->{$k} = UNIVERSAL::can($v, 'clone')
          ? $v->clone
          : $v;
    }

    # Restore the UUID (it was replaced in the while block) and return the
    # new object.
    $new->{uuid} = $uuid;
    return $new;
}

##############################################################################

=begin private

=head2 Private Instance Methods

=end private

=cut

1;
__END__

##############################################################################

=head1 See Also

=over 4

=item L<Kinetic::Meta|Kinetic::Meta>

This module provides the interface for the Kinetic class automation and
introspection defined here.

=back

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
