package TEST::Object::Traits::JSON;

use Class::Trait 'base';

use strict;
use warnings;
use aliased 'Object::Relation::Format';

##############################################################################

=head1 Available methods

=head2 sort_json

  $test->sort_json({
    json   => $json,     # json
    key    => $key,      # defaults to 'name'
    values => \@values,  # Will sort in order of these values,
  });

Given a JSON structure representing an AoH, this method will sort the hashes
by C<$key> in the order the keys are found in C<@values>.

=cut

my $sort_order = sub {
    my $names = shift;
    my %order_by = map { $names->[$_] => $_ } 0 .. $#$names;
    if ( keys %order_by != @$names ) {
        warn "# duplicate names found";
    }
    return \%order_by;
};

sub sort_json {
    my ($test, $arg_for) = @_;
    $arg_for->{key} ||= 'name';
    my $f = Format->new({format => 'json'});
    my $ref = $f->format_to_ref($arg_for->{json});
    my $order_by = $sort_order->($arg_for->{values});
    @$ref = sort { 
        $order_by->{$a->{$arg_for->{key}}}
            <=>
        $order_by->{$b->{$arg_for->{key}}}
    } @$ref;
    return $f->ref_to_format($ref);
}

1;
