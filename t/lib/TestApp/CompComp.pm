package TestApp::CompComp;
use base 'Kinetic';
use TestApp::Composed;
use Kinetic::Util::Language::en_us;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'comp_comp',
        name        => 'CompComp',
        plural_name => 'CompComps',
    );

    $km->add_attribute(
        name          => 'composed',
        type          => 'composed',
        label         => 'Composed',
        required      => 1,
        on_delete     => 'RESTRICT',
        default       => sub { TestApp::Composed->new },
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'profile',
            tip  => 'Composed',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en_us->add_to_lexicon(
  'CompComp',
  'CompComp',
  'CompComps',
  'CompComps',
);

1;
__END__
