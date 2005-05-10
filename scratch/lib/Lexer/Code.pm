package Lexer::Code;

use strict;
use warnings;
use Carp qw/croak/;

my %tokens;
BEGIN {
    $tokens{comparison} = [qw/LIKE GT LT GE LE NE MATCH/];
    $tokens{logical}    = [qw/AND OR/];
    $tokens{sorting}    = [qw/ASC DESC/];

    no strict 'refs';
    foreach my $token (@{ $tokens{comparison} }) {
        *$token = sub($) { my $value = shift; sub { shift || '', $token, $value } };
    }
    foreach my $token (@{ $tokens{logical} }) {
        *$token = sub { my @values = @_; sub { $token, \@values } };
    }
    foreach my $token (@{ $tokens{sorting} }) {
        *$token = sub()  { sub { $token } }
    }
    push @{$tokens{comparison}} => qw/NOT EQ BETWEEN ANY/;
}

use Exporter::Tidy
    main       => ['lex'],
    comparison => $tokens{comparison},
    logical    => $tokens{logical},
    sorting    => $tokens{sorting};

sub NOT($) {
    my $value = _normalize_term(shift);
    sub {
        return ('CODE' eq ref $value)
            ? $value->('NOT')
            : ('NOT', 'EQ', $value);
    }
}

sub EQ($) {
    my $value = shift;
    sub {
        my $negated = shift || '';
        return ('ARRAY' eq ref $value)
            ? ($negated, 'BETWEEN', $value)
            : ($negated, 'EQ',      $value);
    }
}

sub BETWEEN {
    my $value = shift; 
    croak "BETWEEN searches may only have two values (@$value)"
        unless 2 == @$value;
    sub { (shift() || ''), 'BETWEEN', $value }
}

sub ANY { 
    my @args = @_; 
    sub { shift || '', 'ANY', \@args } 
}

sub _normalize_term {
    my $term = shift;
    if ('ARRAY' eq ref $term) {
        my @body = @$term;
        $term = AND(@body);
    }
    return $term;
}

sub _normalize_value {
    my $term = shift;
    if ('ARRAY' eq ref $term) {
        my @body = @$term;
        $term = BETWEEN(\@body);
    }
    if (! ref $term) {
        $term = EQ $term;
    }
    return $term;
}

my %term_types = (
    standard => sub {
        # name => 'foo'
        my ($column, $code) = @_;
        my $value = _normalize_value(shift @$code);
        my @tail  = $value->();
        return [ $column, @tail ];
    },
    CODE => sub {
        my ($term) = @_;
        my ($op, $code) = $term->();
        return 'AND' eq $op
            ? [$op, @{lex($code)}]  # AND 
            : ($op, lex($code));    # OR
    },
);

sub lex {
    my ($code) = @_;
    my @tokens;
    while (my $term = _normalize_term(shift @$code)) {
        my $type = ref $term || 'standard';
        if (my $make_token = $term_types{$type}) {
            push @tokens => $make_token->($term, $code);
        }
        else {
            croak "I don't know how to lex a ($type)";
        }
    }
    return \@tokens;
}

1;
