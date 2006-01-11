package TestApp::Simple::Two;
use base 'TestApp::Simple';
use TestApp::Simple::One;
use Kinetic::Util::Language::en_us;
use aliased 'Kinetic::Meta::Type';
use Kinetic::DataType::DateTime;

BEGIN {
    my $km = Kinetic::Meta->new(
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
        widget_meta   => Kinetic::Meta::Widget->new(
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
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'Age',
        )
    );

    $km->add_attribute(
        name          => 'date',
        type          => 'datetime',
        label         => 'Date',
        required      => 1,
        default       => sub { Kinetic::DataType::DateTime->now },
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'calendar',
            tip  => 'Date',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
  'Two'  => 'Two',
  'Twos' => 'Twos',
  'Age'  => 'Age',
  'Date' => 'Date',
);

1;
__END__
