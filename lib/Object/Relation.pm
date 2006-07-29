package Object::Relation;

# $Id$

use base 'Class::Meta::Express';
use Object::Relation::Meta;
our $VERSION = '0.11';

sub meta {
    splice @_, 1, 0, meta_class => 'Object::Relation::Meta', default_type => 'string';
    goto &Class::Meta::Express::meta;
}

1;

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

Object::Relation - Advanced Object Relational Mapper

=end comment

=head1 Name

Object::Relation - Advanced Object Relational Mapper

=head1 Synopsis

  package MyApp::Thingy;
  use Object::Relation;

  meta 'thingy';
  has  'provenence';
  build;

=head1 Description

Object::Relation is an advanced object relational mapper. Use it to define
your model classes and it handles the rest. And by that I mean that it works
hard to exploit the most advanced features of your data store to provide
efficient yet easy to use objects for use in your system. It currently
supports SQLite and PostgreSQL data stores.

B<Notes:> Develoment and documentation are still in progress; this should be
considered an alpha release. Do not use it in production as things will likely
change over the next few months. But don't let that stop you from playing with
it now to see what it can do!

And now back to the documenation that still needs updating.

=head2 Basic Usage

This package makes it dead simple to create Object::Relation classes. It
overrides the funcions in L<Class::Meta::Express|Class::Meta::Express> so that
the class is always built by L<Object::Relation::Meta|Object::Relation::Meta>
and so that attributes are strings by default. Of course, these settings can
be overridden by explicitly passing the C<meta_class> and and C<default_type>
parameters to C<meta()>:

  package MyApp::SomethingElse;
  use Object::Relation;

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

Creates the L<Object::Relation::Meta|Object::Relation::Meta> object used to
construct the class.

=item ctor

Creates a constructor for the class. Note that all classes created by
L<Object::Relation::Meta|Object::Relation::Meta> automatically inherit from
L<Object::Relation::Base|Object::Relation::Base>, and therefore already have a
C<new()> constructor, among other methods.

=item has

Creates an attribute of the class.

=item method

Creates a method of the class.

=item build

Builds the class and removes the above functions from its namespace.

=back

=head1 To Do

=over

=item *

Add caching to the store.

=item *

Use batch updates and inserts for collections?

=item *

Move all types into classes.

=item *

Make teardowns reverse setups instead of just wiping out the database.

=item *

Swith from XML::Simple to SAX in Format::XML.

=back

=head1 See Also

=over 4

=item L<Object::Relation::Meta|Object::Relation::Meta>

Subclass of L<Class::Meta|Class::Meta> that defines Object::Relation classes
created with Object::Relation.

=item L<Class::Meta::Express|Class::Meta::Express>

The module that Object::Relation overrides, and from which it inherits its
interface. See its documentation for a more complete explication of the
exported functions and their parameters.

=item L<Object::Relation::Base|Object::Relation::Base>

The base class from which all classes created by Object::Relation inherit.

=back

=head1 Bugs

Please send bug reports to <bug-fsa-rules@rt.cpan.org>.

=head1 Author

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 AUTHOR

=end comment

Kineticode, Inc. <info@obj_relode.com>.

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
