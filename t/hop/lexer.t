#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 4;
#use Test::More 'no_plan';

use lib 'lib/', '../lib/';

BEGIN {
    use_ok 'Kinetic::HOP::Lexer', ':all' or die;
}

my @exported = qw(
  make_lexer
);

foreach my $function (@exported) {
    no strict 'refs';
    ok defined &$function, "&$function should be exported to our namespace";
}

my $text         = 'x = 3 + 4';
my @text         = ($text);
my $iter         = sub { shift @text };
my @input_tokens = (
    [ 'VAR',   qr/[[:alpha:]]+/    ],
    [ 'NUM',   qr/\d+/             ],
    [ 'OP',    qr/[-+=]/           ],
    [ 'SPACE', qr/\s*/, sub { () } ],
);

ok my $lexer = make_lexer( $iter, @input_tokens ),
  'Calling make_lexer() with valid arguments should succeed';

my @tokens;
while ( my $token = $lexer->() ) {
    push @tokens, $token;
}

my @expected = (
    [ 'VAR', 'x' ],
    [ 'OP',  '=' ],
    [ 'NUM', 3   ],
    [ 'OP',  '+' ],
    [ 'NUM', 4   ],
);
is_deeply \@tokens, \@expected, '... and it should return the correct tokens';
