package App::Kinetic::Meta;

# $Id$

use strict;
use base 'Class::Meta';
#use App::Kinetic::Meta::DataTypes;
use App::Kinetic::Meta::Attribute;
use App::Kinetic::Meta::Class;
#use App::Kinetic::Util::Exceptions qw(throw_exlib);
use Class::Meta::Types::String; # Move to DataTypes.

=head1 Name

App::Kinetic::Meta - Kinetic class automation, introspection, and data validation

=head1 Synopsis

  package MyApp::Thingy;

  use strict;
  use base 'App::Kinetic::Base';

  BEGIN {
      my $cm = App::Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
      );
      $cm->build;
  }

=head1 Description

This class inherits from L<Class::Meta|Class::Meta> to provide class
automation, introspection, and data validation for Kinetic classes. It
overrides the behavior of Class::Meta to specify the use of the
L<App::Kinetic::Meta::Class|App::Kinetic::Meta::Class> subclass in place of
Class::Meta::Class.

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $cm = App::Kinetic::Meta->new(%init);

Overrides the parent Class::Meta constructor in order to specify that the
class class be App::Kinetic::Meta::Class and that the attribute class be
App::Kinetic::Meta::Attribute.

=cut

sub new {
    shift->SUPER::new(
        # We must specify the package
        package         => scalar caller,
        @_,
        class_class     => 'App::Kinetic::Meta::Class',
        attribute_class => 'App::Kinetic::Meta::Attribute',
    );
}

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<App::Kinetic::Base|App::Kinetic::Base>

The Kinetic base class.

=item L<App::Kinetic::Meta::Class|App::Kinetic::Meta::Class>

The Kinetic class metadata class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
