package TestApp::Abstract;
use base 'Kinetic';
use Kinetic::Util::Language::en_us;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'abstract',
        name        => 'Abstract',
        plural_name => 'Abstracts',
        abstract    => 1,
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

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
  'Abstract',
  'Abstract',
  'Abstracts',
  'Abstracts',
);

1;
__END__
