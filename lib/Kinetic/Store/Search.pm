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
use Scalar::Util qw(blessed);
use Carp qw(croak);

use Kinetic::DateTime::Incomplete;

=head1 Name

Kinetic::Store::Search - Manage Kinetic search parameters

=head1 Synopsis

  use Kinetic::Store::Search;
  my $search = Kinetic::Store::Search->new(
      attr         => $attr,
      operator     => $operator,
      negated      => $negated,
      place_holder => $place_holder, 
      data         => $data,
      search_class => $search_class,
  );
  # later
  $search->attr($new_attr);
  my $method = $search->store_method;
  $store->$method($search);

=head1 Description

This class manages all of the data necessary for creation of individual search
tokens ("name = 'foo'", "age >= 21", etc.).  When enough slots are filled,
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
      attr         => $attr,
      operator     => $operator,
      negated      => $negated,
      place_holder => $place_holder, 
      data         => $data,
      search_class => $search_class,
  );

Creates and returns a new search manager.

If passed named parameters, those respective slots will be populated with the values.

=cut

my @_ATTRIBUTES = qw/
    attr
    negated
    operator
    place_holder
    search_class
/;
my @ATTRIBUTES = ( 'data', @_ATTRIBUTES );
my %ATTR_LOOKUP;
@ATTR_LOOKUP{@ATTRIBUTES} = undef;
    
sub new {
    my ($class, %attributes) = @_;
    my @invalid = grep ! exists $ATTR_LOOKUP{$_} => sort keys %attributes;
    if (@invalid) {
        require Carp;
        Carp::croak "Unknown attributes to ${class}::new (@invalid)";
    }
    no strict 'refs';
    my $self = bless {} => $class;
    while (my ($attribute, $value) = each %attributes) {
        $self->$attribute($value);
    }
    return $self;
}

foreach my $attribute (@_ATTRIBUTES) {
    no strict 'refs';
    *$attribute = sub {
        my $self = shift;
        if (@_) {
            $self->{$attribute} = shift;
            return $self;
        }
        return $self->{$attribute};
    }
}

sub data {
    my $self = shift;
    if (@_) {
        my $data = shift;
        $self->{data} = $data;
        # XXX Is this too early?  If it is, we should push this test into
        # the operator() method.  For now, it works and all tests pass.
        unless ($self->operator) {
             $self->operator('ARRAY' eq ref $data ? 'BETWEEN' : 'EQ');
        }
        return $self;
    }
    return $self->{data};
}

my %COMPARE_DISPATCH = (
    EQ      => sub { 
        my ($search) = @_;
        return _am_i_eq_or_not($search);
    },
    NOT     => sub { 
        my ($search) = @_;
        return _am_i_eq_or_not($search);
    },
    LIKE    => sub { '_LIKE_SEARCH' },
    MATCH   => sub { '_MATCH_SEARCH' },
    BETWEEN => sub { '_BETWEEN_SEARCH' },
    GT      => sub { '_GT_SEARCH' },
    LT      => sub { '_LT_SEARCH' },
    GE      => sub { '_GE_SEARCH' },
    LE      => sub { '_LE_SEARCH' },
    NE      => sub {
        my ($search) = @_;
        $search->negated('NOT');
        $search->operator('EQ');
        return _am_i_eq_or_not($search);
    },
    ANY     => sub { '_ANY_SEARCH' },
);

sub _am_i_eq_or_not {
    my ($search) = @_;
    my $data = $search->data;
    return 
        ! defined $data                                          ? '_NULL_SEARCH'
        : UNIVERSAL::isa($data, 'Kinetic::DateTime::Incomplete') ? '_EQ_INCOMPLETE_DATE_SEARCH'
        :                                                          '_EQ_SEARCH';
}

##############################################################################

=head3 search_method

  my $method = $search->search_method;

This method uses the attributes that have been set to determine which search
method the store L<Kinetic::Store|Kinetic::Store> class should dispatch to.

=cut

sub search_method {
    my $self  = shift;
    my $attr  = $self->attr;
    my $value = $self->data;
    my $neg   = $self->negated;
    my $op    = $self->operator;
    # if it's blessed, assume that it's an object whose overloading will
    # provide the correct search data
    my $error = do {
        local $^W;
        "Don't know how to search for ($attr $neg $op $value)";
    };
    croak "$error:  undefined op" unless defined $op;
    if ( ref $value && ! blessed($value) 
            && 
        ('ARRAY' ne ref $value || grep {ref && ! blessed($_)} @$value)
    ) {
        croak "$error: don't know how to handle value.";
    }
    my $op_sub = $COMPARE_DISPATCH{$op} or croak "$error: unknown op ($op)";
    my $search_method = $COMPARE_DISPATCH{$op}->($self);
    return $search_method;
}

##############################################################################
# Class Methods
##############################################################################

=head2 Instance Methods

##############################################################################

=head3 attr

  $search->attr([$attr]);

Getter/Setter for the field attribute you wish to search on.

##############################################################################

=head3 data

  $search->data([$data]);

Getter/Setter for the data you with to search for.

##############################################################################

=head3 negated

  $search->negated(['NOT']);

Getter/Setter for whether or not the current search logic is negated.

##############################################################################

=head3 operator

  $search->operator([$operator]);t

Getter/Setter for which operator is being used for the current search.
Examples are 'LE', 'EQ', 'LIKE', etc.

##############################################################################

=head3 place_holder

  $search->place_holder([$place_holder]);

Getter/Setter for the place holder to use in DB store apps.

##############################################################################

=head3 search_class

  $search->search_class([$search_class]);

Getter/Setter for the current search class.

=cut


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
