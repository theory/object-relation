package Kinetic::Store::Schema::DB;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Store::Schema';
use Kinetic::Store::Exceptions qw/throw_unimplemented/;

=head1 Name

Kinetic::Store::Schema::DB - Kinetic database data store schema generation

=head1 Synopsis

  use Kinetic::Store::Schema;
  my kbs = Kinetic::Store::Schema->new;
  $kbs->write_schema($file_name);

=head1 Description

This is an abstract base class for the generation and output of a database
schema to build a data store for a Kinetic application. See
L<Kinetic::Store::Schema|Kinetic::Store::Schema> for more information and the
subclasses of Kinetic::Store::Schema::DB for database-specific implementations.

=head1 Naming Conventions

The naming conventions for database objects are defined by the schema meta
classes. See L<Kinetic::Store::Meta::Class::Schema|Kinetic::Store::Meta::Class::Schema> and
L<Kinetic::Store::Meta::Attribute::Schema|Kinetic::Store::Meta::Attribute::Schema> for the
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
indexes constraints, etc. necessary to manage a class in a database. Pass in a
Kinetic::Store::Meta::Class object as the sole argument.

=cut

sub schema_for_class {
    my ( $self, $class ) = @_;
    return grep { $_ }
      map       { $self->$_($class) }
      qw(
      sequences_for_class
      tables_for_class
      indexes_for_class
      constraints_for_class
      procedures_for_class
      views_for_class
      insert_for_class
      update_for_class
      delete_for_class
      extras_for_class
    );
}

##############################################################################

=head3 sequences_for_class

  my $sequence_sql = $kbs->sequences_for_class($class);

This method takes a class object. By default it returns an empty list (or
C<undef> in a scalar context, but don't do that). Subclassses may use it to
return a C<CREATE SEQUENCE> statement for the class.

=cut

sub sequences_for_class { return }

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
    foreach my $attribute ( $class->collection_attributes ) {
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
have a column representing the attribute. Instead, another table representing
the relationship is created. This method will return the C<CREATE TABLE>
statement for that table.

=cut

sub collection_table {
    my ($self, $class, $attribute) = @_;
    return $self->format_coll_table(
        $attribute->collection_table,
        $class->key,
        $attribute->name,
    );
}

##############################################################################

=head3 format_coll_table

  my $table = $kbs->collection_table($table, $has_key, $had_key);

Called by C<collection_table()>, this method generates the actual C<CREATE
TABLE> statement. Pass in the name of the table, the key name of the class
that contains the collection, and the key name of the class of objects stored
in the collection. It creates a simple table declaration that includes the
C<PRIMARY KEY> expression, which is usable by most databases.

=cut

sub format_coll_table {
    my ($self, $table, $has_key, $had_key) = @_;
    return <<"    END_SQL";
CREATE TABLE $table (
    $has_key\_id INTEGER NOT NULL,
    $had_key\_id INTEGER NOT NULL,
    $had_key\_order SMALLINT NOT NULL,
    PRIMARY KEY ($has_key\_id, $had_key\_id)
);
    END_SQL
}

##############################################################################

=head3 collection_view

  my $coll_class = $attribute->collection_of;
  my $view       = $kbs->collection_view($class, $coll_class);

For an attribute which represents a collection of objects--for example,
attributes that have a C<has_many> relationship--this method returns a
C<CREATE VIEW> statement for the table created by the SQL returned by
C<collection_table()>.

=cut

sub collection_view {
    my ($self, $class, $attribute) = @_;;
    return $self->format_coll_view(
        $attribute->collection_view,
        $attribute->collection_table,
        $class->key,
        $attribute->name,
    );
}

##############################################################################

=head3 format_coll_view

  my $view = $kbs->collection_view($table, $has_key, $had_key);

Called by C<collection_view()>, this method generates the actual C<CREATE
VIEW> statement. Pass in the name of the table, the key name of the class
that contains the collection, and the key name of the class of objects stored
in the collection.

=cut

sub format_coll_view {
    my ($self, $view, $table, $has_key, $had_key) = @_;
    return <<"    END_SQL";
CREATE VIEW $view AS
  SELECT $has_key\_id, $had_key\_id, $had_key\_order
  FROM   $table;
    END_SQL
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
C<Kinetic::Store::Meta::Attribute> object passed to the method.

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

Pass in a Kinetic::Store::Meta::Attribute::Schema object to get back the column type
to be used for the attribute. This implementation simply returns the string
"TEXT" for all attributes, but may be overridden in subclasses to return
something more appropriate to particular attribute types.

=cut

sub column_type { return "TEXT" }

##############################################################################

=head3 column_null

  my $null_sql = $kbs->column_null($attr);

Pass in a Kinetic::Store::Meta::Attribute::Schema object to get back the null
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

Pass in a Kinetic::Store::Meta::Attribute::Schema object to get back the default
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

Pass in a Kinetic::Store::Meta::Attribute::Schema object to get back the SQL
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
the Kinetic::Store::Meta::Class::Schema object passed as its sole argument. If the
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
described by the Kinetic::Store::Meta::Class::Schema object passed as the sole
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
    my @attributes = $class->collection_attributes;
    return unless @attributes;
    my @indexes;
    my $class_key = $class->key;
    foreach my $attr (@attributes) {
        my $view     = $attr->collection_view;
        my $table    = $attr->collection_table;
        my $coll_key = $attr->name;
        push @indexes, "CREATE UNIQUE INDEX idx_$view "
                     . "ON $table "
                     . "($class_key\_id, $coll_key\_order);\n";
        push @indexes, "CREATE UNIQUE INDEX idx_$view\_$coll_key\_id "
                     . "ON $table "
                     . "($coll_key\_id);\n"
            if $attr->relationship eq 'has_many';
    }
    return @indexes;
}

##############################################################################

=head3 index_on

  my $column = $kbs->index_on($attr);

Returns the name of the column on which an index will be generated for the
given Kinetic::Store::Meta::Attribute::Schema object. Called by C<index_for_class()>.
May be overridden in subclasses to enclose the column name in SQL functions
and the like.

=cut

sub index_on { pop->column }

##############################################################################

=head3 constraints_for_class

  my $constraint_sql = $kbs->constraints_for_class($class);

Returns a list of the SQL statements to create all of the constraints for the
class described by the Kinetic::Store::Meta::Class::Schema object passed as the sole
argument.

This implementation actually returns C<undef> (or an empty list), but
may be overridden in subclasses to return constraint statements.

=cut

sub constraints_for_class {
    my ( $self, $class ) = @_;
    return;
}

##############################################################################

=head3 procedures_for_class

  my $constraint_sql = $kbs->procedures_for_class($class);

Returns a list of the SQL statements to create all of the procedures and/or
functions for the class described by the Kinetic::Store::Meta::Class::Schema object
passed as the sole argument.

This implementation actually returns C<undef> (or an empty list), but may be
overridden in subclasses to return procedure declarations.

=cut

sub procedures_for_class {
    my ( $self, $class ) = @_;
    return;
}

##############################################################################

=head3 views_for_class

  my $view_sql = $kbs->views_for_class($class);

Returns the SQL statement to create a database view for class described by the
Kinetic::Store::Meta::Class::Schema object passed as the sole argument. Views are the
main construct to access the attributes of a class. They will often
encapsulate inheritance relationships, so that consumer code does not have to
be aware of the inheritance relationship of tables when selecting or modify
the contents of an object. They will also often encapsulate the relationship
between an object and any other objects it contains ("has-a" relationships) by
including all of the attributes of the contained object in the view. This
approach makes selecting an object and all of its contained objects very easy
to do in a single C<SELECT> statement.

=cut

sub views_for_class {
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
    my @views = "CREATE VIEW $name AS\n"
        . "  SELECT $cols\n"
        . "  FROM   $from"
        . ( $where ? "\n  WHERE  $where;" : (';') ) . "\n";

    foreach my $attr ( $class->collection_attributes ) {
        push @views, $self->collection_view($class, $attr);
    }
    return @views;
}

##############################################################################

=head3 view_columns

  my @view_col_sql = $kbs->view_columns($table, $tables, $wheres, @attrs);

Used by the C<views_for_class()> method to generate and return the SQL
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

=head3 extras_for_class

  my @sql = $kbs->extras_for_class($class)

Returns a list of any extra SQL statements that need to be executed in order
to adequately represent a class in the database. By default, there are none,
so this method returns none. But subclasses may override it to provide extra
functionality.

=cut

sub extras_for_class { return }

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
Kinetic::Store::Meta::Class::Schema object passed as the sole argument. If the class
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
          $self->once_triggers_sql( $key, $attr, $table, $constraint );
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

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
