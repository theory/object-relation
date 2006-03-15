package TestApp::CompComp;

use strict;
use warnings;

use Kinetic::Meta;
use Kinetic::Meta::Widget;
use Kinetic::Util::Language::en_us;

use TestApp::Composed;

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
        once          => 1,
        default       => sub { TestApp::Composed->new },
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'search',
            tip  => 'Composed',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Util::Language::en->add_to_lexicon(
  'CompComp',
  'CompComp',
  'CompComps',
  'CompComps',
);

1;
__END__
