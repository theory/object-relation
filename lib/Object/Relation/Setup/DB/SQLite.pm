package Object::Relation::Setup::DB::SQLite;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.1.0');

use base 'Object::Relation::Setup::DB';
use aliased 'Object::Relation::Language';
use Object::Relation::Exceptions qw(
    throw_unsupported
    throw_io
);

=head1 Name

Object::Relation::Setup::DB::SQLite - Object::Relation SQLite data store setup

=head1 Synopsis

See L<Object::Relation::Setup|Object::Relation::Setup>.

=head1 Description

This module inherits from Object::Relation::Setup::DB to build a SQLite set up
store.

=head1 Class Interface

=head2 Constructors

=head3 new

  my $sqlite_setup = Object::Relation::Setup::DB::SQLite->new(\%params);

The constructor inherits from
L<Object::Relation::Setup::DB|Object::Relation::Setup:::DB>, but detects when the
C<dsn> attribute isn't set, and sets it to a default value. The database file
in that value will be F<obj_rel.db> and will live in the directory returned by
C<File::Temp::tempdir()>.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    unless ($self->dsn) {
        require File::Spec;
        $self->dsn(
            'dbi:SQLite:dbname='
            . File::Spec->catfile(File::Spec->tmpdir, 'obj_rel.db')
        );
    }
    return $self;
}

##############################################################################

=head2 Class Methods

=head3 connect_attrs

  DBI->connect(
      $dsn, $user, $pass,
      { Object::Relation::Setup::DB::SQLite->connect_attrs }
  );

Returns a list of arugments to be used in the attributes hash passed to the
DBI C<connect()> method. Overrides that provided by
L<Object::Relation::Setup::DB|Object::Relation::Setup::DB> to add
C<< unicode => 1 >>.

=cut

sub connect_attrs {
    return (
        shift->SUPER::connect_attrs,
        unicode => 1,
    );
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 setup

  $setup->setup;

Sets up the data store. This implementation simply constructs a database
handle and assigns it to the C<dbh> attribute, and then calls
C<SUPER::setup()> to let Object::Relation::Setup::DB handle the bulk of the
work.

=cut

sub setup {
    my $self    = shift;
    my $dbh     = $self->connect;
    my $verbose = $self->verbose;
    my $lang    = Language->get_handle;

    # Check the version of SQLite.
    $self->notify($lang->maketext('Do we have the proper version of SQLite?'));
    my $req = version->new('3.2.0');
    my $got = version->new($dbh->{sqlite_version});
    throw_unsupported [
        '[_1] is compiled with [_2] [_3] but we require version [_4]',
        'DBD::SQLite',
        'SQLite',
        $got,
        $req,
    ] if $got < $req;
    $self->notify(' ', $lang->maketext('Yes'), $/);

    # Set the database handle and send it on up.
    $self->dbh($dbh);
    $self->SUPER::setup;
    $self->dbh(undef);
}

##############################################################################

=head3 teardown

  $kbs->teardown;

Tears down the database by disconnecting all database connections and deleting
the database file, which is extracted from the DSN.

=cut

sub teardown {
    my $self = shift;
    $self->disconnect_all;
    (my $file = $self->dsn) =~ s/.+dbname=//;
    unlink $file or throw_io [ 'Cannot delete "[_1]": [_2]', $file, $! ];
    return $self;
}

##############################################################################

1;
__END__

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

