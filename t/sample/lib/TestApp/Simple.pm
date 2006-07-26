package TestApp::Simple;

use strict;
use warnings;

use Object::Relation::Meta;
use Object::Relation::Meta::Widget;
use Object::Relation::Language::en_us;

our $VERSION = version->new('1.1.0');

BEGIN {
    my $km = Object::Relation::Meta->new(
        key         => 'simple',
        name        => 'Simple',
        plural_name => 'Simples',
        store_config => {
            class => $ENV{OBJ_REL_CLASS},
            cache => $ENV{OBJ_REL_CACHE},
            user  => $ENV{OBJ_REL_USER},
            pass  => $ENV{OBJ_REL_PASS},
            dsn   => $ENV{OBJ_REL_DSN},
        },
    );
    $km->add_attribute(
        name        => 'name',
        label       => 'Name',
        type        => 'string',
        required    => 1,
        indexed     => 1,
        widget_meta => Object::Relation::Meta::Widget->new(
            type => 'text',
            tip  => 'The name of this object',
        )
    );
    $km->add_attribute(
        name        => 'description',
        label       => 'Description',
        type        => 'string',
        widget_meta => Object::Relation::Meta::Widget->new(
            type => 'textarea',
            tip  => 'The description of this object',
        )
    );

    $km->build;
}

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
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

