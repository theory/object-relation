package Kinetic::Store::Setup;

# $Id$

use strict;
use Kinetic::Store::Exceptions qw(
    throw_invalid_class
    throw_unimplemented
);

use Class::BuildMethods qw(
    verbose
);

use version;
our $VERSION = version->new('0.0.2');

=head1 Name

Kinetic::Store::Setup - Set up a Kinetic Data Store

=head1 Synopsis

  use Kinetic::Store::Setup;
  my $setup = Kinetic::Store::Setup->new(\%params);
  $setup->setup;

=head1 Description

This module is the base class for classes that set up a Kinetic::Store::Handle data
store.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $setup = Kinetic::Store::Setup->new(\%params);

This factory constructor creates and returns a new setup object. By default,
it accepts the following parameters:

=over

=item class

Determines which subclass of Kinetic::Store::Setup to use. The class can be
specified as a full class name, such as
L<Kinetic::Store::Setup::DB::Pg|Kinetic::Store::Setup::DB::Pg>, or if it's in
the C<Kinetic::Store::Setup> namespace, you can just use the remainder of the
class name, e.g., C<DB::Pg>. Once Kinetic::Store::Setup has loaded the
subclass, it will redispatch to its C<new()> constructor. The C<class>
parameter defaults to C<DB::SQLite> unless the constructor is called directly
on the subclass, in which case that class will be used.

=item class_dirs

An array refererence of the classes to search for classes that inherit from
C<Kinetic::Store::Base>. These will be passed to the C<load_classes> method of
L<Kinetic::Store::Schema|Kinetic::Store::Schema>; as such, the final value in
the list may optionally be a File::Find::Rule object. Defaults to C<['lib']>
if not specified.

=item verbose

A boolean value indicating whether or not the setup should be verbose.

=back

=cut

sub new {
    my ($class, $params) = @_;

    if ($class eq __PACKAGE__) {
        my $sub = delete $params->{class} || 'DB::SQLite';
        $class = __PACKAGE__ . "::$sub";
        eval "require $class";
        if ($@ && $@ =~ /^Can't locate/) {
            $class = $sub;
            eval "require $class";
        }

        throw_invalid_class [
            'I could not load the class "[_1]": [_2]',
            $class,
            $@,
        ] if $@;

        return $class->new($params);
    }

    my $self = bless {} => $class;
    $self->{class_dirs} = $params->{class_dirs} || ['lib'];

    while (my ($k, $v) = each %$params) {
        next if $k eq 'class' || $k eq 'class_dirs';;
        if (my $meth = $self->can($k)) {
            $self->$meth($v);
        }
    }

    $self->verbose(0) unless defined $self->verbose;
    return $self;
}

##############################################################################

=head2 Class Methods

=head3 schema_class

  my $schema_class = Kinetic::Store::Setup->schema_class

Returns the name of the Kinetic::Store::Schema subclass that can be used
to generate the schema code to build the data store. By default, this method
returns the same name as the name of the Kinetic::Store::Setup subclass,
but with "Store" replaced with "Schema".

=cut

sub schema_class {
    (my $class = ref $_[0] ? ref shift : shift) =~ s/Setup/Schema/;
    return $class;
}

##############################################################################

=head3 store_class

  my $store_class = Kinetic::Store::Setup->store_class

Returns the name of the Kinetic::Store::Handle subclass that manages the interface to
the data store for Kinetic applications. By default, this method returns the
same name as the name of the Kinetic::Store::Setup subclass, but with "Build"
removed.

=cut

sub store_class {
    (my $class = ref $_[0] ? ref shift : shift) =~ s/Setup:://;
    return $class;
}

##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

=head3 verbose

  my $verbose = $setup->verbose;
  $setup->verbose($verbose);

A boolean value idicating whether or not the setup should be verbose.

=head3 class_dirs

  my @dirs = $setup->class_dirs;
  $setup->class_dirs(@dirs);

Gets or sets the list of directories that will be searched for classes that
inherit from C<Kinetic::Store::Base>. These will be passed to the
C<load_classes> method of L<Kinetic::Store::Schema|Kinetic::Store::Schema>; as
such, the final value in the list may optionally be a File::Find::Rule object.

=cut

sub class_dirs {
    my $self = shift;
    return @{ $self->{class_dirs} } unless @_;
    $self->{class_dirs} = \@_;
    return $self;
}

##############################################################################

=head2 Instance Methods

=head3 setup

  $setup->setup;

Sets up the data store. This is an abstract method that must be overridden in
the subclasses.

=cut

sub setup {
    throw_unimplemented [
        '"[_1]" must be overridden in a subclass',
        'setup'
    ];
}

##############################################################################

=head3 load_schema

  $setup->load_schema;

Loads a Kinetic::Store::Schema object with all of the libraries found in the
path specified by the C<source_dir> Kinetic::Build attribute.

Why? This loads an all of the libraries in an already installed Kinetic
platform, including, of course, the Kinetic system classes. Then a complete
database can be built including the system classes and the application
classes. That's really only useful for tests, though.

=cut

sub load_schema {
    my $self = shift;
    my $schema_class = $self->schema_class;
    eval "use $schema_class";
    require Carp && Carp::croak $@ if $@;

    my $sg = $schema_class->new;

    # Now load the classes to be installed.
    return $sg->load_classes($self->class_dirs);
}

##############################################################################

=head3 notify

  $setup->nofify('Looking good...', $/);

Outputs setup notification messages. It simply prints all messages to if the
C<verbose> attribute is true.

=cut

sub notify {
    my $self = shift;
    print @_ if $self->verbose;
    return $self;
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
