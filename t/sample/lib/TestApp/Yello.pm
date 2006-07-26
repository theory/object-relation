package TestApp::Yello;

use strict;
use warnings;

use Object::Relation::Language::en_us;
use TestApp::Simple::One;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'yello',
        name        => 'Yello',
    );

    $km->add_attribute(
        name        => 'age',
        label       => 'Yello age',
        type        => 'posint',
        widget_meta => Object::Relation::Meta::Widget->new(
            type => 'text',
            tip  => 'This is a tip.  This is only a tip.',
        ),
    );

    $km->add_attribute(
        name         => 'ones',
        type         => 'one',
        relationship => 'has_many',
        widget_meta  => Object::Relation::Meta::Widget->new(
            type => 'text',
            tip  => 'This is a tip.  This is only a tip.',
        ),
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
    'Yello',
    'Yello',
    'Yellos',
    'Yellos',
);

1;
__END__
