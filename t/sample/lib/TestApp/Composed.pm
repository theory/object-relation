package TestApp::Composed;

use strict;
use warnings;

use Object::Relation::Meta;
use Object::Relation::Meta::Widget;
use Object::Relation::Language::en_us;

use TestApp::Simple::One;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'composed',
        name        => 'Composed',
        plural_name => 'Composeds',
        store_config => {
            class => $ENV{OBJ_REL_CLASS},
            cache => $ENV{OBJ_REL_CACHE},
            user  => $ENV{OBJ_REL_USER},
            pass  => $ENV{OBJ_REL_PASS},
            dsn   => $ENV{OBJ_REL_DSN},
        },
    );

    $km->add_attribute(
        name          => 'one',
        type          => 'one',
        label         => 'One',
        required      => 0,
        once          => 1,
        default       => sub { TestApp::Simple::One->new },
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'search',
            tip  => 'One',
        )
    );

    $km->add_attribute(
        name          => 'another_one',
        type          => 'one',
        label         => 'One',
        required      => 0,
        once          => 0,
        default       => sub { TestApp::Simple::One->new },
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'search',
            tip  => 'One',
        )
    );

    $km->add_attribute(
        name     => 'color',
        type     => 'string',
        label    => 'Color',
        default  => undef,
        unique   => 1,
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'text',
            tip  => 'Color',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'Composed',
  'Composed',
  'Composeds',
  'Composeds',
  'Color',
  'Color'
);

1;
__END__
