package TEST::Kinetic::Contact;

# $Id: Person.pm 2619 2006-02-13 18:41:00Z theory $

use strict;
use warnings;

use base 'TEST::Kinetic::Type::Contact';
use Test::More;
use Kinetic::Meta;
use Kinetic::Meta::Widget;
use Kinetic::Type::Contact;

sub class_key { 'contact' }

sub attr_values {
    return {
        contact_type => Kinetic::Type::Contact->new,
    }
}

1;
__END__
