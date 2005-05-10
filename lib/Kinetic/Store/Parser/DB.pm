package Kinetic::Store::Parser::DB;

use strict;
use warnings;
use Scalar::Util 'blessed';
use Exporter::Tidy default => ['parse'];
use constant OBJECT_DELIMITER => '__'; # XXX push this to Store/DB.pm

use Kinetic::Store::Parser    ':all';
use Kinetic::Store::Search;
use Kinetic::Util::Exceptions 'throw_search';
use Kinetic::Util::Stream     ':all';

my $value;
my $Value = parser { $value->(@_) };
$value = alternate(
  _('VALUE'),
  T(
    _('UNDEF'),
    sub { undef }
  )
);
my $any;
my $Any = parser { $any->(@_) };
$any = T(
  concatenate(
    _('ANY'),
    _('LPAREN'),
    $value,
    T(
      star(
        T(
          concatenate(
            alternate(
              _('COMMA'),
              _('SEPARATOR')
            ),
            _('VALUE'), # undef doesn't apply 
          ),
          sub { $_[1] }
        )
      ),
      sub { \@_ }
    ),
    T(star(_('SEPARATOR')), sub {()}), # allow a trailing comma
    _('RPAREN'),
  ),
  sub {
    # any is in an arrayref because $normal_value has star(_('KEYWORD'))
    # and that returns the keyword in an arrayref
    [ ['ANY'], [ $_[2], @{$_[3]} ] ]
  }
);

my $normal_value = T(
  concatenate(
    alternate(
      concatenate(
        star(_('KEYWORD')),
        $value
      ),
      $any
    )
  ),
  sub { [$_[0][0], $_[1]] }
);

my $between_value = T(
  concatenate(
    star(_('BETWEEN')),
       _('LBRACKET'),
         $value,
         alternate(
           _('COMMA', '=>'),
           _('SEPARATOR', ','),
         ),
         $value,
       _('RBRACKET'),
  ),
  sub { ['BETWEEN', [$_[2], $_[4]]] }
);

my $search = T(
  concatenate( 
       _('IDENTIFIER'),
       _('COMMA', '=>'),
    star(_('NEGATED')),
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
        _('SEPARATOR'),
        $Statement,
      ),
      sub { $_[1] }
    ),
  ),
  T(star(_('SEPARATOR')), sub {()}), # allow a trailing comma
);

$statement = T(
  alternate(
    $statement_list,
    T(
      concatenate(
        alternate(
          _('AND'),
          _('OR')
        ),
        _('LPAREN'),
        $statement_list,
        _('RPAREN')
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
        _('SEPARATOR'),
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
    $statements, # was $Full_query
    \&End_of_Input
  ), 
  sub { 
    $_[0]
  }
);

my $STORE;
sub parse { 
  my ($stream, $store) = @_;
  unless (defined $store && UNIVERSAL::isa($store, 'Kinetic::Store')) {
    throw_search [
      'Argument "[_1]" is not a valid [_2] object',
      2, 'Kinetic::Store'
    ];
  }
  $STORE = $store;
  return $entire_input->($stream);
}

sub _make_search {
  my ($column, $negated, $operator, $value) = @_;
  $column =~ s/\./OBJECT_DELIMITER/eg;
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
      : ref $value      ? $value->id
      : throw_search [
        'Object key "[_1]" must point to an object, not a scalar ([_2])',
        $id_column, $value
      ];
  }

  return Kinetic::Store::Search->new(
    column   => $column,
    negated  => ($negated || ''),
    operator => ($operator || 'EQ'),
    data   => $value,
  );
}

1;
