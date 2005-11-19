package TestApp::Simple;
use base 'Kinetic';
use Kinetic::Util::Language::en_us;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'simple',
        name        => 'Simple',
        plural_name => 'Simples',
    );
    $km->add_attribute(
        name        => 'name',
        label       => 'Name',
        type        => 'string',
        required    => 1,
        indexed     => 1,
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'The name of this object',
        )
    );
    $km->add_attribute(
        name        => 'description',
        label       => 'Description',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'textarea',
            tip  => 'The description of this object',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
  'Simple',
  'Simple',
  'Simples',
  'Simples',
);

1;
__END__
