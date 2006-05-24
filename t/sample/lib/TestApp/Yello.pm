package TestApp::Yello;

use strict;
use warnings;

use Kinetic::Meta::Widget;
use Kinetic::Util::Language::en_us;
use Kinetic::Meta::Declare ':all';

use TestApp::Simple::One;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'yello',
        name        => 'Yello',
    );

    $km->add_attribute(
        name        => 'age',
        label       => 'Yello age',
        type        => 'posint',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'This is a tip.  This is only a tip.',
        ),
    );

    $km->add_attribute(
        name         => 'ones',
        type         => 'one',
        relationship => 'has_many',
        widget_meta  => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'This is a tip.  This is only a tip.',
        ),
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
    'Yello',
    'Yello',
    'Yellos',
    'Yellos',
);

1;
__END__
