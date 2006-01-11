package Kinetic::Store::Search;

# $Id: Store.pm 1364 2005-03-08 03:53:03Z curtis $

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

use Scalar::Util qw(blessed);

use Kinetic::Util::Exceptions qw(panic throw_search);
use aliased 'Kinetic::DataType::DateTime::Incomplete';

#use overload '""' => \&formatted_data, fallback => 1;

# lots of private class data

# generic getter/setters
my @_ATTRIBUTES = qw/
  column
  negated
  operator
  place_holder
  search_class
  /;

# getter/setter with custom behavior
my @ATTRIBUTES = ( 'data', @_ATTRIBUTES );

# simple getter/setter lookup table
my %ATTR_LOOKUP;
@ATTR_LOOKUP{@ATTRIBUTES} = undef;

# for a given "operator", the value should be a sub that will return
# the correct store class search method.
my %COMPARE_DISPATCH = (
    ANY     => \&_ANY_SEARCH,
    EQ      => sub { _am_i_eq_or_not(shift) },
    NOT     => sub { _am_i_eq_or_not(shift) },
    LIKE    => sub { '_LIKE_SEARCH' },
    MATCH   => sub { '_MATCH_SEARCH' },
    BETWEEN => \&_BETWEEN_SEARCH,
    GT      => sub { shift->_GT_LT_SEARCH( '<=', '>' ) },
    LT      => sub { shift->_GT_LT_SEARCH( '>=', '<' ) },
    GE      => sub { shift->_GT_LT_SEARCH( '<', '>=' ) },
    LE      => sub { shift->_GT_LT_SEARCH( '>', '<=' ) },
    NE => sub {
        my ($search) = @_;
        $search->negated('NOT');
        $search->operator('EQ');
        return _am_i_eq_or_not($search);
    },
);

sub _GT_LT_SEARCH {
    my ( $search, $neg_op, $op ) = @_;
    $search->operator( $search->negated ? $neg_op : $op );
    return UNIVERSAL::isa( $search->data, Incomplete )
      ? '_date_handler'
      : '_GT_LT_SEARCH';
}

=head1 Name

Kinetic::Store::Search - Manage Kinetic search parameters

=head1 Synopsis

  use Kinetic::Store::Search;
  my $search = Kinetic::Store::Search->new(
      column       => $column,
      operator     => $operator,
      negated      => $negated,
      place_holder => $place_holder,
      data         => $data,
      search_class => $search_class,
  );
  # later
  $search->column($new_attr);
  my $method = $search->search_method;
  $store->$method($search);

=head1 Description

This class manages all of the data necessary for creation of individual search
tokens ("name = 'foo'", "age >= 21", etc.). When enough slots are filled,
calling C<store_method> will return the name of the method that will generate
the appropriate search token.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $search = Kinetic::Store::Search->new;
  # or
  my $search = Kinetic::Store::Search->new(
      column       => $column,
      operator     => $operator,
      negated      => $negated,
      data         => $data,
      place_holder => $place_holder,
      search_class => $search_class,
  );

Creates and returns a new search manager.

If passed named parameters, those respective slots will be populated with the
values.

Each of the parameters can also be accessed via a getter/setter.  See the docs
for the corresponding parameter to understand its function.

=cut

sub new {
    my ( $class, %attributes ) = @_;

    # XXX why am I sorting these keys?
    my @invalid = grep !exists $ATTR_LOOKUP{$_} => sort keys %attributes;
    if (@invalid) {
        throw_search [ "Unknown attributes to [_1]: [_2]", "$class->new",
            "@invalid" ];
    }
    my $self = bless {} => $class;
    while ( my ( $attribute, $value ) = each %attributes ) {
        $self->$attribute($value);
    }
    $self->original_operator( $attributes{operator} );
    return $self;
}

foreach my $attribute (@_ATTRIBUTES) {
    no strict 'refs';
    next if defined &$attribute; # don't overwrite existing method
    *$attribute = sub {
        my $self = shift;
        if (@_) {
            $self->{$attribute} = shift;
            return $self;
        }
        return $self->{$attribute};
    };
}

sub operator {
    my $self = shift;
    if (@_) {
        my $operator = shift || '';
        if ( $operator ne ( $self->{operator} || '' ) ) {
            $self->{operator}      = $operator;
            $self->{search_method} = undef;       # clear search_method cache
        }
        return $self;
    }
    return $self->{operator};
}

##############################################################################

=head3 search_method

  my $method = $search->search_method;

This method uses the attributes that have been set to determine which search
method the store L<Kinetic::Store|Kinetic::Store> class should dispatch to.

=cut

sub search_method {
    my $self = shift;

    if ( my $method = $self->{search_method} ) {
        return $method;
    }

    my $column = $self->column;
    my $value  = $self->data;
    my $neg    = $self->negated;
    my $op     = $self->operator;
    my $error  = "Don't know how to search for ([_1] [_2] [_3] [_4]): [_5]";
    no warnings 'uninitialized';
    throw_search [ $error, $column, $neg, $op, $value, "undefined operator." ]
      unless defined $op;

    # if it's blessed, assume that it's an object whose overloading will
    # provide the correct search data
    if ( ref $value && !blessed($value) && 'ARRAY' ne ref $value ) {
        throw_search [
            $error, $column, $neg, $op, $value,
            "don't know how to handle value."
        ];
    }
    my $op_sub = $COMPARE_DISPATCH{$op}
      or
      throw_search [ $error, $column, $neg, $op, $value, "unknown op ($op)." ];
    my $search_method = $op_sub->($self);
    $self->{search_method} = $search_method;
    return $search_method;
}

sub data {
    my $self = shift;
    if (@_) {
        my $data = shift;
        $self->{data}          = $data;
        $self->{search_method} = undef;    # clear search_method cache

        # XXX Is this too early? If it is, we should push this test into
        # the operator() method. For now, it works and all tests pass.
        unless ( $self->operator ) {
            $self->operator( 'ARRAY' eq ref $data ? 'BETWEEN' : 'EQ' );
        }
        return $self;
    }
    return $self->{data};
}


sub formatted_data {
    my $self = shift;
    my $data = $self->data;
    return $data unless ref $data;
    require Data::Dumper;

    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse  = 1;

    # data is guaranteed to be an array reference (what's the crossed-fingers
    # emoticon?)
    return '(' . ( join ', ', map { Data::Dumper::Dumper($_) } @$data ) . ')';
}

sub original_operator {
    my $self = shift;
    if (@_) {
        $self->{original_operator} = shift;
        return $self;
    }
    return $self->{original_operator};
}

sub _ANY_SEARCH {
    my $search = shift;
    my $data   = $search->data;
    unless ( 'ARRAY' eq ref $data ) {
        panic
"PANIC: ANY search data is not an array ref. This should never happen.";
    }
    my %types;
    {
        no warnings;
        $types{ ref $_ }++ foreach @$data;
    }
    unless ( 1 == keys %types ) {
        throw_search "All types to an ANY search must match";
    }
    return Incomplete eq ref $data->[0]
      ? '_date_handler'
      : '_ANY_SEARCH';
}

sub _BETWEEN_SEARCH {
    my $search = shift;
    my $data   = $search->data;
    unless ( 'ARRAY' eq ref $data ) {
        panic
"PANIC: BETWEEN search data is not an array ref. This should never happen.";
    }
    unless ( 2 == @$data ) {
        my $count = @$data;
        throw_search [
            "BETWEEN searches should have two terms. You have [_1] term(s).",
            $count
        ];
    }
    if ( ref $data->[0] ne ref $data->[1] ) {
        throw_search [
"BETWEEN searches must be between identical types. You have ([_1]) and ([_2])",
            ref $data->[0],
            ref $data->[1]
        ];
    }
    return Incomplete eq ref $data->[0]
      ? '_date_handler'
      : '_BETWEEN_SEARCH';
}

sub _am_i_eq_or_not {
    my ($search) = @_;
    my $data = $search->data;
    $search->operator( $search->negated ? '!=' : '=' );
    return !defined $data ? '_NULL_SEARCH'
      : UNIVERSAL::isa( $data, Incomplete ) ? '_date_handler'
      : '_EQ_SEARCH';
}

##############################################################################
# Class Methods
##############################################################################

=head2 Instance Methods

=head3 column

  $search->column([$column]);

Getter/Setter for the object column on which you wish to search.

=head3 data

  $search->data([$data]);

Getter/Setter for the data you wish to search for.

=head3 formatted_data

  my $data = $search->formatted_data;

This may go away in the future.

Returns data formatted suitable for the REST request.  Individual values will
be returned unquoted.  C<ANY> or C<BETWEEN> searches will be returned as a
string wrapped in parentheses with string values quoted.

=head3 negated

  $search->negated(['NOT']);

Getter/Setter for the boolean attribute that determines whether or not the
current search logic is negated.

=head3 operator

  $search->operator([$operator]);t

Getter/Setter identifying which operator is actually being used for the current
search.  Examples are '<=', '=', 'LIKE', etc.

The C<orginal_operator> method will return the operator used in the search
request.  This method returns the operator that will be used in the actual
request, if different.  For example, if C<negated> returns true and
C<original_operator> returns C<EQ>, C<operator> will return C<!=>.

=head3 original_operator

  $search->original_operator([$operator]);t

Getter/Setter identifying which operator was being used for the current search.
Examples are 'LE', 'EQ', 'LIKE', etc.

=head3 place_holder

  $search->place_holder([$place_holder]);

Getter/Setter for the place holder to use in Database store apps, such as '?'.

=head3 search_class

  $search->search_class([$search_class]);

Getter/Setter for the current search class.

=cut

1;
__END__

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
