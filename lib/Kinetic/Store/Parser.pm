package Kinetic::Store::Parser;

# $Id: Store.pm 1671 2005-05-10 00:24:33Z curtis $

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
use Exporter::Tidy default => ['parse'];

use Kinetic::Store::Parser::HOP   qw/:all/;
use Kinetic::Store::Search;
use Kinetic::Util::Constants      qw/:data_store/;
use Kinetic::Util::Exceptions     qw/throw_search/;
use Kinetic::HOP::Stream          qw/:all/;
use Kinetic::DateTime::Incomplete qw/is_incomplete_iso8601/;

=head1 Name

Kinetic::Store::Parser - The Kinetic parser for search requests

=head1 Synopsis

  use Kinetic::Store::Parser qw/parse/;
  use Kinetic::Store::Lexer::Code qw/lexer_stream/;

  sub _create_ir {
    my ($self, $search_request) = @_;
    my $stream = lexer_stream($search_request);
    my ($intermediate_representation) = parse($stream, $ir);
    return $intermediate_representation;
  }

=head1 Description

This class takes the tokens produced by a Kinetic lexer and creates an
intermediate representation that can be easily converted to a search request
for a given store.

=cut

# predefine a few things
my $lparen    = match(OP =>  '(');
my $rparen    = match(OP =>  ')');
my $lbracket  = match(OP =>  '[');
my $rbracket  = match(OP =>  ']');
my $fat_comma = match(OP => '=>');
my $comma     = match(OP =>  ',');

my $search_value = match('VALUE');
sub _search_value { $search_value }

my $value;
my $Value = parser { $value->(@_) };
$value = alternate(
  $search_value,
  T(
    match('UNDEF'),
    sub { undef }
  )
);
my $any;
my $Any = parser { $any->(@_) };
$any = T(
  concatenate(
    match(KEYWORD => 'ANY'),
    $lparen,
    $value,
    T(
      star(
        T(
          concatenate(
            alternate(
              $fat_comma,
              $comma
            ),
            $search_value, # undef doesn't apply 
          ),
          sub { $_[1] }
        )
      ),
      sub { \@_ }
    ),
    T(star($comma), sub {()}), # allow a trailing comma
    $rparen,
  ),
  sub {
    # any is in an arrayref because $normal_value has star(match('COMPARE'))
    # and that returns the keyword in an arrayref
    [ ['ANY'], [ _normalize_value($_[2]), map { _normalize_value($_) } @{$_[3]} ] ]
  }
);

my $normal_value = T(
  concatenate(
    alternate(
      concatenate(
        star(match('COMPARE')),
        $value
      ),
      $any
    )
  ),
  sub { [$_[0][0], $_[1]] }
);

my $between_value = T(
  concatenate(
    star(match(KEYWORD => 'BETWEEN')), # 0
       $lbracket,                  # 1
         $Value,                   # 2
         alternate(
           $fat_comma,             # 3
           $comma,
         ),
         $Value,                   # 4
       $rbracket,
  ),
  sub { ['BETWEEN', [_normalize_value($_[2]), _normalize_value($_[4])]] }
);

my $search = T(
  concatenate( 
       match('IDENTIFIER'),
       $fat_comma,
    star(match(KEYWORD => 'NOT')),
    alternate(
      $normal_value,
      $between_value
    )
  ),
  sub { _make_search($_[0], $_[2][0], @{$_[3]}) }
);
my $Search = parser { $search->(@_) };

my $statement;
my $Statement = parser { $statement->(@_) };

my $statement_list = concatenate(
  $Search,
  star(
    T(
      concatenate(
        $comma,
        $Statement,
      ),
      sub { $_[1] }
    ),
  ),
  T(star($comma), sub {()}), # allow a trailing comma
);

$statement = T(
  alternate(
    $statement_list,
    T(
      concatenate(
        alternate(
          match(KEYWORD => 'AND'),
          match(KEYWORD => 'OR')
        ),
        $lparen, $statement_list, $rparen
      ),
      sub { [$_[0], $_[2] ] }
    ),
  ),
  sub {
    \@_
  }
);

my $statements = T(
  concatenate(
    $Statement,
    star(
      concatenate(
        $comma,
        $Statement
      )
    )
  ),
  sub {
    [ grep { defined }  _extract_statements(\@_) ];
  }
);

sub _extract_statements {
  my $ref = shift;
  my @statements;
  
  while(defined(my $head = drop($ref))) {
    next if ',' eq $head; # XXX oops
    if ('ARRAY' eq ref $head) {
      push @statements => _extract_statements($head);
    }
    elsif ('OR' eq $head) {
      push @statements => 'OR', [_extract_statements($ref)];
      undef $ref;
    }
    elsif ('AND' eq $head) {
      push @statements => ['AND', _extract_statements($ref)];
      undef $ref;
      
    }
    else {
      push @statements => $head;
    }
  };
  return @statements;
}

my $entire_input = T(
  concatenate(
    $statements,
    \&End_of_Input
  ), 
  sub { 
    $_[0]
  }
);

##############################################################################
# Public Interface
##############################################################################

=head2 Exportable functions

=head3 parse

  my $ir = parse($stream, $store);

This function takes a lexer stream produced by a Kinetic lexer a the store
object to be searched.  It returns an intermediate representation suitable
for parsing into a where clause.

This function returns an array reference of 
L<Kinetic::Store::Search|Kinetic::Store::Search> objects and groups of these
Search objects.  Groups may be simple groups, "AND" groups or "OR" groups.  

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
    OR( age => GT 3),
    OR(
      one__type   => LIKE 'email',
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

=item Kinetic::Util::Exception::Fatal::Search

=back

=cut

my $STORE;
sub _make_search {
  my ($column, $negated, $operator, $value) = @_;
  $column =~ s/\Q@{[ATTR_DELIMITER]}\E/OBJECT_DELIMITER/eg;
  unless ($STORE->_search_data_has_column($column)) {
    # special case for searching on a contained object id ...
    my $id_column = $column . OBJECT_DELIMITER . 'id';
    unless ($STORE->_search_data_has_column($id_column)) {
      throw_search [
        "Don't know how to search for ([_1] [_2] [_3] [_4]): [_5]",
        $column, $negated, $operator, $value,
        "Unknown column '$column'"
      ];
    }
    $column = $id_column;
    $value =
      'ARRAY' eq ref $value ? [map $_->id => @$value]
      : ref $value          ? $value->id
      : throw_search [
        'Object key "[_1]" must point to an object, not a scalar ([_2])',
        $id_column, $value
      ];
  }

  return Kinetic::Store::Search->new(
    column   => $column,
    negated  => ($negated  || ''),
    operator => ($operator || 'EQ'),
    data     => _normalize_value($value),
  );
}

sub _normalize_value {
  my $value = shift;
  if (is_incomplete_iso8601($value)) {
    $value = Kinetic::DateTime::Incomplete->new_from_iso8601($value);
  }
  return $value;
}

sub parse { 
  my ($stream, $store) = @_;
  unless (defined $store && UNIVERSAL::isa($store, 'Kinetic::Store')) {
    throw_search [
      'Argument "[_1]" is not a valid [_2] object',
      2, 'Kinetic::Store'
    ];
  }
  $STORE = $store;
  my ($results, $remainder) = $entire_input->($stream); 
  # XXX really need to figure out a more descriptive error message
  throw_search 'Could not parse search request' if $remainder or ! $results;
  return $results;
}

1;

__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

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
