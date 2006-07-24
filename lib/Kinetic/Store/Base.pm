package Kinetic::Store::Base;

# $Id$

use 5.008003;
use strict;
use version;
use encoding 'utf8';
binmode STDERR, ':utf8';
use Kinetic::Store::Meta;
use Kinetic::Store::Meta::Widget;
use Kinetic::Store::Handle;
use Kinetic::Store::Functions qw(:uuid);
use Kinetic::Store::DataType::State qw(:all);

our $VERSION = version->new('0.0.2');

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

Kinetic::Store::Base - The Kinetic::Store base class

=end comment

=head1 Name

Kinetic::Store::Base - The Kinetic::Store base class

=head1 Synopsis

  package MyApp::Thingy;
  use Kinetic::Store;

  meta thingy => (
      store_config => {
          class => 'DB::Pg',
          cache => 'Memcached',
          dsn   => 'dbi:Pg:dbname=kinetic',
          user  => 'kinetic',
          pass  => 'kinetic',
      };
  );

  has => 'provenance';

  build;

=head1 Description

Kinetic is an enterprise application framework. It pulls together the
Class::Meta, Widget::Meta, and other modules to offer a platform for the rapid
development of enterprise applications in Perl.

This class serves as the base class for all Kinetic classes. It defines the
interface for all data access, and provides convenience methods to all of the
data store access methods required by the subclasses.

=cut

BEGIN {
    my $cm = Kinetic::Store::Meta->new(
        key         => 'kinetic_base_class',
        name        => 'Kinetic Base Class',
        plural_name => 'Kinetic Base Classes',
        trust       => 'Kinetic::Store::Handle',
        abstract    => 1,
    );

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $kinetic = Kinetic::Store::Base->new;
  $kinetic = Kinetic::Store::Base->new(%init);

The universal Kinetic object constructor. It takes a list of parameters as its
arguments, constructs a new Kinetic object with its attributes set to the
values relevant to those parameters, and returns the new Kinetic object.

The C<new()> constructor is guaranteed to always be callable without
parameters. This makes it easy to create new Kinetic objects with their
parameters set to default values.

=cut

    # Create the new() constructor.
    $cm->add_constructor(
        name   => 'new',
        create => 1,
    );

##############################################################################
# Class Methods
##############################################################################

=head2 Class Methods

=head3 my_class

  my $class = Kinetic::Store::Base->my_class;

Returns the Kinetic::Store::Meta::Class object that describes this class. See
L<Class::Meta|Class::Meta> for more information.

=head3 my_key

  my $key = Kinetic::Store::Base->my_key;

Returns the key that uniquely identifies this class. The class key is used in
the Kinetic UI, and by the SOAP server. Equivalent to C<<
Kinetic::Store::Base->my_class->key >>.

=cut

    sub my_key { shift->my_class->key }

##############################################################################

=head3 lookup

  my $kinetic = Some::Kinetic::Object->lookup(uuid => $uuid);

Calling this method looks up a Kinetic object in the data store. See the
C<lookup> method in L<Kinetic::Store::Handle|Kinetic::Store::Handle> for more
information.

=cut

    sub lookup {
        my $class = shift;
        $class->StoreHandle->lookup($class->my_class, @_);
    }
    $cm->add_constructor(
        name   => 'lookup',
        create => 0,
    );

##############################################################################

=head3 query

  my $iterator = Some::Kinetic::Object->query(name => LIKE '%vid');

Calling this method searches the data store for objects meeting the query
criteria. See the C<query> method in
L<Kinetic::Store::Handle|Kinetic::Store::Handle> for more information.

=cut

##############################################################################

=head3 squery

  my $iterator = Some::Kinetic::Object->squery("name => LIKE '%vid'");

Calling this method searches the data store for objects meeting the query
criteria. This method uses a string search instead of a code search. See the
C<squery> method in L<Kinetic::Store::Handle|Kinetic::Store::Handle> for more
information.

=cut

    my @redispatch = qw(
        query
        squery
        count
        query_uuids
        squery_uuids
    );

    foreach my $method (@redispatch) {
        no strict 'refs';
        *$method = eval qq/sub {
                my \$class = shift;
                \$class->Storehandle->$method(\$class->my_class, \@_);
        }/;

        $cm->add_method(
            name    => $method,
            context => Class::Meta::CLASS,
        );
    }

##############################################################################

=head3 count

  my $count = Some::Kinetic::Object->count(name => LIKE '%vid');

This method returns a count of the objects in the data store which meet the
search criteria. See the C<count> method in
L<Kinetic::Store::Handle|Kinetic::Store::Handle> for more information.

=cut

##############################################################################

=head3 query_uuids

  my $uuids = Some::Kinetic::Object->query_uuids(name => LIKE '%vid');

This method returns an array ref of uuids of the objects in the data store
which meet the search criteria. See the C<query_uuids> method in
L<Kinetic::Store::Handle|Kinetic::Store::Handle> for more information.

=cut

##############################################################################

=head3 squery_uuids

  my $uuids = Some::Kinetic::Object->squery_uuids("name => LIKE '%vid'");

Same as query_ids, but uses a string search.

=cut

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

B<Notes:> Kinetic::Store:'s UUIDs are generated by OSSP::uuid.

=cut

    $cm->add_attribute(
        name        => 'uuid',
        label       => 'UUID',
        type        => 'uuid',
        required    => 1,
        indexed     => 1,
        distinct    => 1,
        once        => 1,
        default     => \&create_uuid,
        authz       => Class::Meta::READ,
        widget_meta => Kinetic::Store::Meta::Widget->new(
            type => 'text',
            tip  => 'The globally unique identifier for this object',
        )
    );

    sub uuid_bin    { uuid_to_bin(shift->uuid) }
    sub uuid_hex    { uuid_to_hex(shift->uuid) }
    sub uuid_base64 { uuid_to_b64(shift->uuid) }

##############################################################################

=head3 state

  my $state = $kinetic->state;
  $kinetic->state($state);

The state of the Kinetic object. Kinetic objects always have one of the
several states representing whether they're active, inactive, or deleted. See
L<Kinetic::Store::DataType::State|Kinetic::Store::DataType::State> for details
on the various supported states.

A number of shortcut methods are provided to simplify checking for whether a
Kinetic object is in a particular state, or to set it to a particular state.
Those methods are:

=over 4

=item C<is_permanent>

=item C<is_active>

=item C<is_inactive>

=item C<is_deleted>

=item C<is_purged>

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
        default       => Kinetic::Store::DataType::State::ACTIVE,
        widget_meta   => Kinetic::Store::Meta::Widget->new(
            type    => 'dropdown',
            tip     => 'The state of this object',
            options => sub {[
                [ ACTIVE->value   => ACTIVE->name   ],
                [ INACTIVE->value => INACTIVE->name ],
                [ DELETED->value  => DELETED->name  ],
                [ PURGED->value   => PURGED->name   ],
            ]}
        )
    );

    sub is_permanent { shift->state == PERMANENT }
    sub is_active    { shift->state == ACTIVE    }
    sub is_inactive  { shift->state == INACTIVE  }
    sub is_deleted   { shift->state == DELETED   }
    sub is_purged    { shift->state == PURGED    }

    sub activate     { shift->state(ACTIVE)      }
    sub deactivate   { shift->state(INACTIVE)    }
    sub delete       { shift->state(DELETED)     }
    sub purge        { shift->state(PURGED)      }

##############################################################################

=head3 is_persistent

  my $is_persistent = $kinetic->is_persistent;

Returns true if the object is persistent and false if it is not. What does it
mean to be persistent? It means that the object has been saved to the data
store at least once and has not been purged.

=cut

sub is_persistent {
    my $self = shift;
    # XXX This should be changed if we ever rely on non-DB stores.
    return $self->{id} ? $self : undef;
}

##############################################################################

=head2 Other Instance Methods

=head3 save

  $kinetic->save;

Calling this method saves the Kinetic object to the data store. See the
C<save> method in L<Kinetic::Store::Handle|Kinetic::Store::Handle> for more
information.

=cut

    sub save {
        my $self = shift;
        $self->StoreHandle->save($self, @_);
        return $self;
    }
    $cm->add_method(
        name    => 'save',
        context => Class::Meta::OBJECT,
    );

    $cm->build;

##############################################################################

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
        my $new   = ref($self)->new;

        # I think it's okay to use the underlying hash, so that we're sure to
        # get all private attributes, too.
        while (my ($k, $v) = each %$self) {
            # XXX Need to account for circular references?
            $new->{$k} = ref $v && eval { $v->can('clone') }
                ? $v->clone
                : $v;
        }

        # Reset the UUID (it was replaced in the while block) and return.
        $new->{uuid} = undef;
        return $new;
    }
    $cm->add_method(
        name    => 'clone',
        context => Class::Meta::OBJECT,
    );

##############################################################################

=begin private

=head2 Private Instance Methods

=head3 _add_modified

  $kinetic->_add_modified(@attr_name);

Pass in one or more persistent attribute names and they will be added to the
list of object attributes that have been modified. Called by the accessors
generated by
L<Kinetic::Store::Meta::AccessorBuilder|Kinetic::Store::Meta::AccessorBuilder>.

=cut

    sub _add_modified {
        my $self = shift;
        my $mod = $self->{_modified} ||= {};
        $mod->{$_} = undef for @_;
        return $self;
    }

##############################################################################

=head3 _modified

  my $bool = $kinetic->_is_modified($attr_name);

This method returns a true value if the persistent attribute named by
$attr_name has been modified since the object was instantiated or since the
last time it was saved, and false if it has not. Called by the delegating
accessors generated by
L<Kinetic::Store::Meta::AccessorBuilder|Kinetic::Store::Meta::AccessorBuilder>.

=cut

    sub _is_modified {
        my $self = shift;
        my $mod = $self->{_modified} or return undef;
        return exists $mod->{shift()} ? $self : undef;
    }

##############################################################################

=head3 _get_modified

  my @modified = $kinetic->_get_modified;
  my $modified = $kinetic->_get_modified;

Returns a list or array reference of the names of all of the persistent
attributes that have been modified since the object was instantiated or since
the last time it was saved. Called by
C<Kinetic::Store::Handle|Kinetic::Store::Handle> and its subclasses to
determine what changes to send to the data store.

=cut

    sub _get_modified {
        my $self = shift;
        my $mod = $self->{_modified} || {};
        return wantarray ? sort keys %{ $mod } : [ sort keys %{ $mod } ];
    }

##############################################################################

=head3 _clear_modified

  $kinetic->_clar_modified;

Clears out the list of the names of modified persistent attributes. Called by
C<Kinetic::Store::Handle|Kinetic::Store::Handle> and its subclasses once they
have saved any changes to the data store.

=cut

    sub _clear_modified {
        my $self = shift;
        delete $self->{_modified};
        return $self;
    }

} # BEGIN

1;
__END__

##############################################################################

=head1 See Also

=over 4

=item L<Kinetic::Store::Meta|Kinetic::Store::Meta>

This module provides the interface for the Kinetic class automation and
introspection defined here.

=back

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut