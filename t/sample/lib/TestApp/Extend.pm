package TestApp::Extend;

use strict;
use warnings;

use Kinetic::Store::Meta;
use Kinetic::Store::Meta::Widget;
use Kinetic::Store::Language::en_us;

use TestApp::Simple::Two;

BEGIN {
    my $km = Kinetic::Store::Meta->new(
        key         => 'extend',
        name        => 'Extend',
        plural_name => 'Extends',
        extends     => 'two',
    );

    $km->build;
}

# Add new strings to the lexicon.
Kinetic::Store::Language::en->add_to_lexicon(
  'Extend',
  'Extend',
  'Extends',
  'Extends',
);

1;
