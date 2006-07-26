package TestApp::Simple::Two;
use base 'TestApp::Simple';
use TestApp::Simple::One;
use Object::Relation::Language::en_us;
use aliased 'Object::Relation::Meta::Type';
use Object::Relation::DataType::DateTime;

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'two',
        name        => 'Two',
        plural_name => 'Twos',
    );

    $km->add_attribute(
        name          => 'one',
        type          => 'one',
        label         => 'One',
        required      => 1,
        default       => sub { TestApp::Simple::One->new },
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'search',
            tip  => 'One',
        )
    );

    $km->add_attribute(
        name     => 'age',
        type     => 'whole',
        label    => 'Age',
        default  => undef,
        unique   => 1,
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'text',
            tip  => 'Age',
        )
    );

    $km->add_attribute(
        name          => 'date',
        type          => 'datetime',
        label         => 'Date',
        required      => 1,
        default       => sub { Object::Relation::DataType::DateTime->now },
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'calendar',
            tip  => 'Date',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'Two'  => 'Two',
  'Twos' => 'Twos',
  'Age'  => 'Age',
  'Date' => 'Date',
);

1;
__END__
