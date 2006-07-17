package Kinetic::Store::Format::JSON;

# $Id$

use strict;
use warnings;
use JSON::Syck;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Store::Format';

=head1 Name

Kinetic::Store::Format::JSON - The Kinetic JSON serialization class

=head1 Synopsis

  use Kinetic::Store::Format::JSON;
  my $formatter = Kinetic::Store::Format::JSON->new;
  my $json      = $formatter->serialize($kinetic_object);
  my $object    = $formatter->deserialize($json);

=head1 Description

This class is used for serializing and deserializing Kinetic objects to and 
from JSON.  New objects may be created or existing objects may be updated using
this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Store::Format::JSON->new;

Creates and returns a new JSON format  object. 

=cut

sub _init {
    my ( $class, $arg_for ) = @_;
    # basically a no-op for JSON, but _init needs to return a ref to bless.
    $arg_for ||= {};
    return $arg_for;
}

##############################################################################

=head3 content_type

  my $content_type = $formatter->content_type;

Returns the MIME content type for the current format.

=cut

# XXX There also appears to be a 'text/x-json' content type, but it's not
# standard, not is it widespread.

sub content_type { 'text/plain' }

##############################################################################

=head3 ref_to_format

  my $json = $formatter->ref_to_format($reference);

Converts an arbitrary reference to its JSON equivalent.

=cut

sub ref_to_format {
    my ( $self, $ref ) = @_;
    $ref = $self->expand_ref($ref);
    return JSON::Syck::Dump($ref);
}

##############################################################################

=head3 format_to_ref

  my $reference = $formatter->format_to_ref($json);

Converts JSON to its equivalent Perl reference.

=cut

sub format_to_ref { 
    my ($self, $json) = @_;
    return JSON::Syck::Load($json);
}

1;

__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
