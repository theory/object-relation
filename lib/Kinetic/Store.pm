package Kinetic::Store;

# $Id$

use version;
use base 'Class::Meta::Express';
use Kinetic::Store::Meta;
our $VERSION = version->new('0.0.2');

sub meta {
    splice @_, 1, 0, meta_class => 'Kinetic::Store::Meta', default_type => 'string';
    goto &Class::Meta::Express::meta;
}

1;

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

Kinetic::Store - Advanced Object Relational Mapper

=end comment

=head1 Name

Kinetic::Store - Advanced Object Relational Mapper

=head1 Synopsis

  package MyApp::Thingy;
  use Kinetic::Store;

  meta 'thingy';
  has  'provenence';
  build;

=head1 Description

This package makes it dead simple to create Kinetic classes. It overrides the
funcions in L<Class::Meta::Express|Class::Meta::Express> so that the class is
always built by L<Kinetic::Store::Meta|Kinetic::Store::Meta> and so that
attributes are strings by default. Of course, these settings can be
overriddent by using the explicitly passing the C<meta_class> and and
C<default_type> parameters to C<meta()>:

  package MyApp::SomethingElse;
  use Kinetic::Store;

  meta else => (
      meta_class   => 'My::Meta,
      default_type => 'binary',
  );

Or, for attribute types, you can set them on a case-by-case basis by passing
the C<type> parameter to C<has()>:

      has image => ( type => 'binary' );

=head1 Interface

The functions exported by this module are:

=over

=item meta

Creates the L<Kinetic::Store::Meta|Kinetic::Store::Meta> object used to
construct the class.

=item ctor

Creates a constructor for the class. Note that all classes created by
L<Kinetic::Store::Meta|Kinetic::Store::Meta> automatically inherit from
L<Kinetic|Kinetic>, and therefore already have a C<new()> constructor, among
other methods.

=item has

Creates an attribute of the class.

=item method

Creates a method of the class.

=item build

Builds the class and removes the above functions from its namespace.

=back

=head1 See Also

=over 4

=item L<Kinetic::Store::Meta|Kinetic::Store::Meta>

Subclass of L<Class::Meta|Class::Meta> that defines Kinetic classes
created with Kinetic::Store.

=item L<Class::Meta::Express|Class::Meta::Express>

The module that Kinetic::Store overrides, and from which it inherits its
interface. See its documentation for a more complete explication of the
exported functions and their parameters.

=item L<Kinetic|Kinetic>

The base class from which all classes created by Kinetic::Store inherit.

=back

=head1 Bugs

Please send bug reports to <bug-fsa-rules@rt.cpan.org>.

=head1 Author

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 AUTHOR

=end comment

Kineticode, Inc. <info@kineticode.com>.

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
