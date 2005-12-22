package TestApp::Composed;
use base 'Kinetic';
use TestApp::Simple::One;
use Kinetic::Util::Language::en_us;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'composed',
        name        => 'Composed',
        plural_name => 'Composeds',
    );

    $km->add_attribute(
        name          => 'one',
        type          => 'one',
        label         => 'One',
        required      => 0,
        once          => 1,
        default       => sub { TestApp::Simple::One->new },
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'search',
            tip  => 'One',
        )
    );

    $km->add_attribute(
        name     => 'color',
        type     => 'string',
        label    => 'Color',
        default  => undef,
        unique   => 1,
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'Color',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
  'Composed',
  'Composed',
  'Composeds',
  'Composeds',
);

1;
__END__
