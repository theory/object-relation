package TEST::Kinetic::Traits::HTML;

#use Class::Trait 'base';

use strict;
use warnings;

# note that the following is a stop-gap measure until Class::Trait has
# a couple of bugs fixed.  Bugs have been reported back to the author.
#
# Traits would be useful here as the REST and REST::Dispatch classes are
# coupled, but not by inheritance.  The tests need to share functionality
# but since inheritance is not an option, I will be importing these methods
# directly into the required namespaces.

use Exporter::Tidy default => [ qw/ instance_table / ];

sub instance_table {
    my ($test, @objects) = @_;
    my $table = '<table bgcolor="#eeeeee" border="1"><tr>';
    my @attributes = $test->desired_attributes;
    foreach my $attr (@attributes) {
        $table .= "<th>$attr</th>";
    }
    $table .= '</tr>';
    foreach my $object (@objects) {
        my $uuid = $object->uuid;
        $table .= '<tr>';
        foreach my $attr (@attributes) {
            my $value = ($object->$attr||'');
            $table .= <<"            END_ATTR";
    <td>
    <a href="http://localhost:9000/rest/one/lookup/uuid/$uuid?type=html">$value</a>
    </td>
            END_ATTR
        }
        $table .= '</tr>';
    }
    $table .= '</table>';
    return $table;
}

1;
