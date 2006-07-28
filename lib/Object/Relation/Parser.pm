package Object::Relation::Parser;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.1.0');

use Exporter::Tidy default => ['parse'];
use HOP::Stream qw/drop list_to_stream/;
use HOP::Parser qw/:all/;
use Scalar::Util 'blessed';
use List::Util 'first';

use Object::Relation::DataType::DateTime::Incomplete qw/is_incomplete_iso8601/;
use Object::Relation::Search;
use Object::Relation::Exceptions qw/panic throw_search isa_exception/;

=head1 Name

Object::Relation::Parser - The Object::Relation parser for search requests

=head1 Synopsis

  use Object::Relation::Parser      qw/parse/;
  use Object::Relation::Lexer::Code qw/lexer_stream/;

  sub _create_ir {
      my ($self, $search_request) = @_;
      my $stream                      = lexer_stream($search_request);
      my $intermediate_representation = parse($stream, $store);
      return $intermediate_representation;
  }

=head1 Description

This class takes the tokens produced by a Object::Relation lexer and creates an
intermediate representation that can be easily converted to a search request
for a given store.

=cut

# predefine a few things
my $lparen    = match( OP => '(' );
my $rparen    = match( OP => ')' );
my $lbracket  = match( OP => '[' );
my $rbracket  = match( OP => ']' );
my $fat_comma = match( OP => '=>' );
my $comma     = match( OP => ',' );
my $either_comma = alternate( $fat_comma, $comma );
my $search_value = match('VALUE');

#
# Declare parsers
#

my ( $search, $value, $normal_value, $between_value, $any, $statement,
    $statement_list, $statements );

#
# Eta-conversion
#
# This fails:
#
#   my $search;
#   $search = some_parser($search);
#
# It fails because search is not defined at the time some_parser is called.
# So we create a second parser to refer to the first and the second parser
# calls the first parser with "parser { $search->(@_) }".  This delays the
# evaluation of $search until it's actually used, thus ensuring it has data.
# This is called "eta-conversion."
#
# For the various grammar rules, use the lower-case version ($search) for the
# LHS and the upper-case version ($Search) the RHS.
#
# This has the additional advantage of allowing us to arrange the grammar
# rules in any order.
#

my $Search         = parser { $search->(@_) };
my $Value          = parser { $value->(@_) };
my $Normal_value   = parser { $normal_value->(@_) };
my $Between_value  = parser { $between_value->(@_) };
my $Any            = parser { $any->(@_) };
my $Statement      = parser { $statement->(@_) };
my $Statements     = parser { $statements->(@_) };
my $Statement_list = parser { $statement_list->(@_) };

#
# Grammar
#

#  entire_input   ::= statements 'End_Of_Input'

my $entire_input =
  error( T( concatenate( $Statements, \&End_of_Input ), sub { $_[0] } ) );

#  statements     ::= statement | statement ',' statements

$statements =
  T( list_values_of( $Statement, $comma ),
    sub { [ _extract_statements(@_) ] } );

#  statement      ::= statement_list
#                   | 'AND' '(' statement_list ')'
#                   | 'OR'  '(' statement_list ')'

my $and_or = alternate( match( KEYWORD => 'AND' ), match( KEYWORD => 'OR' ) );

$statement = T(
    alternate(
        $Statement_list,
        concatenate(
            $and_or, absorb($lparen), $Statement_list, absorb($rparen)
        ),
    ),
    sub { \@_ }
);

#  statement_list ::= search
#                   | search ','                      # allow trailing commmas
#                   | search ',' statement
#                   | search ',' statement ','        # allow trailing commmas

$statement_list = concatenate(
    $Search,
    star( rlist_values_of( $Statement, $comma ) ),
    absorb( optional($comma) ),    # allow a trailing comma
);

#  search         ::= identifier '=>'       normal_value
#                   | identifier '=>' 'NOT' normal_value
#                   | identifier '=>'       between_value
#                   | identifier '=>' 'NOT' between_value
#                   | identifier            normal_value
#                   | identifier      'NOT' normal_value
#                   | identifier            between_value
#                   | identifier      'NOT' between_value

$search = T(
    concatenate(
        match('IDENTIFIER'),
        absorb( optional($fat_comma) ),
        optional( match( KEYWORD => 'NOT' ) ),
        alternate( $Normal_value, $Between_value )
    ),
    sub { _make_search(@_) }
);

#  normal_value   ::= value | compare value | any

$normal_value =
  T( alternate( concatenate( optional( match('COMPARE') ), $Value ), $Any ),
    sub { [ $_[0][0], $_[1] ] } );

#  note that parenthese are allowed for "BETWEEN" searches.  This allows
#  STRING searches to do this:
#    age BETWEEN (21, 40)

#  between_value  ::= 'BETWEEN' '[' value ','  value ']'
#                   | 'BETWEEN' '[' value '=>' value ']'
#                   |           '[' value ','  value ']'
#                   |           '[' value '=>' value ']'
#                   | 'BETWEEN' '(' value '=>' value ')'
#                   | 'BETWEEN' '(' value ','  value ')' # BETWEEN is not optional when using parens

$between_value = T(
    alternate(
        concatenate(
            absorb( optional( match( KEYWORD => 'BETWEEN' ) ) ),
            absorb($lbracket), $Value, absorb($either_comma), $Value,
            absorb($rbracket),
        ),
        concatenate(
            absorb( match( KEYWORD => 'BETWEEN' ) ),
            absorb($lparen), $Value, absorb($either_comma), $Value,
            absorb($rparen),
        ),
    ),
    sub {
        [ 'BETWEEN', [ map { _normalize_value($_) } @_ ] ];
    }
);

#  any            ::= 'ANY' '(' any_list ')'
#
#  any_list       ::= search_value
#                   | search_value ','  any_list
#                   | search_value '=>' any_list
#                   | search_value ','  any_list ','  # allow trailing commas
#                   | search_value '=>' any_list '=>' # allow trailing commas
#

$any = T(
    concatenate(
        absorb( match( KEYWORD => 'ANY' ) ),
        absorb($lparen),
        $Value,
        rlist_values_of( $search_value, $either_comma ),
        absorb( optional($comma) ),    # allow a trailing comma
        absorb($rparen),
    ),
    sub {

        # any is in an arrayref because $normal_value has
        # optional(match('COMPARE'))
        # and that returns the keyword in an arrayref
        [
            ['ANY'],
            [
                _normalize_value(shift),
                map { _normalize_value($_) } @{ +shift }
            ]
        ];
    }
);

#  value          ::= search_value | undef

$value = alternate( $search_value, absorb( match('UNDEF') ) );

sub _extract_statements {
    my $stream = list_to_stream(@_);
    my @statements;

    while ( defined( my $head = drop($stream) ) ) {
        if ( 'ARRAY' eq ref $head ) {
            push @statements => _extract_statements($head);
        }
        elsif ( 'OR' eq $head ) {
            push @statements => 'OR', [ _extract_statements($stream) ];
            undef $stream;
        }
        elsif ( 'AND' eq $head ) {
            push @statements => [ 'AND', _extract_statements($stream) ];
            undef $stream;
        }
        else {
            push @statements => $head;
        }
    }
    return @statements;
}

##############################################################################
# Public Interface
##############################################################################

=head2 Exportable functions

=head3 parse

  my $ir = parse($stream, $store);

This function takes a lexer stream produced by a Object::Relation lexer and the store
object to be searched. It returns an intermediate representation suitable for
converting into a data store search (such as a SQL C<WHERE> clause).

This function returns an array reference of
L<Object::Relation::Search|Object::Relation::Search> objects and groups of these
Search objects. Groups may be simple groups, "AND" groups or "OR" groups.

=over 4

=item Simple groups

Simple groups are merely a reference to an array of search objects:

  [
    $search1,
    $search2,
    $search3,
  ]

All searches in a simple group must succeed for the search to succeed.

=item AND groups

"AND" groups are array references with the string "AND" as the first element.

  [
    [
      'AND',
      $search2,
      $search3,
    ]
  ]

=item OR groups

An "OR" group is the string "OR" followed by an array reference.

  [
    'OR',
    [
      $search1,
      $search2,
    ]
  ]

=item Nested groups

And of the above groups may be nested.

    AND(
        name   => 'foo',
        l_name => 'something',
    ),
    OR( age => GT 3 ),
    OR(
        one__type  => LIKE 'email',
        fav_number => GE 42
    )

The above search, whether it is a code search or a string search, should
produce the same IR:

  [
    [
        'AND',
        $name_search,
        $lname_search,
    ],
    'OR',
    [
        $age_search,
    ],
    'OR',
    [
        $one_type_search,
        $fav_number_search,
    ]
  ]

=back

B<Throws:>

=over

=item Object::Relation::Exception::Fatal::Search

=back

=cut

my $STORE;

sub _make_search {
    my $param   = shift;
    my $negated = $_[0][0];
    my ( $operator, $value ) = @{ $_[1] };

    return $STORE->_prep_search_token(
        Object::Relation::Search->new(
            param    => $param,
            negated  => $negated || '',
            operator => $operator || 'EQ',
            data     => _normalize_value($value),
            class    => $STORE->search_class,
        )
    );
}

sub _normalize_value {
    my $value = shift;
    if ( is_incomplete_iso8601($value) ) {
        $value = Object::Relation::DataType::DateTime::Incomplete->bake($value);
    }
    return $value;
}

sub parse {
    my ( $stream, $store ) = @_;
    unless ( blessed $store && $store->isa('Object::Relation::Handle') ) {
        throw_search [
            'Argument "[_1]" is not a valid [_2] object',
             2,
            'Object::Relation::Handle'
        ];
    }
    $STORE = $store;
    my ( $results, $remainder ) = eval { $entire_input->($stream) };
    if ( my $error = $@ ) {
        if ( 'ARRAY' eq ref $error ) {
            if (my $ex = first { isa_exception( $_ ) }
                map { ref $_ ? @$_ : $_ } @$error
            ) {
                $ex->rethrow;
            }
            $error = fetch_error($error);
        }
        throw_search [ 'Could not parse search request:  [_1]', $error ];
    }
    return $results;
}

1;

__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
