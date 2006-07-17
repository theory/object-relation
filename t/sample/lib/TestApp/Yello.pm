package TestApp::Yello;

use strict;
use warnings;

use Kinetic::Store::Language::en_us;
use TestApp::Simple::One;

BEGIN {
    my $km = Kinetic::Store::Meta->new(
        key         => 'yello',
        name        => 'Yello',
    );

    $km->add_attribute(
        name        => 'age',
        label       => 'Yello age',
        type        => 'posint',
        widget_meta => Kinetic::Store::Meta::Widget->new(
            type => 'text',
            tip  => 'This is a tip.  This is only a tip.',
        ),
    );

    $km->add_attribute(
        name         => 'ones',
        type         => 'one',
        relationship => 'has_many',
        widget_meta  => Kinetic::Store::Meta::Widget->new(
            type => 'text',
            tip  => 'This is a tip.  This is only a tip.',
        ),
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Store::Language::en->add_to_lexicon(
    'Yello',
    'Yello',
    'Yellos',
    'Yellos',
);

1;
__END__
