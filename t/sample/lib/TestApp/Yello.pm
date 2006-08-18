package TestApp::Yello;

use strict;
use warnings;

use Object::Relation::Language::en_us;
use TestApp::Simple::One;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'yello',
        name        => 'Yello',
        store_config => {
            class => $ENV{OBJ_REL_CLASS},
            cache => $ENV{OBJ_REL_CACHE},
            user  => $ENV{OBJ_REL_USER},
            pass  => $ENV{OBJ_REL_PASS},
            dsn   => $ENV{OBJ_REL_DSN},
        },
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
