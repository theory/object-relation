# $Id$

=head1 Name

Object::Relation::Handle::DB::SQLite::DBI - DBI subclass adding funtions to SQLite

=head1 Synopsis

  my $dbh = Object::Relation::Handle::DB::SQLite::DBI->connect(...);

=head1 Description

This class subclasses the L<DBI|DBI> to add custom functions and aggregates
to the SQLite interface. These functions can then simply be used in SQLite
queries.

=cut

package Object::Relation::Handle::DB::SQLite::DBI;
use base 'DBI';
our $VERSION = '0.11';

package Object::Relation::Handle::DB::SQLite::DBI::st;
use base 'DBI::st';
our $VERSION = '0.11';

package Object::Relation::Handle::DB::SQLite::DBI::db;
use base 'DBI::db';
use strict;
use Object::Relation::Functions ();
our $VERSION = '0.11';

=head1 Interface

=head2 Functions

=head3 coll_set

  SELECT coll_set('blog_entry', 1, 'tag', '3,14,12,56,2,33');

This function sets all of the objects in a collection. Think C<@coll =
(@ids)>. Any pre-existing objects in the collection that are not in the new
list of objects will be discarded. Existing objects that I<are> in the new
list will remain in the same row in the database, but may have their order
column updated as appropriate. In the above example, the tag collection
associated with blog entry ID 1 will contain the tags with the IDs 3, 14, 12,
56, 2, and 33 in that order.

=cut

sub coll_set {
    my ($dbh, $obj_key, $obj_id, $coll_of, $coll_ids) = @_;
    my $order = 0;
    my $table = "_$obj_key\_coll_$coll_of";

    # We'll need this in a bit.
    my $ins = $dbh->prepare(qq{
        INSERT INTO $table ($obj_key\_id, $coll_of\_id, $coll_of\_order)
        VALUES (?, ?, ?)
    });

    # First, negate the order of existing rows.
    my $updated = $dbh->do(qq{
        UPDATE $table
        SET    $coll_of\_order = -$coll_of\_order
        WHERE  $obj_key\_id = ?
    }, undef, $obj_id);

    if ($updated > 0) {
        # There are existing records. We'll try updating each one, first.
        my $upd = $dbh->prepare(qq{
            UPDATE $table
            SET    $coll_of\_order = ?
            WHERE  $obj_key\_id = ?
                   AND $coll_of\_id = ?
        });

        for my $coll_id (split /,/, $coll_ids) {
            # If no row is updated, insert it.
            unless ($upd->execute(++$order, $obj_id, $coll_id) > 0) {
                $ins->execute($obj_id, $coll_id, $order);
            }
        }

        # Now delete any remaining rows.
        $dbh->do(qq{
            DELETE FROM $table
            WHERE  $obj_key\_id = ?
                   AND $coll_of\_order < 0
        }, undef, $obj_id);
    }

    else {
        # There are no existing records, so just insert them.
        $ins->execute($obj_id, $_, ++$order) for split /,/, $coll_ids;
    }
}

##############################################################################

=head3 coll_add

  SELECT coll_add('blog_entry', 1, 'tag', '4,3,5,14');

This function adds a list of objects to a collection. Think C<push @coll,
@ids>. Any existing objects in the collection will remain unmolested. If any
of the IDs to be added already exist in the collection, they will remain in
the same row and will retain their existing ordering. Otherwise, new IDs will
be added, with their ordering starting with the next number after the highest
order number currently stored in the database for the object.

In the above example, the tag IDs 4, 3, 5, and 14 will be added in that order
to the collection for the blog entry with the ID 1.

=cut

sub coll_add {
    my ($dbh, $obj_key, $obj_id, $coll_of, $coll_ids) = @_;
    my $table = "_$obj_key\_coll_$coll_of";

    my @to_add = split /,/, $coll_ids or return;
    my $placeholders = join ', ', ('?') x @to_add;

    # Determine the IDs already stored.
    my $existing = $dbh->selectcol_arrayref(qq{
        SELECT $coll_of\_id
        FROM   $table
        WHERE  $obj_key\_id = ?
               AND $coll_of\_id IN($placeholders)
    }, undef, $obj_id, @to_add);

    # Filter out the existing ones from the new ones.
    if (@$existing) {
        @to_add = grep {
            my $id = $_;
            !first { $id == $_ } @$existing
        } @to_add;
    }
    return unless @to_add;

    # Get the current maximum value.
    my ($max) = $dbh->selectrow_array(qq{
        SELECT COALESCE(MAX($coll_of\_order), 0)
        FROM   $table
        WHERE  $obj_key\_id = ?
    }, undef, $obj_id);

    # Add the new IDs. Yes, there's a race condition, but there's nothing
    # we can do about that with SQLite.
    my $ins = $dbh->prepare(qq{
        INSERT INTO $table ($obj_key\_id, $coll_of\_id, $coll_of\_order)
        VALUES (?, ?, ?)
    });
    $ins->execute($obj_id, $_, ++$max) for @to_add;
}

##############################################################################

=head3 coll_del

  SELECT coll_del('blog_entry', 1, 'tag', '3,12,56,2');

This function deletes a specific list of objects from a collection. Think
C<delete @coll{@ids}>. In the above exmple, it would delete the tags with the
IDs 3, 12, 56, and 2 from the collection of tags associated with the blog
entry with the ID 1.

=cut

sub coll_del {
    my ($dbh, $obj_key, $obj_id, $coll_of, $coll_ids) = @_;
    my @to_del = split /,/, $coll_ids;
    my $placeholders = join ', ', ('?') x @to_del;
    $dbh->do(qq{
        DELETE FROM _$obj_key\_coll_$coll_of
        WHERE  $obj_key\_id = ?
               AND $coll_of\_id IN ($placeholders)
    }, undef, $obj_id, @to_del);
}

##############################################################################

=head3 coll_clear

  SELECT coll_clear('blog_entry', 1, 'tag');

This function clears a collection from the datatabse. Think C<@coll = ()>. In
the above example, it would delete all of the tags in the collection of tags
associated with the blog entry with the ID 1.

=cut

sub coll_clear {
    my ($dbh, $obj_key, $obj_id, $coll_of) = @_;
    $dbh->do(qq{
        DELETE FROM _$obj_key\_coll_$coll_of
        WHERE  $obj_key\_id = ?
    }, undef, $obj_id);
}

##############################################################################

=head3 UUID_V4

  SELECT UUID_V4();

This function uses the C<create_uuid()> function from
L<Object::Relation::Functions|Object::Relation::Functions> to create a new UUID.

=head3 regexp

  SELECT regexp('^foo', 'food');

  SELECT name, rank
  FROM   soldier
  WHERE  name REGEXP '^Larry';

This function adds the full power of Perl regular expresions to SQLite. The
regular expression is the first argument, and the string to be matched against
is the second argument. All comparisons are case-insensitive.

Conveniently, the mere presence of this function allows the SQLite C<REGEXP>
operator to work, as well. See
L<http://www.justatheory.com/computers/databases/sqlite/add_regexen.html>.

=head3 isa_gtin

  SELECT isa_gtin('4007630000116');

Examines the value passed to it to determine whether or not it is a valid
GTIN. Imported from L<Object::Relation::Functions|Object::Relation::Functions>.

=head2 Methods

=head3 connected

=cut

sub connected {
    my $dbh = shift;
    return if exists $dbh->{private_ObjectRelationSQLite_functions};
    my $func = 'create_function';

    # Add UUID_V4() function.
    $dbh->func(
        'UUID_V4',
        0,
        \&Object::Relation::Functions::create_uuid,
        $func,
    );

    # Add regexp() function for use by REGEXP operator. See
    # http://www.justatheory.com/computers/databases/sqlite/add_regexen.html
    $dbh->func('regexp', 2, sub {
        my ($regex, $string) = @_;
        return $string =~ /$regex/ixms;
    }, $func);

    # Add collection functions.
    $dbh->func('coll_clear', 3, sub { coll_clear($dbh, @_ ) }, $func);
    $dbh->func('coll_del',   4, sub { coll_del(  $dbh, @_ ) }, $func);
    $dbh->func('coll_add',   4, sub { coll_add(  $dbh, @_ ) }, $func);
    $dbh->func('coll_set',   4, sub { coll_set(  $dbh, @_ ) }, $func);

    # Add isa_gtin() function.
    $dbh->func(
        'isa_gtin',
        1,
        \&Object::Relation::Functions::isa_gtin,
        $func
    );

    # Make sure that we don't do this again.
    $dbh->{private_ObjectRelationSQLite_functions} = 1;
}

1;
__END__

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
