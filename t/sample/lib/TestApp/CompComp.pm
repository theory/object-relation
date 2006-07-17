package TestApp::CompComp;

use strict;
use warnings;

use Kinetic::Store::Meta;
use Kinetic::Store::Meta::Widget;
use Kinetic::Store::Language::en_us;

use TestApp::Composed;

BEGIN {
    my $km = Kinetic::Store::Meta->new(
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
        once          => 1,
        default       => sub { TestApp::Composed->new },
        widget_meta   => Kinetic::Store::Meta::Widget->new(
            type => 'search',
            tip  => 'Composed',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Store::Language::en->add_to_lexicon(
  'CompComp',
  'CompComp',
  'CompComps',
  'CompComps',
);

1;
__END__
