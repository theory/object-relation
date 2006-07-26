package TestApp::CompComp;

use strict;
use warnings;

use Object::Relation::Meta;
use Object::Relation::Meta::Widget;
use Object::Relation::Language::en_us;

use TestApp::Composed;

BEGIN {
    my $km = Object::Relation::Meta->new(
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
        widget_meta   => Object::Relation::Meta::Widget->new(
            type => 'search',
            tip  => 'Composed',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'CompComp',
  'CompComp',
  'CompComps',
  'CompComps',
);

1;
__END__
