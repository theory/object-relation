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
        type_of     => 'one',
        mediates    => 'simple',
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
