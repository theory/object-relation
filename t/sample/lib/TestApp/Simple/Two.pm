package TestApp::Simple::Two;
use base 'TestApp::Simple';
use TestApp::Simple::One;
use Kinetic::Util::Language::en_us;

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
            type => 'profile',
            tip  => 'One',
        )
    );

    $km->add_attribute(
        name     => 'age',
        type     => 'whole',
        label    => 'Age',
        default  => undef,
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en_us->add_to_lexicon(
  'Two'  => 'Two',
  'Twos' => 'Twos',
);

1;
__END__
