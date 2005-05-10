#!/usr/bin/perl
use warnings;
use strict;

use Test::More 'no_plan';

use lib 'lib', '../lib';
use Lexer qw/:all/;
use Stream qw/drop/;

use Data::Dumper;
BEGIN {
    use_ok 'Parser', ':all' or die $!;
}

my @tokens = (
    [ 'INT',  3 ],
    [ 'OP', '+' ],
);

ok my $int     = lookfor('INT'), 'lookfor() should succeed with a scalar argument';
is ref $int, 'CODE', '... and return a code ref';
ok my $op_plus = lookfor([qw/OP +/]), '... and it should succeed with an arrayref arg';
is ref $op_plus, 'CODE', '... and still return a code ref';

is_deeply [$int->(\@tokens)], [3, ['OP', '+']],
    '... and $int should recognize an INT token';
shift @tokens;
is_deeply [$op_plus->(\@tokens)], ['+', undef],
    '... and $op_plus should recognize an "OP +" token';
ok ! $op_plus->([['OP', '-']]), '... but it should not recognize an "OP -" token';

@tokens = (
    [qw/DING  3/],
    [qw/DONG  2/],
    [qw/DRIBBLE/],
);

my $stream   = iterator_to_stream(sub {shift @tokens});
my $doorbell = concatenate(lookfor('DING'), lookfor('DONG'));
my @result   = $doorbell->($stream);
is ref $result[-1][-1], 'CODE', 'The last item in a concatenating parse should be a promise';
$result[1][1] = undef; # eliminate the code ref
my $expected = [
    [ 3, 2 ],
    [
        [ 'DRIBBLE' ],
        undef
    ]
];
is_deeply \@result, $expected, '... and the parse should be valid';

@tokens = (
    [qw/DING  3/],
    [qw/DONG  2/],
    [qw/DRIBBLE/],
);

$doorbell = alternate(lookfor('DING'), lookfor('DONG'));
@result   = $doorbell->($stream);
$expected = [
  '3',
  [
    [ 'DONG', '2' ],
    [
      [ 'DRIBBLE' ],
      undef
    ]
  ]
];
is_deeply \@result, $expected, '... and the parse should be valid';

my $expression;
my $Expression = parser { $expression->(@_) };
$expression = alternate(concatenate(lookfor('INT'),
                                    lookfor(['OP', '+']),
                                    $Expression),
                        concatenate(lookfor('INT'),
                                    lookfor(['OP', '*']),
                                    $Expression),
                        concatenate(lookfor(['OP', '(']),
                                    $Expression,
                                    lookfor(['OP', ')'])),
                        lookfor('INT'));

my $entire_input = concatenate($Expression, \&End_of_Input);

my $lexer = _make_test_lexer();
my ($result, $remaining_input) = $entire_input->($lexer);
$expected = [
  [
    '2', '*',
    [
      '3', '+',
      [
        '(', 
          [ '4', '*', '5' ], 
        ')'
      ]
    ]
  ],
  undef
];

is_deeply $result, $expected, 'We should be able to parse a lexer stream';
ok ! $remaining_input, '... and there should be no leftover input if everthing parsed';

my ($term, $factor);

# entire_input -> expression 'End of Input'
# expression   -> term   '+' expression | term
# term         -> factor '*' term | factor
# factor       -> 'INT' | '(' expression ')'


my $Term   = parser { $term  ->(@_) };
my $Factor = parser { $factor->(@_) };

$expression = alternate(concatenate($Term,
                                    lookfor(['OP', '+']),
                                    $Expression),
                        $Term);
$term       = alternate(concatenate($Factor,
                                    lookfor(['OP', '*']),
                                    $Term),
                        $Factor);
$factor     = alternate(lookfor('INT'),
                        concatenate(lookfor(['OP', '(']),
                                    $Expression,
                                    lookfor(['OP', ')']))
                        );
$entire_input = concatenate($Expression, \&End_of_Input);
($result, $remaining_input) = $entire_input->($lexer);
$expected = [
  [
    [ '2', '*', '3' ],
    '+',
    [
      '(',
        [ '4', '*', '5' ],
      ')'
    ]
  ],
  undef
];
is_deeply $result, $expected, '... and by tuning the grammar, we can get precendence respected';


$expression = alternate(T(concatenate($Term,
                                    lookfor(['OP', '+']),
                                    $Expression),
                        sub { [@_[1,0,2]] } ),
                        $Term);
$term       = alternate(T(concatenate($Factor,
                                    lookfor(['OP', '*']),
                                    $Term),
                        sub { [@_[1,0,2]] } ),
                        $Factor);
$factor     = alternate(lookfor('INT'),
                        T(
                            concatenate(lookfor(['OP', '(']),
                                        $Expression,
                                        lookfor(['OP', ')'])),
                            sub { $_[1] }) # strip parentheses
                        );
$entire_input = T(concatenate($Expression, \&End_of_Input), sub { $_[0] });
($result, $remaining_input) = $entire_input->($lexer);
$expected = [
  '+',
  [ '*', '2', '3' ],
  [ '*', '4', '5' ],
];
is_deeply $result, $expected, 
    '... and with transforms, we should be able to generate a complete AST';

sub _make_test_lexer {
    my @input = '2 * 3 + (4 * 5)';
    my $input = sub { shift @input };

    return iterator_to_stream(
        make_lexer($input,
            ['TERMINATOR', qr/;\n*|\n+/               ],
            ['INT',        qr/\d+/                    ],
            ['PRINT',      qr/bprint\b/               ],
            ['IDENTIFIER', qr/[[:alpha:]_][[:word:]]*/],
            ['OP',         qr/\*\*|[-+*\/=()]/        ],
            ['WHITESPACE', qr/\s+/, sub {''}          ],
        ),
    );
}

