#!/usr/bin/perl
use warnings;
use strict;

use Test::More 'no_plan';

use lib 'lib';
my $LEXER;
BEGIN {
    my $LEXER = 'Lexer';
    use_ok $LEXER, qw/tokens allinput blocks make_lexer/ or die;
}

my $lexer = make_lexer(blocks(\*DATA),
    ['TERMINATOR', qr/;\n*|\n+/               ],
    ['INTEGER',    qr/\d+/                    ],
    ['PRINT',      qr/bprint\b/               ],
    ['IDENTIFIER', qr/[[:alpha:]_][[:word:]]*/],
    ['OPERATOR',   qr/\*\*|[-+*\/=()]/        ],
    ['WHITESPACE', qr/\s+/, sub {''}          ],
);

while (my $token = $lexer->()) {
    show_token($token);
}

sub show_token {
    my $token = shift;
    if (2 == @$token) {
        if ("\n" eq $token->[1]) {
            $token->[1] = '\n';
        }
        $token->[1] = qq'"$token->[1]"';
    }
    diag '['.join(', ', @$token).']',$/;
}
__DATA__
a = 12345679 * 6
b=a*9; c=0
print b
