package App::Kinetic::Base;

# $Id$

use strict;
use App::Kinetic;
use App::Kinetic::Meta;
use Widget::Meta;

=head1 Name

App::Kinetic::Biz - Kinetic application framework base class

=head1 Synopsis

  package MyApp::Biz;
  use base qw(App::Kinetic::Base);

=head1 Description

This class serves as the base class for all Kinetic classes. It defines the
interface for all data access, and provides convenience methods to all of the
data store access methods required by the subclasses.

=cut

BEGIN {
    my $cm = App::Kinetic::Meta->new(
        key         => 'base',
        name        => 'Base',
        plural_name => 'Base',
        abstract    => 1,
    );

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $biz_obj = App::Kinetic::Base->new;
  $kinetic = App::Kinetic::Base->new(%init);

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

  my $class = App::Kinetic::Base->my_class;

Returns the App::Kinetic::Meta::Class object that describes this class. See
L<Class::Meta|Class::Meta> for more information.

=head3 my_key

  my $key = App::Kinetic::Base->my_key;

Returns the key that uniquely identifies this class. The class key is used in
the Kinetic UI, and by the SOAP server. Equivalent to
C<< App::Kinetic::Base->my_class->key >>.

=cut

    sub my_key { shift->my_class->key }

##############################################################################
# Instance Methods.
##############################################################################

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Class::Meta|Class::Meta>

This module provides the interface for the Kinetic class automation and
introspection defined here.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
