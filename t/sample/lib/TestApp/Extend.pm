package TestApp::Extend;

use strict;
use warnings;

use Object::Relation::Meta;
use Object::Relation::Meta::Widget;
use Object::Relation::Language::en_us;

use TestApp::Simple::Two;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'extend',
        name        => 'Extend',
        plural_name => 'Extends',
        extends     => 'two',
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'Extend',
  'Extend',
  'Extends',
  'Extends',
);

1;
