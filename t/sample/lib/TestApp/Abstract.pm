package TestApp::Abstract;

use strict;
use warnings;

use Object::Relation::Meta;
use Object::Relation::Meta::Widget;
use Object::Relation::Language::en_us;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'abstract',
        name        => 'Abstract',
        plural_name => 'Abstracts',
        abstract    => 1,
    );

    $km->add_attribute(
        name        => 'name',
        label       => 'Name',
        type        => 'string',
        required    => 1,
        indexed     => 1,
        widget_meta => Object::Relation::Meta::Widget->new(
            type => 'text',
            tip  => 'The name of this object',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'Abstract',
  'Abstract',
  'Abstracts',
  'Abstracts',
);

1;
__END__
