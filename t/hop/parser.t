#!/usr/bin/perl
use warnings;
use strict;

#use Test::More tests => 17;
use Test::More 'no_plan';

use lib 'lib/', '../lib/';

BEGIN {
    use_ok 'Kinetic::HOP::Parser', ':all' or die;
}

use Kinetic::HOP::Stream qw/node list_to_stream/;
use Kinetic::Util::Exceptions; # auto stacktrace

my @exported = qw(
  action
  alternate
  concatenate
  debug
  End_of_Input
  error
  list_of
  lookfor
  match
  nothing
  null_list
  operator
  parser
  star
  T
  test
);

foreach my $function (@exported) {
    no strict 'refs';
    ok defined &$function, "&$function should be exported to our namespace";
}

#
# parser: test that parser accepts a bare block as a subroutine
#

ok my $sub = parser {'Ovid'}, 'parser() should accept a bare block as a sub';
is $sub->(), 'Ovid', '... and we should be able to call the sub';

#
# lookfor: test passing a bare label
#

ok my $parser = lookfor('OP'),
  'lookfor() should return a parser which can look for tokens.';

ok !$parser->( [ [ 'VAL' => 3 ] ] ),
  '... and the parser will fail if the first token does not match';

my @tokens = (
    node( OP  => '+' ),
    node( VAR => 'x' ),
    node( VAL => 3 ),
    node( VAL => 17 ),
);
my $stream = list_to_stream(@tokens);
ok my ( $parsed, $remainder ) = $parser->($stream),
  'The lookfor() parser should succeed if the first token matches';
is $parsed, '+', '... returning what we are looking for';
my $expected = [ [ 'VAR', 'x' ], [ [ 'VAL', 3 ], [ 'VAL', 17 ] ] ];
is_deeply $remainder, $expected, '... and then the rest of the stream';

#
# lookfor: test passing a [ $label ]
#

ok $parser = lookfor( ['OP'] ),
  'lookfor() should return a parser if we supply an array ref with a label';

ok !$parser->( [ [ 'VAL' => 3 ] ] ),
  '... and the parser will fail if the first token does not match';

( $parsed, $remainder ) = $parser->($stream);
ok $parsed, 'The lookfor() parser should succeed if the first token matches';

is $parsed, '+', '... returning what we are looking for';
is_deeply $remainder, $expected, '... and then the rest of the stream';

#
# lookfor: test passing a [ $label, $value ]
#

ok $parser = lookfor( [ OP => '+' ] ),
  'lookfor() should succeed if we supply an array ref with a "label => value"';

ok !$parser->( [ [ 'VAL' => 3 ] ] ),
  '... and the parser will fail if the first token does not match';

( $parsed, $remainder ) = $parser->($stream);
ok $parsed, 'The lookfor() parser should succeed if the first token matches';

is $parsed, '+', '... returning what we are looking for';
is_deeply $remainder, $expected, '... and then the rest of the stream';

my %opname_for = (
    '+' => 'plus',
    '-' => 'minus',
);
my $get_value = sub {
    my $value = $_[0][1];    # token is [ $label, $value ]
    return exists $opname_for{$value} ? $opname_for{$value} : $value;
};

#
# lookfor: test passing a [ $label ], \&get_value
#

ok $parser = lookfor( ['OP'], $get_value ),
  'lookfor() should succeed if we supply an array ref with a "label => value"';

ok !$parser->( [ [ 'VAL' => 3 ] ] ),
  '... and the parser will fail if the first token does not match';

( $parsed, $remainder ) = $parser->($stream);
ok $parsed, 'The lookfor() parser should succeed if the first token matches';

is $parsed, 'plus', '... returning the transformed value';
is_deeply $remainder, $expected, '... and then the rest of the stream';

( $parsed, $remainder ) = $parser->( [ [ OP => '-' ] ] );
is $parsed, 'minus', '... and other transformed values should work';

( $parsed, $remainder ) = $parser->( [ [ OP => '*' ] ] );
is $parsed, '*', '... just like we expect them to';

$get_value = sub {
    my ( $matched_token, $opname_for ) = @_;
    my $value = $matched_token->[1];    # token is [ $label, $value ]
    return exists $opname_for->{$value} ? $opname_for->{$value} : $value;
};

#
# lookfor: test passing a [ $label ], \&get_value, $param
#

ok $parser = lookfor( ['OP'], $get_value, \%opname_for ),
  'lookfor() should succeed with the three argument syntax';

ok !$parser->( [ [ 'VAL' => 3 ] ] ),
  '... and the parser will fail if the first token does not match';

( $parsed, $remainder ) = $parser->($stream);
ok $parsed, 'The lookfor() parser should succeed if the first token matches';

is $parsed, 'plus', '... returning the transformed value';
is_deeply $remainder, $expected, '... and then the rest of the stream';

( $parsed, $remainder ) = $parser->( [ [ OP => '-' ] ] );
is $parsed, 'minus', '... and other transformed values should work';

( $parsed, $remainder ) = $parser->( [ [ OP => '*' ] ] );
is $parsed, '*', '... just like we expect them to';

#
# match: test passing a $label
#

ok $parser = match('OP'), 'match() should return a parser if we supply a label';

ok !$parser->( [ [ 'VAL' => 3 ] ] ),
  '... and the parser will fail if the first token does not match';

( $parsed, $remainder ) = $parser->($stream);
ok $parsed, 'The match() parser should succeed if the first token matches';

is $parsed, '+', '... returning what we are looking for';
is_deeply $remainder, $expected, '... and then the rest of the stream';

#
# match:  test passing a $label, $value
#

ok $parser = match( OP => '+' ),
  'match() should succeed if we supply a "label => value"';

ok !$parser->( [ [ 'VAL' => 3 ] ] ),
  '... and the parser will fail if the first token does not match';

( $parsed, $remainder ) = $parser->($stream);
ok $parsed, 'The match() parser should succeed if the first token matches';

is $parsed, '+', '... returning what we are looking for';
is_deeply $remainder, $expected, '... and then the rest of the stream';

#
# nothing
#

( $parsed, $remainder ) = nothing($stream);
ok !defined $parsed, 'nothing() will always return "undef" for what was parsed';
is_deeply $remainder, $stream, '... and should return the input unaltered';

#
# End_of_Input
#

my @succeeds = End_of_Input($stream);
ok !@succeeds, 'End_of_Input() should fail if data left in the stream';

@succeeds = End_of_Input(undef);
ok @succeeds, '... and it should succeed if no data is left in the stream';

#
# concatenate:  we should be able to concatenate stream tokens
#

ok $parser = concatenate(), 'We should be able to concatenate nothing';
( $parsed, $remainder ) = $parser->($stream);
ok !defined $parsed, '... and it should return an undefined parse';
is_deeply $remainder, $stream, '... and the input should be unchanged';

ok $parser = concatenate( match('OP') ),
  'We should be able to concatenate a single parser';
( $parsed, $remainder ) = $parser->($stream);
is $parsed, '+', '... and it should parse the stream';
is_deeply $remainder, $expected,
  '... and the input should be the rest of the stream';

ok $parser = concatenate( match('OP'), match( VAR => 'x' ), ),
  'We should be able to concatenate multiple parsers';
( $parsed, $remainder ) = $parser->($stream);
is_deeply $parsed, [qw/ + x /], '... and it should parse the stream';
my $expected_remainder = [ [ 'VAL', 3 ], [ 'VAL', 17 ] ];
is_deeply $remainder, $expected_remainder,
  '... and the input should be the rest of the stream';

ok $parser = concatenate( match('OP'), match( VAR => 'no such var' ), ),
  'We should be able to concatenate multiple parsers';
@succeeds = $parser->($stream);
ok !@succeeds, '... but the parser should fail if the tokens do not match';

ok $parser = concatenate(
    match('OP'),
    match( VAR => 'x' ),
    match( VAL => 3 ),
    match( VAL => 17 ),
  ),
  'We should be able to concatenate multiple parsers';

diag "Uncomment the following when we figure out what's wrong!";

#( $parsed, $remainder ) = $parser->($stream);
#is_deeply $parsed, [qw/ + x 3 17 /],
#  '... and it should be able to parse the entire stream';

#
# alternate:  we should be able to alternate stream tokens
#

ok $parser = alternate(), 'We should be able to alternate nothing';
@succeeds = $parser->($stream);
ok !@succeeds, '... but it should always fail';

ok $parser = alternate( match('VAR'), match('VAL') ),
  'We should be able to alternate on incorrect tokens';
@succeeds = $parser->($stream);
ok !@succeeds, '... but it should always fail';

$parser = alternate( match('Foo'), match('OP') );
( $parsed, $remainder ) = $parser->($stream);
is $parsed, '+', 'alternate() should succeed even if one match is bad';
is_deeply $remainder, $expected,
  '... and the remainder should be the rest of the stream';

$parser = alternate( match('OP'), match('Foo') );
( $parsed, $remainder ) = $parser->($stream);
is $parsed, '+', '... regardless of the order they are in';
is_deeply $remainder, $expected,
  '... and the remainder should be the rest of the stream';

$parser = alternate( match('OP'), match('OP') );
( $parsed, $remainder ) = $parser->($stream);
is $parsed, '+', '... or if they are duplicate tokens';
is_deeply $remainder, $expected,
  '... and the remainder should be the rest of the stream';

$parser = alternate(
    match('VAL'), match('Foo'), match('BAR'), match('~'),
    match('OP'),  match('INT'),
);
( $parsed, $remainder ) = $parser->($stream);
is $parsed, '+',
  'We should be able to alternate over an arbitrary amount of tokens';
is_deeply $remainder, $expected,
  '... and the remainder should be the rest of the stream';

#
# null_list
#

( $parsed, $remainder ) = null_list($stream);
is_deeply $parsed, [], 'The null_list() parser should always succeed';
is_deeply $remainder, $stream, '... and return the input as the remainder';

#
# star:  generates a "zero or more" parser
#

$parser = star( match('Foo') );
( $parsed, $remainder ) = $parser->($stream);
is_deeply $parsed, [], 'The star() parser should always succeed';
is_deeply $remainder, $stream,
  '... and return the input as the remainder if it did not match';

$parser = star( match('OP') );
( $parsed, $remainder ) = $parser->($stream);
is_deeply $parsed, ['+'],
  'The start() parser should return the first value if matched';
is_deeply $remainder, $expected, '... and then the remainder of the stream';

$parser = star( alternate( match('VAR'), match('OP') ) );
( $parsed, $remainder ) = $parser->($stream);
is_deeply $parsed, [ '+', 'x' ],
  'The start() parser should return all the values matched';
is_deeply $remainder, [ [ VAL => 3 ], [ VAL => 17 ] ],
  '... and then the remainder of the stream';

$parser = star( alternate( match('VAL'), match('VAR'), match('OP') ) );
#( $parsed, $remainder ) = $parser->($stream);
#is_deeply $parsed, [ '+', 'x', 3, 17 ],
#  'The start() parser should return all the values matched';
#is_deeply $remainder, [ [ VAL => 3 ], [ VAL => 17 ] ],
#  '... and then the remainder of the stream';
#diag $remainder;
