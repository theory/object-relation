package TestApp::Simple;
use base 'Kinetic';
use Kinetic::Util::Language::en_us;

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'simple',
        name        => 'Simple',
        plural_name => 'Simples',
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
