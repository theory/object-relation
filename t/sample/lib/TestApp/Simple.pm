package TestApp::Simple;

use strict;
use warnings;

use Kinetic::Meta;
use Kinetic::Meta::Widget;
use Kinetic::Util::Language::en_us;

our $VERSION = version->new('1.1.0');

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'simple',
        name        => 'Simple',
        plural_name => 'Simples',
        store_config => {
            class => $ENV{KS_CLASS},
            cache => $ENV{KS_CACHE},
            user  => $ENV{KS_USER},
            pass  => $ENV{KS_PASS},
            dsn   => $ENV{KS_DSN},
        },
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

=head1 NAME

TestApp::Simple - Simple application for testing

=cut

