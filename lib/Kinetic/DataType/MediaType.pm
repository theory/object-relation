package Kinetic::DataType::MediaType;

# $Id$

use strict;
use base 'MIME::Type';
use MIME::Types;
use Kinetic::Meta::Type;
use Kinetic::Util::Exceptions qw(throw_invalid);

use version;
our $VERSION = version->new('0.0.2');

=head1 Name

Kinetic::DataType::MediaType - Kinetic MediaType objects

=head1 Synopsis

  use aliased 'Kinetic::DataType::MediaType';
  my $media_type = MediaType->bake('text/html');

=head1 Description

This module creates the "media_type" data type for use in Kinetic attributes.
It subclasses the L<MIME::Type|MIME::Type> module to offer media types to
Kinetic applications. It differs from MIME::Type in providing the C<bake()>
method for deserialization from the data store. Use the C<type()> method for
serialization.

=cut

# Create the data type.
Kinetic::Meta::Type->add(
    key   => 'media_type',
    name  => 'Media Type',
    raw   => sub { ref $_[0] ? shift->type : shift },
    bake  => sub { __PACKAGE__->bake(shift) },
    check => __PACKAGE__,
);

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $media_type = Kinetic::DataType::MediaType->new($string);

Overrides the implementation of C<new()> in L<MIME::Type|MIME::Type> to
redispatch to C<bake()> if there is only one argument. Otherwise, it sends the
arguments off to MIME::Type's C<new()>.

=cut

sub new {
    my $class = shift;
    return @_ == 1 ? $class->bake(@_) : $class->SUPER::new(@_);
}

##############################################################################

=head3 bake

  my $media_type = Kinetic::DataType::MediaType->bake($string);

Parses a media type string and returns a Kinetic::DataType::MediaType object.
If the media type does not currently exist, it will be created by calling
C<new()>.

=cut

my $mt = MIME::Types->new;
sub bake {
    my ($class, $string) = @_;
    throw_invalid [ 'Value "[_1]" is not a valid media type', $string, ]
        if $string !~ m{\w+/\w+};
    return bless +(
        $mt->type($string) || __PACKAGE__->new(type => $string)
    ), $class;
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
