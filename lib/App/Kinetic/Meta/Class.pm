package App::Kinetic::Meta::Class;

# $Id$

use strict;
use base 'Class::Meta::Class';
#use App::Kinetic::Util::Context;

=head1 Name

App::Kinetic::Meta::Class - Kinetic class metadata class.

=head1 Synopsis

  my $class = MyApp::Thingy->my_class;
  my $thingy = MyApp::Thingy->new;

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

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 name

  my $name = $class->name;

Returns the localized form of the name of the class, such as "Thingy".

=cut

#sub name {
#    App::Kinetic::Util::Context->language->maketext(shift->SUPER::name);
#}

##############################################################################

=head3 plural_name

  my $plural_name = $class->plural_name;

Returns the localized plural form of the name of the class, such as
"Thingies".

=cut

sub plural_name {
#    App::Kinetic::Util::Context->language->maketext(shift->{plural_name});
    shift->{plural_name};
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

=item L<App::Kinetic::Meta|App::Kinetic::Meta>

The class for Kinetic class automation, introspection, and data validation.

=item L<App::Kinetic::Meta::Attribute|App::Kinetic::Meta::Attribute>

Kinetic object attribute introspection class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
