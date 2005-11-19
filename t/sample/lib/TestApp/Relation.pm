package TestApp::Relation;
use base 'Kinetic';
use TestApp::Simple;
use TestApp::Simple::One;
use Kinetic::Util::Language::en_us;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'relation',
        name        => 'Relation',
        plural_name => 'Relations',
    );

    $km->add_attribute(
        name          => 'one',
        type          => 'one',
        label         => 'One',
        required      => 1,
        relationship  => 'extends',
        default       => sub { TestApp::Simple::One->new },
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'search',
            tip  => 'One',
        )
    );

    $km->add_attribute(
        name          => 'simple',
        type          => 'simple',
        label         => 'Simple',
        required      => 1,
        relationship  => 'mediates',
        default       => sub { TestApp::Simple->new },
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'search',
            tip  => 'Simple',
        )
    );

    # Add non-persistent attribute.
    $km->add_attribute(
        name        => 'tmp',
        label       => 'Temporary storage',
        type        => 'string',
        persistent  => 0,
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'Non-persistent temporary object storage',
        )
    );
    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
  'Relation',
  'Relation',
  'Relations',
  'Relations',
);

1;
__END__
