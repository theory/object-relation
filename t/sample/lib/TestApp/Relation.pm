package TestApp::Relation;

use strict;
use warnings;

use Object::Relation;
use TestApp::Simple;
use TestApp::Simple::One;
use Object::Relation::Language::en_us;

meta relation => (
    plural_name => 'Relations',
    type_of     => 'one',
    mediates    => 'simple',
);

has tmp => (
    label       => 'Temporary storage',
    persistent  => 0,
    widget_meta => Object::Relation::Meta::Widget->new(
        type => 'text',
        tip  => 'Non-persistent temporary object storage',
    ),
);

build;

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
    'Relation',
    'Relation',
    'Relations',
    'Relations',
    'Non-persistent temporary object storage',
    'Non-persistent temporary object storage',
    'Temporary storage',
    'Temporary storage',
);

1;
__END__
