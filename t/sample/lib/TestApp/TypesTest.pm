package TestApp::TypesTest;
use base 'Kinetic';
use Kinetic::Util::Language::en_us;
use Kinetic::DataType::Duration;
use Kinetic::DataType::MediaType;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'types_test',
        name        => 'Types Test',
        plural_name => 'Types Tests',
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
        widget_meta => Kinetic::Meta::Widget->new(
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

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
  'Types Test',
  'Types Test',
);

1;
__END__