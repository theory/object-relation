package TestApp::Simple::One;
use base 'TestApp::Simple';
use Object::Relation::Meta;
use Object::Relation::Language::en_us;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'one',
        name        => 'One',
        plural_name => 'Ones',
    );

    $km->add_attribute(
        name          => 'bool',
        type          => 'bool',
        label         => 'Bool',
        required      => 1,
        default       => 1,
        store_default => 1,
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'checkbox',
            tip  => 'Bool',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'One'  => 'One',
  'Ones' => 'Ones',
  'Bool' => 'Bool',
);

1;
__END__
