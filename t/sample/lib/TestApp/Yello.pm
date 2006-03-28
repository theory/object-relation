package TestApp::Yello;

use strict;
use warnings;

use Kinetic::Meta::Widget;
use Kinetic::Util::Language::en_us;
use Kinetic::Meta::Declare ':all';

use TestApp::Simple::One;

Kinetic::Meta::Declare->new(
    meta => [
        key         => 'yello',
        plural_name => 'Yellos',
    ],
    attributes => [
        age => {
            label       => 'Yello age',
            type        => $TYPE_WHOLE,
            widget_meta => Kinetic::Meta::Widget->new(
                type => 'text',
                tip  => 'This is a tip.  This is only a tip.',
            ),
        },
        ones => {
            type         => 'one',
            relationship => 'has_many',
            widget_meta  => Kinetic::Meta::Widget->new(
                type => 'text',
                tip  => 'This is a tip.  This is only a tip.',
            ),
        },
    ]
);

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
    'Yello',
    'Yello',
    'Yellos',
    'Yellos',
);

1;
__END__