package TestApp::HasMany;
use base 'Kinetic';

use TestApp::Simple::One;
use Kinetic::Util::Language::en_us;
use Kinetic::Meta::Declare ':all';
use Kinetic::Meta::Widget;

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
            relationship => 'has_many', # can also be an array ref
            type         => 'one',
            widget_meta  => Kinetic::Meta::Widget->new(
                type => 'text',
                tip  => 'This is a tip.  This is only a tip.',
            ),
        },
    ]
);

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
    'has_many',
    'has_many',
    'Has many',
    'Has many',
    'Has Manys',
    'Has Manys',
    'This is a tip.  This is only a tip.',
    'This is a tip.  This is only a tip.',
    'HasMany age',
    'HasMany age',
);

1;
__END__
