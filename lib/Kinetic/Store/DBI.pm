package Kinetic::Store::DBI;

# $Id$

use strict;
use base qw(Kinetic::Store);
use Kinetic::Collection;
use Kinetic::DBCatalog;
use DBI;
use Exception::Class::DBI;
use Scalar::Util qw(blessed);

=head1 Name

Kinetic::Store::DBI - The Kinetic storage API implemented with DBI/SQL

=head1 Synopsis

  use Kinetic::Store;

  my $store = Kinetic::Store::DBI->connect($dsn, $user, $pw);

  my $coll = $store->search('Kinetic::SubClass' =>
                            attr => 'value');

=head1 Description

This class implements the Kinetic storage API using DBI to
communicate with an RDBMS.  RDBMS specific behavior is implemented via
the C<Kinetic::Store::DBI::Pg> and C<Kinetic::Store::DBI::mysql>
classes.

=cut

{
    package Kinetic::Store::DBI::Search;

    sub string_val { ${$_[0]} }

    @Kinetic::Store::DBI::Search::Inline::ISA  = 'Kinetic::Store::DBI::Search';
    @Kinetic::Store::DBI::Search::Compare::ISA = 'Kinetic::Store::DBI::Search';
}

BEGIN {
    foreach my $sub ([AND => 'AND'],
                     [OR  => 'OR'],
                     [OPEN_PAREN  => '('],
                     [CLOSE_PAREN => ')'],
                    )
    {
        my $obj = bless \$sub->[1], 'Kinetic::Store::DBI::Search::Inline';

        no strict 'refs';
        *{$sub . '_C'} = sub () { $obj };
    }

    foreach my $sub (qw(NOT LIKE GT LT GE LE)) {
        my $val = $sub;
        my $obj = bless \$val, 'Kinetic::Store::DBI::Search::Compare';

        no strict 'refs';
        *{$sub . '_C'} = sub () { $obj };
    }
}

sub connect {
    my ($class, $dsn, $user, $pw) = @_;

    my $dbh = DBI->connect($dsn, $user, $pw,
                           {HandleError => Exception::Class::DBI->handler,
                            ShowErrorStatement => 1});

    my $driver = $dbh->{Driver}{Name};

    my $subclass = "Kinetic::Store::DBI::$driver";
    eval "require $subclass";

    return bless { dbh => $dbh }, $subclass;
}

sub AND  { shift; AND_C(), OPEN_PAREN(), @{$_[0]}, CLOSE_PAREN() }
sub OR   { shift; OR_C(), OPEN_PAREN(), @{$_[0]}, CLOSE_PAREN() }

sub NOT  { shift; NOT_C(), @_ }
sub LIKE { shift; LIKE_C(), @_ }
sub GT   { shift; GT_C(), @_ }
sub LT   { shift; LT_C(), @_ }
sub GE   { shift; GE_C(), @_ }
sub LE   { shift; LE_C(), @_ }

sub lookup {
    my $self = shift;
    my $target = shift;
    my ($key, $value) = @_;

    my $sql = 'SELECT * FROM ';
    $sql .= Kinetic::DBCatalog->class_to_table($target);
    $sql .= ' WHERE ';

    if ($key eq 'guid') {
        # or could this be something like person_id ??
        $sql .= 'guid = ?';
    } else {
        # check to see that $key is actually an attribute of the
        # target class

        $sql .= "$key = ?";
    }

    my $sth = $self->_make_sth(sql  => $sql, bind => $value);

    # Assume FetchHashKeyName was set to NAME_lc when DBI handle was
    # constructed
    my $row = $sth->fetchrow_hashref;

    return unless $row;

    # How are objects constructed?
    return $target->new(data => $row);
}

sub search {
    my $self = shift;

    my ($sql, $bind) = $self->_search(select => '*', params => \@_);

    my $sth = $self->_make_sth(sql => $sql, bind => $bind);

    return Kinetic::Collection::Sth->new(return => $_[0], sth => $sth);
}

sub list_guids {
    my $self = shift;

    my ($sql, $bind) = $self->_search(select => 'guid', params => \@_);

    my $ids = $self->{dbh}->selectcol_arrayref($sql, {}, @$bind);

    return wantarray ? @$ids : $ids;
}

# the real implementation of anything that provides search parameters
# & options
sub _search {
    my ($self, $select, $params) = @_;

    my ($target, $search, $options) = $self->SUPER::_search_params(@$params);

    my $table = Kinetic::DBCatalog->class_to_table($target);

    my $select_clause = "SELECT $table.$select ";

    my ($join_tables, $where, $bind) =
        $self->_search_elements($target, $search, $options);

    my ($sort_tables, $sort_and_limit) =
        $self->_process_options($table, $options);

    my $tables = join ', ', sort (keys %$join_tables, keys %$sort_tables);
    my $sql .= <<"EOF";
$select_clause
FROM $tables
WHERE $where
$sort_and_limit
EOF

    return ($sql, $bind);
}

# will be called from Kinetic::Store->_search_params
sub _expand_search_modifier {
    my ($self, $mod) = @_;

    my $name = shift @$mod;

    return $self->$name(@$mod);
}

sub _search_elements {
    my ($self, $target, $search) = @_;

    my %tables;
    my @where;
    my @bind;

    while (@$search) {

        my ($k, $v, $has_not, $operator) = $self->_get_next_search(\@where, $search);

        my ($table, $column, $type);

        if ($k =~ /\./ || $target->attr_is_object($k)) {
            my ($attr, $foreign_attr);

            if ($k =~ /\./) {
                ($attr, $foreign_attr) = split /\./, $k;
            } else {
                ($attr, $foreign_attr) = ($k, 'guid');
            }

            my $related_class = $target->class_for_attr($attr);

            if (! blessed $v) {
                if (ref $v) {
                    my @new_v;
                    for (@$v) {
                        die "Must provide an object (or objects) of the proper class ($related_class) for search attribute $attr in $target"
                            unless UNIVERSAL::isa($_, $related_class);

                        push @new_v, $_->get_guid;
                    }

                    $v = \@new_v;
                } else {
                    # not a blessed ref, must be bad
                    die "Must provide an object (or objects) for search attribute $attr in $target";
                }
            } else {
                die "Must provide an object (or objects) of the proper class ($related_class) for search attribute $attr in $target"
                    unless UNIVERSAL::isa($v, $related_class);
                $v = $v->get_guid;
            }

            $table = Kinetic::DBCatalog->class_to_table($related_class);

            $column =
                Kinetic::DBCatalog->attribute_to_column($related_class, $foreign_attr);

            $type = Kinetic::DBCatalog->column_type($column);

            $tables{$table} = 1;

            my $from_column = Kinetic::DBCatalog->attribute_to_column($target, $attr);
            my $from_table = Kinetic::DBCatalog->class_to_table($target);

            my $to_column = Kinetic::DBCatalog->foreign_column($from_column);

            push @where, "$from_table.$from_column = $table.$to_column";
        } else {
            $table = Kinetic::DBCatalog->class_to_table($target);

            $column = Kinetic::DBCatalog->attribute_to_column($target, $k);

            $type = Kinetic::DBCatalog->column_type($column);
        }

        if (blessed $v || ! ref $v) {
            if (defined $v) {
                my $comp =
                    $self->_comparison_operator_for_single($has_not, $operator);

                push @where, "$table.$column $comp ?";
            } else {
                my $not = $has_not ? 'NOT' : '';
                push @where, "$table.$column IS $not NULL";
            }

            # At this point, the only blessed value should be a
            # DateTime object, which will stringify
            push @bind, $v;
        } else {
            my $not = $has_not ? ' NOT' : '';

            if (@$v == 2) {
                push @where, "$not ($table.$column >= ? AND $table.$column < ?)";
            } else {
                my $in = '(';
                $in .= join ', ', ('?') x @$v;
                $in .= ')';

                push @where, "$not ($table.$column IN $in)";
            }

            push @bind, @$v;
        }
    }

    my $where = join ' ', @where;

    return (\%tables, $where, \@bind);
}

sub _get_next_search {
    my ($self, $where, $search) = @_;

    my $k = shift @$search;

    if (ref $k) {
        # If the first element we look at is a ref, it should be
        # something returned from one of the search functions like
        # 'AND' or 'OR'.  Anything else should be a key for a
        # key/value pair, where the key is always a string, and the
        # value may be a number of things.
        die "Bad search params"
            unless UNIVERSAL::isa($k, 'Kinetic::Store::Search::Inline');

        push @$where, $k->string_value;

        next;
    } else {
        push @$where, 'AND'
            if @$where;
    }

    my $v = shift @$search;

    my $has_not;
    my $operator;

    while (UNIVERSAL::isa($v, 'Kinetic::Store::DBI::Search::Compare')) {
        if ($v->string_val eq 'NOT') {
            $has_not = 1;
        } elsif ($operator) {
            die "Cannot combine multiple search modifiers\n";
        } else {
            $operator = $v->string_val;
        }

        $v = shift @$search;
    }

    return ($k, $v, $has_not, $operator);
}

# LIKE (and its inverse) are handled in subclasses
my %operator = ('GT' => '>',
                'LT' => '<',
                'GE' => '>=',
                'LE' => '<=',

                '='  => '=',

                'SQL_LIKE' => 'LIKE',
               );

my %inverse = ('GT' => '<=',
               'LT' => '>=',
               'GE' => '<',
               'LE' => '>',

               '='  => '!=',

               'SQL_LIKE' => 'NOT LIKE',
              );

sub _comparison_operator_for_single {
    my ($self, $has_not, $operator, $type) = @_;

    $operator ||= $type eq 'string' ? 'SQL_LIKE' : '=';

    if ($has_not) {
        return $inverse{$operator};
    } else {
        # Operator, operator, hook me up to my lover on the end of the
        # line ...
        return $operator{$operator};
    }
}

sub _options {
    my ($self, $target, $table, $options) = @_;

    my %tables;
    my $sort_and_limit = '';

    if ($options->{order_by}) {
        my ($ob_table, $ob_column);

        if ($options->{order_by} =~ /\./) {
            my ($attr, $foreign_attr) = split /\./, $options->{order_by};

            my $related_class = $target->class_for_attr($attr);

            $ob_table = Kinetic::DBCatalog->class_to_table($related_class);

            $ob_column =
                Kinetic::DBCatalog->attribute_to_column($related_class, $foreign_attr);

            $tables{$ob_table} = 1;
        } else {
            $ob_table = $table;

            $ob_column =
                Kinetic::DBCatalog->attribute_to_column($target, $options->{order_by});
        }

        $sort_and_limit .= " ORDER BY $ob_table.$ob_column ";

        $sort_and_limit .= $options->{sort_order} || 'ASC';
    }

    if ($options->{limit} || $options->{offset}) {
         $sort_and_limit .= $self->_limit_clause(@{ $options }{ 'limit', 'offset' });
    }

    return (\%tables, $sort_and_limit);
}

# MySQL supports this syntax as of version 4.0.6 - may need to be
# overridden if we ever support Oracle (which has no limit syntax!)
sub _limit_clause {
    my ($self, $limit, $offset) = @_;

    $limit ||= 0; # no undefs

    my $limit_clause = " LIMIT $limit";
    $limit_clause .= " OFFSET $offset" if $offset;

    return $limit_clause;
}
