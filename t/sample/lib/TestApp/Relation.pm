package TestApp::Relation;
use base 'Kinetic';
use TestApp::Simple;
use TestApp::Simple::One;
use Kinetic::Util::Language::en_us;
use Kinetic::Meta::Declare ':all';
use Kinetic::Meta::Widget;

Kinetic::Meta::Declare->new(
    meta => [
        key         => 'relation',
        plural_name => 'Relations',
        type_of     => 'one',
        mediates    => 'simple',
    ],
    attributes => [
        tmp => {
            label       => 'Temporary storage',
            persistent  => 0,
            widget_meta => Kinetic::Meta::Widget->new(
                type => 'text',
                tip  => 'Non-persistent temporary object storage',
            ),
        },
    ]
);

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
    'Relation',
    'Relation',
    'Relations',
    'Relations',
    'Non-persistent temporary object storage',
    'Non-persistent temporary object storage',
    'Temporary storage',
    'Temporary storage',
);

1;
__END__
