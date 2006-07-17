package TestApp::Relation;

use strict;
use warnings;

use Kinetic::Store;
use TestApp::Simple;
use TestApp::Simple::One;
use Kinetic::Store::Language::en_us;

meta relation => (
    plural_name => 'Relations',
    type_of     => 'one',
    mediates    => 'simple',
);

has tmp => (
    label       => 'Temporary storage',
    persistent  => 0,
    widget_meta => Kinetic::Store::Meta::Widget->new(
        type => 'text',
        tip  => 'Non-persistent temporary object storage',
    ),
);

build;

# Add new strings to the lexicon.
Kinetic::Store::Language::en->add_to_lexicon(
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
