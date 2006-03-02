package Kinetic::Build::Schema::DB;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;

use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Build::Schema';
use Kinetic::Util::Exceptions qw/throw_unimplemented/;

=head1 Name

Kinetic::Build::Schema::DB - Kinetic database data store schema generation

=head1 Synopsis

  use Kinetic::Build::Schema;
  my kbs = Kinetic::Build::Schema->new;
  $kbs->write_schema($file_name);

=head1 Description

This is an abstract base class for the generation and output of a database
schema to build a data store for a Kinetic application. See
L<Kinetic::Build::Schema|Kinetic::Build::Schema> for more information and the
subclasses of Kinetic::Schema::DB for database-specific implementations.

=head1 Naming Conventions

The naming conventions for database objects are defined by the schema meta
classes. See L<Kinetic::Meta::Class::Schema|Kinetic::Meta::Class::Schema> and
L<Kinetic::Meta::Attribute::Schema|Kinetic::Meta::Attribute::Schema> for the
methods that define these names and documentation for the naming conventions.

=cut

##############################################################################
# Instance Interface
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 schema_for_class

  my @sql = $kbs->schema_for_class($class);

Returns a list of the SQL statements that can be used to build the tables,
indexes, and constraints necessary to manage a class in a database. Pass in a
Kinetic::Meta::Class object as the sole argument.

=cut

sub schema_for_class {
    my ( $self, $class ) = @_;
    return grep { $_ }
      map       { $self->$_($class) }
      qw(
      sequence_for_class
      tables_for_class
      indexes_for_class
      constraints_for_class
      view_for_class
      insert_for_class
      update_for_class
      delete_for_class
    );
}

##############################################################################

=head3 behaviors_for_class

  my @sql = $self->behaviors_for_class($class);

Takes a class object. Returns a list of SQL statements for:

=over 4

=item * indexes

  $kbs->indexes_for_class($class);

=item * constraints

  $kbs->constraints_for_class($class);

=item * view

  $kbs->view_for_class($class);

=item * inserts

  $kbs->insert_for_class($class);

=item * updates

  $kbs->update_for_class($class);

=item * deletes

  $kbs->delete_for_class($class);

=back

This is primarily a handy wrapper method for fetching these values all at once
when a schema is being created in a new database.

=cut

sub behaviors_for_class {
    my ( $self, $class ) = @_;
    return grep { $_ }
      map       { $self->$_($class) }
      qw(
      indexes_for_class
      constraints_for_class
      view_for_class
      insert_for_class
      update_for_class
      delete_for_class
    );
}

##############################################################################

=head3 sequence_for_class

  my $sequence_sql = $kbs->sequence_for_class($class);

This method takes a class object. By default it returns an empty string.
Subclassses may use it to return a C<CREATE SEQUENCE> statement for the class.

=cut

sub sequence_for_class { return '' }

##############################################################################

=head3 tables_for_class

  my $table_sql = $kbs->tables_for_class($class);

This method takes a class object. It returns a C<CREATE TABLE> SQL statement
for the class.

=cut

sub tables_for_class {
    my ( $self, $class ) = @_;
    my @tables;
    my $sql = $self->start_table($class);
    $sql .= "    " . join ",\n    ", $self->columns_for_class($class);
    $sql .= $self->end_table($class);
    push @tables, $sql;
    foreach my $attribute ( $class->attributes ) {
        next unless $attribute->collection_of;
        push @tables, $self->collection_table($class, $attribute);
    }
    return @tables;
}

##############################################################################

=head3 collection_table 

  my $coll_class = $attribute->collection_of;
  my $table      = $kbs->collection_table($class, $coll_class);

For an attribute which represents a collection of objects, for example,
attributes which have a C<has_many> relationship, the primary table will not
have a column representing the attribute.  Instead, another table representing
the relationship is created.  This method will return that table.

=cut

sub collection_table {
    throw_unimplemented [ 
        '"[_1]" must be overridden in a subclass',
        'collection_table'
    ];
}

##############################################################################

=head3 start_table

  my $start_table_sql = $kbs->start_table($class);

This method is called by C<tables_for_class()> to generate the opening
statement for creating a table.

=cut

sub start_table {
    my ( $self, $class ) = @_;
    my $table = $class->table;
    return "CREATE TABLE $table (\n";
}

##############################################################################

=head3 end_table

  my $end_table_sql = $kbs->end_table($class);

This method is called by C<tables_for_class()> to generate the closing
statement for creating a table.

=cut

sub end_table {
    return "\n);\n";
}

##############################################################################

=head3 collection_table_name

  my $name = $kbs->collection_table_name($main_class, $coll_class);

Given the primary class and the class for the collection, this method will
return the name of the collection table.

=cut

sub collection_table_name {
    my ($self, $class, $coll_class) = @_;
    return $class->key . "_coll_" . $coll_class->key;
}

##############################################################################

=head3 columns_for_class

  my @column_sql = $kbs->columns_for_class($class);

This method returns all of the columns necessary to represent a class in a
table.

=cut

sub columns_for_class {
    my ( $self, $class ) = @_;
    return (
        $self->pk_column($class),
        map { $self->generate_column( $class, $_ ) } $class->table_attributes
    );
}

##############################################################################

=head3 generate_column

  my $column_sql = $kbs->generate_column($class, $attr);

This method returns the SQL representing a single column declaration in a
table, where the column holds data represented by the
C<Kinetic::Meta::Attribute> object passed to the method.

=cut

sub generate_column {
    my ( $self, $class, $attr ) = @_;
    my $null = $self->column_null($attr);
    my $def  = $self->column_default($attr);
    my $fk   = $self->column_reference($attr);
    my $type = $self->column_type($attr);
    my $name = $attr->column;
    return "$name $type"
      . ( $null ? " $null" : '' )
      . ( $def  ? " $def"  : '' )
      . ( $fk   ? " $fk"   : '' );
}

##############################################################################

=head3 column_type

  my $type = $kbs->column_type($attr);

Pass in a Kinetic::Meta::Attribute::Schema object to get back the column type
to be used for the attribute. This implementation simply returns the string
"TEXT" for all attributes, but may be overridden in subclasses to return
something more appropriate to particular attribute types.

=cut

sub column_type { return "TEXT" }

##############################################################################

=head3 column_null

  my $null_sql = $kbs->column_null($attr);

Pass in a Kinetic::Meta::Attribute::Schema object to get back the null
constraint expression for the attribute. Returns "NOT NULL" if the attribute
is required, and an empty string if it is not required.

=cut

sub column_null {
    my ( $self, $attr ) = @_;
    return "NOT NULL" if $attr->required;
    return '';
}

##############################################################################

=head3 column_default

  my $default_sql = $kbs->column_default($attr);

Pass in a Kinetic::Meta::Attribute::Schema object to get back the default
value expression for the column for the attribute. Returns C<undef> (or an
empty list) if there is no default value on the column. Otherwise, it returns
the default value expression.

=cut

my %num_types = (
    integer => 1,
    whole   => 1,
    boolean => 1,
);

sub column_default {
    my ( $self, $attr ) = @_;
    my $def = $attr->{default};
    return unless defined $def && ref $def ne 'CODE';
    my $type = $attr->type;

    # Return the raw value for numeric data types.
    return "DEFAULT $def" if $num_types{$type};
    return "DEFAULT " . ( $def + 0 ) if $type eq 'state';

    # Return nothing if it's a reference.
    return if ref $def;

    # Otherwise, assume that it's a string.
    $def =~ s/'/''/g;
    return "DEFAULT '$def'";
}

##############################################################################

=head2 column_reference

  my $ref_sql = $kbs->column_reference($attr);

Pass in a Kinetic::Meta::Attribute::Schema object to get back the SQL
expression to create a foreign key relationship to another table for the given
attribute. Returns C<undef> (or an empty list) if the attribute is not a
reference to another object. Otherwise, it returns a simple reference
statement of the form "REFERENCES table(id) ON DELETE CASCADE" (where "table"
and "CASCADE" may vary). This method may be overridden in subclasses to return
C<undef> if they use named foreign key constraints, instead.


=cut

sub column_reference {
    my ( $self, $attr ) = @_;
    my $ref = $attr->references or return;
    my $fk_table = $ref->table;
    return "REFERENCES $fk_table(id) ON DELETE " . uc $attr->on_delete;
}

##############################################################################

=head3 pk_column

  my $pk_sql = $kbs->pk_column($class);

Returns the SQL statement to create the primary key column for the table for
the Kinetic::Meta::Class::Schema object passed as its sole argument. If the
class has a concrete parent class, the primary key column expression will
reference the primary key in the parent table. Otherwise, it will just define
the primary key for the current class.

=cut

sub pk_column {
    my ( $self, $class ) = @_;
    if ( my $parent = $class->parent ) {
        my $fk_table = $parent->table;
        return "id INTEGER NOT NULL PRIMARY KEY REFERENCES $fk_table(id) "
          . "ON DELETE CASCADE";
    }
    return "id INTEGER NOT NULL PRIMARY KEY";
}

##############################################################################

=head3 indexes_for_class

  my $index_sql = $kbs->indexes_for_class($class);

Returns the SQL statements to create all of the indexes for the class
described by the Kinetic::Meta::Class::Schema object passed as the sole
argument. All of the index declaration statements will be returned in a single
string, each separated by a "\n".

=cut

sub indexes_for_class {
    my ( $self, $class ) = @_;
    my @indexes = 
      map  { $self->index_for_attr( $class => $_ ) }
      grep { $_->index } 
      $class->table_attributes;
    return join q{}, @indexes, $self->_collection_indexes($class);
}

##############################################################################

=head3 index_for_attr

  my $index = $kbs->index_for_attr($class, $attr);

Returns the SQL that declares an SQL index. The default implementation here
uses the SQL standard index declaration, adding the C<UNIQUE> key word if the
attribute is a unique attribute, and using the C<index_on()> method to specify
the column to index.

=cut

sub index_for_attr {
    my ( $self, $class, $attr ) = @_;
    my $table  = $class->table;
    my $unique = $attr->unique ? ' UNIQUE' : '';
    my $name   = $attr->index($class);
    my $on     = $self->index_on($attr);
    return "CREATE$unique INDEX $name ON $table ($on);\n";
}

##############################################################################

=head3 _collection_indexes 

  my @collection_indexes = $kbs->_collection_indexes($class);

For a given class, this method will return all collection indexes for the
class.

=cut

sub _collection_indexes {
    my ( $self, $class ) = @_;
    my @collections = grep { $_ } map { $_->collection_of } $class->attributes;
    return unless @collections;
    my @indexes;
    my $class_key = $class->key;
    foreach my $coll (@collections) {
        my $coll_key = $coll->key;
        my $table    = $self->collection_table_name($class, $coll);
        push @indexes, "CREATE UNIQUE INDEX idx_$table "
                     . "ON $table "
                     . "($class_key\_id, $coll_key\_id, rank);\n";
    }
    return @indexes;
}

##############################################################################

=head3 index_on

  my $column = $kbs->index_on($attr);

Returns the name of the column on which an index will be generated for the
given Kinetic::Meta::Attribute::Schema object. Called by C<index_for_class()>.
May be overridden in subclasses to enclose the column name in SQL functions
and the like.

=cut

sub index_on { pop->column }

##############################################################################

=head3 constraints_for_class

  my $constraint_sql = $kbs->constraints_for_class($class);

Returns the SQL statements to create all of the constraints for the class
described by the Kinetic::Meta::Class::Schema object passed as the sole
argument. All of the constraint declaration statements will be returned in a
single string, each separated by a double "\n\n".

This implementation actually returns C<undef> (or an empty list), but
may be overridden in subclasses to return constraint statements.

=cut

sub constraints_for_class {
    my ( $self, $class ) = @_;
    return;
}

##############################################################################

=head3 view_for_class

  my $view_sql = $kbs->view_for_class($class);

Returns the SQL statement to create a database view for class described by the
Kinetic::Meta::Class::Schema object passed as the sole argument. Views are the
main construct to access the attributes of a class. They will often
encapsulate inheritance relationships, so that consumer code does not have to
be aware of the inheritance relationship of tables when selecting or modify
the contents of an object. They will also often encapsulate the relationship
between an object and any other objects it contains ("has-a" relationships) by
including all of the attributes of the contained object in the view. This
approach makes selecting an object and all of its contained objects very easy
to do in a single C<SELECT> statement.

=cut

sub view_for_class {
    my ( $self, $class ) = @_;
    my $key   = $class->key;
    my $table = $class->table;

    my ( @tables, @cols, @wheres );
    if ( my @parents = reverse $class->parents ) {
        my $prev;
        for my $parent (@parents) {
            push @tables, $parent->key;
            push @wheres, "$prev.id = $tables[-1].id" if $prev;
            $prev = $tables[-1];
            push @cols,
              $self->view_columns($prev, \@tables, \@wheres,
                $class->parent_attributes($parent) );

        }
        unshift @cols, "$tables[0].id AS id";
        push @wheres,  "$prev.id = $table.id";
    }
    else {
        @cols = ("$table.id AS id");
    }
    push @tables, $class->table;

    # Get all of the column names.
    push @cols, $self->view_columns(
        $table, \@tables, \@wheres, $class->table_attributes
    );

    my $cols  = join ', '    => @cols;
    my $from  = join ', '    => @tables;
    my $where = join ' AND ' => @wheres;
    my $name  = $class->key;

    # Output the view.
    return "CREATE VIEW $name AS\n"
        . "  SELECT $cols\n"
        . "  FROM   $from"
        . ( $where ? "\n  WHERE  $where;" : (';') ) . "\n";
}

##############################################################################

=head3 view_columns

  my @view_col_sql = $kbs->view_columns($table, $tables, $wheres, @attrs);

Used by the C<view_for_class()> method to generate and return the SQL
expressions for all of the columns used in a view. This method may be
called recursively to get all of the column names for all of the tables
referenced in a view, including parent tables and contained object tables.

The arguments are as follows:

=over

=item * $table

The name of the table for which we're currently defining the columns. This
may be used to create C<JOIN>s.

=item * $tables

A reference to an array of all the tables used in the view to the point that
C<view_columns()> was called. C<view_columns> may add new table names to
this array, so calling code must be sure to include them all in the view.

=item * $wheres

A reference to an array of all the C<WHERE> statements used in the view to the
point that C<view_columns()> was called. C<view_columns> may add new
C<WHERE> statements to this array, so calling code must be sure to include
them all in the view.

=item * @attrs

A list of the attributes to that correspond to columns in the table specified
by the C<$table> argument.

=back

=cut

sub view_columns {
    my ( $self, $table, $tables, $wheres ) = splice @_, 0, 4;
    my @cols;
    for my $attr (@_) {
        my $col = $attr->column;
        if ( my $ref = $attr->references ) {
            my $key = $ref->key;
            if ( $attr->required ) {
                # It will be an INNER JOIN.
                push @$tables, $key;
                push @$wheres, "$table.$col = $key.id";
            }

            else {
                # It will be a LEFT JOIN.
                my $join = "$table LEFT JOIN $key ON $table.$col = $key.id";

                # Either change the existing table name to the join table
                # syntax, or, if it is already joined to another table (and
                # therefore is not the whole string), then push the new join
                # string onto the table list.
                unless ( grep { s/^$table$/$join/ } @$tables ) {
                    push @$tables, $join;
                }
            }

            # Generate the list of columns for the VIEW query.
            push @cols, "$table.$col AS $key\__id",
                $self->_map_ref_columns( $ref, $key );
        }

        else {
            push @cols, "$table.$col AS " . $attr->view_column;
        }
    }
    return @cols;
}

##############################################################################

=begin private

=head1 Private Interface

=head3 Private Instance Methods

=head3 _map_ref_columns

  my @cols_sql = $kbs->_map_ref_columns($class, $key, $view_class, @keys);

This method is called by C<view_columns()> to create the column names for
contained objects in a view. It may be called recursively if the contained
object itself has one or more contained objects.

Contained object column names are the key name of the class, a double
underscore, and then the name of the column. The double underscore
distinguishes contained object column names from the columns for the primary
attributes of a class.

=cut

sub _map_ref_columns {
    my ( $self, $class, $key, @keys ) = @_;
    my @cols;
    my $ckey = @keys ? join ( '__', @keys, '' ) : ('');
    for my $attr ( $class->persistent_attributes ) {
        my $col = $attr->view_column;
        push @cols, "$key.$ckey$col AS $key\__$ckey$col";

        if ( my $ref = $attr->references ) {
            push @cols, $self->_map_ref_columns(
                $ref, $key, @keys, $ref->key
            );
        }
    }
    return @cols;
}

##############################################################################

=head3 once_triggers

  my $once_trigger_sql = $kbs->once_triggers($class);

Returns the triggers to validate the values of any "once" attributes in
the table representing the contents of the class represented by the
Kinetic::Meta::Class::Schema object passed as the sole argument. If the class
has no once attributes C<once_triggers()> will return C<undef> (or an empty
list).

Called by C<constraints_for_class()>.

Calls C<once_triggers_sql()> which must be overridden in a subclass to
generate database specific SQL.

=cut

sub once_triggers {
    my ( $self, $class ) = @_;
    my @onces = grep { $_->once } $class->table_attributes
      or return;
    my $table = $class->table;
    my $key   = $class->key;
    my @trigs;
    for my $attr (@onces) {
        my $col = $attr->column;

        # If the column is required, then the NOT NULL constraint will
        # handle that bit for us--no need to be redundant.
        my $constraint =
          $attr->required
          ? "OLD.$col <> NEW.$col OR NEW.$col IS NULL"
          : "OLD.$col IS NOT NULL AND (OLD.$col <> NEW.$col OR NEW.$col IS NULL)";
        push @trigs,
          $self->once_triggers_sql( $key, $col, $table, $constraint );
    }
    return join "\n", @trigs;
}

##############################################################################

=head3 once_triggers_sql

  my $once_triggers_sql_body = $kbs->once_triggers_sql(
    $key, $col, $table, $constraint
  );

This method is called by C<once_triggers()> to generate database specific
rules, functions, triggers, etc., to ensure that a column, once set to a
non-null value, can never be changed.

=cut

sub once_triggers_sql {
    throw_unimplemented [ '"[_1]" must be overridden in a subclass',
        'once_triggers_sql' ];
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
