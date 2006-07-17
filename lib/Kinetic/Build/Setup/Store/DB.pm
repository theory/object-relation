package Kinetic::Build::Setup::Store::DB;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Build::Setup::Store';

use DBI;
my %private;

=head1 Name

Kinetic::Build::Setup::Store::DB - Kinetic database store builder

=head1 Synopsis

See L<Kinetic::Build::Setup::Store|Kinetic::Build::Setup::Store>.

=head1 Description

This module inherits from Kinetic::Build::Setup::Store to function as the base class
for all store builder classes that builds a data store in a database. Its
interface is defined entirely by Kinetic::Build::Setup::Store.

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 dbd_class

  my $dbd_class = Kinetic::Build::Setup::Store::DB->dbd_class;

This abstract class method returns the name of the DBI database driver class,
such as "DBD::Pg" or "DBD::SQLite". Must be overridden in subclasses.

=cut

sub dbd_class {
    require Carp
        && Carp::croak "dbd_class() must be overridden in the subclass";
}

##############################################################################

=head3 dsn_dbd

  my $dsn_dbd = Kinetic::Build::Setup::Store::DB->dsn_dbd;

Returns the part of the database driver class name suitable for use in a
DBI DSN. By default, this method simply returns the value returned by
C<dbd_class()>, but with the leading "DBD::" stripped off.

=cut

sub dsn_dbd {
    (my $dbd = shift->dbd_class) =~ s/^DBD:://;
    return $dbd;
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 dsn

  my $dsn = $kbs->dsn;

This abstract method returns the DSN to be used by the Kinetic::Store::Handle::DB
subclass to connect to the database. Must be overridden in a subclass.

=cut

sub dsn { require Carp && Carp::croak "dsn() must be overridden in the subclass" }

##############################################################################

=head3 test_dsn

  my $test_dsn = $kbs->test_dsn;

This abstract method returns the DSN to be used by the Kinetic::Store::Handle::DB
subclass to connect to a test database while C<./Build test> is running. Must
be overridden in a subclass.

=cut

sub test_dsn { require Carp && Carp::croak "test_dsn() must be overridden in the subclass" }

##############################################################################

=head3 create_dsn

  my $create_dsn = $kbs->create_dsn;

Returns the DSN to be used to create the production database. By default, this
is the same as the value returned by C<dsn()>; override C<create_dsn()> to
change this behavior.

=cut

sub create_dsn { shift->dsn }

##############################################################################

=head3 build_db

Builds the database. Called as an action during C<./Build install>.

=cut

sub build_db {
    my $self = shift;
    my $sg   = $self->_load_schema;
    my $dbh  = $self->_dbh;

    $dbh->begin_work;
    eval {
        $dbh->do($_) for
            $sg->begin_schema,
            $sg->setup_code,
            (map { $sg->schema_for_class($_) } $sg->classes),
            $sg->end_schema;
        $dbh->commit;
    };

    if (my $err = $@) {
        $dbh->rollback;
        require Carp && Carp::croak $err;
    }

    return $self;
}

##############################################################################

=head3 build_test_db

Builds the test database. Called during C<./Build test>.

=cut

sub build_test_db {
    my $self = shift;
    # Let it default to building the entire database.
    $self->build_db;
}



##############################################################################

=head3 switch_to_db

This action switches the database connection for building a database to a
different database. Used when switching between a template database for
creating a new database, and the database to be built.

=cut

sub switch_to_db {
    my ($self, $db_name) = @_;
    $self->builder->db_name($db_name);
    $self->builder->notes(db_name => $db_name);
    $self->_dbh->disconnect if $self->_dbh;
    $self->_dbh(undef); # clear wherever we were
    return $self;
}

##############################################################################

=head3 disconnect_all

  $kbs->disconnect_all;

Disconnects all cached connections to the database server (that is, created by
calls to C<< DBI->connect_cached >> for the driver returned by C<dbd_class()>.
Used by C<test_cleanup()> methods and in other contexts.

=cut

sub disconnect_all {
    my $self = shift;
    my %drhs = DBI->installed_drivers;
    $_->disconnect for grep { defined }
        values %{ $drhs{$self->dsn_dbd}->{CachedKids} };
    return $self;
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _dbh

  $kbs->_dbh;

Returns the database handle to connect to the data store.

=cut

sub _dbh {
    my $self = shift;
    return $private{$self}->{dbh} unless @_;
    return $private{$self}->{dbh} = shift;
}

##############################################################################

=head3 _load_schema

  $kbs->_load_schema;
  $kbs->_load_schema($boolean);

Loads a Kinetic::Store::Schema object with all of the libraries found in the
path specified by the C<source_dir> Kinetic::Build attribute. If a true value
is passed, it will first load all of the libraries found in the
C<install_base> Kinetic::Build attribute.

Why? This loads an all of the libraries in an already installed Kinetic
platform, including, of course, the Kinetic system classes. Then a complete
database can be built including the system classes and the application
classes. That's really only useful for tests, though.

=cut

sub _load_schema {
    my ($self, $load_installed) = @_;
    my $schema_class = $self->schema_class;
    eval "use $schema_class";
    require Carp && Carp::croak $@ if $@;

    my $sg      = $schema_class->new;
    my $builder = $self->builder;

    # Load the installed classes first.
    if ($load_installed) {
        (my $base = $builder->install_base) =~ s{/?$}{/lib};
        $sg->load_classes($base);
    }

    # Now load the classes to be installed.
    return $sg->load_classes($builder->source_dir);

}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
