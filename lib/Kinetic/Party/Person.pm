package Kinetic::::Party::Person;

# $Id$

use strict;
use base qw(Kinetic::::Party);
use Kinetic::Util::Context;
use Lingua::Strfname ();
use Kinetic::Util::Config qw(:api);

=head1 Name

Kinetic::::Party::Person - Kinetic person objects

=head1 Description

This class serves as the abstract base class for people in Kinetic.

=cut

BEGIN {
    my $cm = Kinetic::Meta->new(
        key         => 'person',
        name        => 'Person',
        plural_name => 'Persons',
        abstract    => 1,
    );

##############################################################################
# Constructors.
##############################################################################

=head1 Instance Interface

In addition to the interface inherited from L<Kinetic::::|Kinetic::>
and L<Kinetic::::Party|Kinetic::::Party>, this class offers a number
of its own attributes.

=head2 Accessors

=head3 last_name

  my $last_name = $person->last_name;
  $person->last_name($last_name);

The person's last name.

=cut

    $cm->add_attribute(
        name        => 'last_name',
        label       => 'Last Name',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's last name"
        )
    );

##############################################################################

=head3 first_name

  my $first_name = $person->first_name;
  $person->first_name($first_name);

The person's first name.

=cut

    $cm->add_attribute(
        name        => 'first_name',
        label       => 'First Name',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's first name"
        )
    );

##############################################################################

=head3 middle_name

  my $middle_name = $person->middle_name;
  $person->middle_name($middle_name);

The person's middle name.

=cut

    $cm->add_attribute(
        name        => 'middle_name',
        label       => 'Middle Name',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's middle name"
        )
    );

##############################################################################

=head3 nickname

  my $nickname = $person->nickname;
  $person->nickname($nickname);

The person's nickname.

=cut

    $cm->add_attribute(
        name        => 'nickname',
        label       => 'Nickname',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's nickname"
        )
    );

##############################################################################

=head3 prefix

  my $prefix = $person->prefix;
  $person->prefix($prefix);

The prefix to the person's name, such as "Mr.", "Ms.", "Dr.", etc.

=cut

    $cm->add_attribute(
        name        => 'prefix',
        label       => 'Prefix',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The prefix to the person's name"
        )
    );

##############################################################################

=head3 suffix

  my $suffix = $person->suffix;
  $person->suffix($suffix);

The suffix to the person's name, such as "JD", "PhD", "MD", etc.

=cut

    $cm->add_attribute(
        name        => 'suffix',
        label       => 'Suffix',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The suffix to the person's name"
        )
    );

##############################################################################

=head3 generation

  my $generation = $person->generation;
  $person->generation($generation);

The generation to the person's name, such as "Jr.", "III", etc.

=cut

    $cm->add_attribute(
        name        => 'generation',
        label       => 'Generation',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The generation of the person's name"
        )
    );

##############################################################################

=head2 Instance Methods

=head3 name

  my $name = $person->name;
  $name = $person->name($format);

Return the person object's name as formatted according to a
L<Linguage::Strfname|Linguage::Strfname> format. Although the C<name>
attribute is defind by Kinetic::, Kinetic::::Party::Person uses this
method to override its behavior so that it looks more like a read-only
attribute.

The default format is specified by the locale returned by the currently
selected langauge. See the L<Linguage::Strfname|Linguage::Strfname>
documentation for details on its formats to pass in custom formats.

=cut

    sub name {
        my ($self, $format) = @_;
        $format ||=
          Kinetic::Util::Language->get_handle->maketext('strfname_format');
        return Lingua::Strfname::strfname(
            $format,
            $self->last_name,
            $self->first_name,
            $self->middle_name,
            $self->prefix,
            $self->suffix,
            $self->generation
        );
    }

    # We want to override the name attribute to make it READ-only, and so that
    # this method for all practical purposes becomes its replacement.
    $cm->add_attribute(
        name        => 'name',
        label       => 'Name',
        type        => 'string',
        authz       => Class::Meta::READ,
        create      => Class::Meta::NONE,
        override    => 1,
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'The name of this object',
        )
    );

    $cm->build;
} # BEGIN

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. See
L<Kinetic::License|Kinetic::License> for complete license terms and
conditions.

=cut
