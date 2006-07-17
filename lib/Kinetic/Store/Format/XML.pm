package Kinetic::Store::Format::XML;

# $Id$

use strict;
use warnings;
use XML::Simple ();

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Store::Format';

=head1 Name

Kinetic::Store::Format::XML - The Kinetic XML serialization class

=head1 Synopsis

  use Kinetic::Store::Format::XML;
  my $formatter = Kinetic::Store::Format::XML->new;
  my $xml      = $formatter->serialize($kinetic_object);
  my $object    = $formatter->deserialize($xml);

=head1 Description

This class is used for serializing and deserializing Kinetic objects to and 
from XML.  New objects may be created or existing objects may be updated using
this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Store::Format::XML->new;
  # or
  my $xml = Kinetic::Store::Format::XML->new({
    pretty => 1,
    indent => 2,
  });

Creates and returns a new XML format  object.  It optionally takes a
L<Kinetic|Kinetic> object as an argument.  This is equivalent to:

If preferred, a hashref may be passed as an argument.  Keys are:

=over 4

=item * pretty

Whether to use newlines between XML elements.

=item * indent

Indentation level (in spaces) for nested XML elements.

=back

As a general rule, you will want to call C<new> without arguments.  This
ensures a more compact XML representation, thus saving bandwidth.

=cut

sub _init {
    my ( $class, $arg_for ) = @_;
    $arg_for ||= {};
    my $xml  = XML::Simple->new;
    $arg_for->{xml} = $xml;
    return $arg_for;
}

##############################################################################

=head3 content_type

  my $content_type = $formatter->content_type;

Returns the MIME content type for the current format.

=cut

sub content_type { 'text/xml' }

##############################################################################

=head3 ref_to_format

  my $xml = $formatter->ref_to_format($reference);

Converts an arbitrary reference to its XML equivalent.

=cut

sub ref_to_format {
    my ( $self, $ref ) = @_;
    $ref = $self->expand_ref($ref);
    local $^W;   # suppress "uninitialized" warnings.  These are common with
                 # undef keys
    return $self->{xml}->XMLout($ref);
}

##############################################################################

=head3 format_to_ref

  my $reference = $formatter->format_to_ref($xml);

Converts XML to its equivalent Perl reference.

=cut

sub format_to_ref { 
    my ($self, $xml) = @_; 
    return $self->{xml}->XMLin(
        $xml,
        suppressempty => undef,
        keyattr       => [],
        #ForceArray    => [ 'instance' ], # XXX maybe later?
    );
}

1;

__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
