package TEST::Object::Traits::Debug;

use Class::Trait 'base';

use strict;
use warnings;
use Test::More;

##############################################################################

=head1 Available methods

=head2 Instance methods

The following methods are are methods common debugging helpers.

=cut

##############################################################################

=head3 debug

  $test->debug(@data);

Foreach element in C<@data>, C<debug> will C<diag> a row of asterisks followed
by the data.  If the data is not a reference, it will simply be output with
C<diag>.  Otherwise, C<Data::Dumper> will be used to output the data.  At the
end of the debugging, the method will block while waiting for input from
C<< <STDIN> >>.  This gives the programmer time to read through the data.

=cut

sub debug {
    my ($test, @data) = @_;
    my $row = '*' x 78;
    foreach my $data (@data) {
        diag($row);
        if (ref $data) {
            require Data::Dumper;
            diag(Data::Dumper::Dumper($data));
        }
        else {
            diag($data);
        }
    }
    <STDIN>;
}

1;
