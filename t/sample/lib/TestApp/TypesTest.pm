package TestApp::TypesTest;

use strict;
use warnings;

use Object::Relation::Meta;
use Object::Relation::Meta::Widget;
use Object::Relation::Language::en_us;
use Object::Relation::DataType::Duration;
use Object::Relation::DataType::MediaType;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'types_test',
        name        => 'Types Test',
        plural_name => 'Types Tests',
    );

    $km->add_attribute(
        name        => 'integer',
        label       => 'Integer',
        type        => 'integer',
        required    => 1,
    );

    $km->add_attribute(
        name        => 'whole',
        label       => 'Whole',
        type        => 'whole',
    );

    $km->add_attribute(
        name        => 'posint',
        label       => 'Posint',
        type        => 'posint',
    );

    $km->add_attribute(
        name        => 'version',
        label       => 'Version',
        type        => 'version',
        required    => 1,
    );

    $km->add_attribute(
        name        => 'duration',
        label       => 'Duration',
        type        => 'duration',
        required    => 1,
        indexed     => 1,
        widget_meta => Object::Relation::Meta::Widget->new(
            type => 'interval',
            tip  => 'An interval of time',
        )
    );

    $km->add_attribute(
        name        => 'operator',
        label       => 'Operator',
        type        => 'operator',
        required    => 1,
    );

    $km->add_attribute(
        name        => 'media_type',
        label       => 'Media Type',
        type        => 'media_type',
        required    => 1,
    );

    $km->add_attribute(
        name        => 'attribute',
        label       => 'Attribute',
        type        => 'attribute',
    );

    $km->add_attribute(
        name        => 'gtin',
        label       => 'GTIN',
        type        => 'gtin',
    );

    $km->add_attribute(
        name        => 'bin',
        label       => 'Binary',
        type        => 'binary',
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'Types Test',
  'Types Test',
);

1;
__END__
