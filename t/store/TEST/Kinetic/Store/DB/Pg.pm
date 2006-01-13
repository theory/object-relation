package TEST::Kinetic::Store::DB::Pg;

# $Id: Pg.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;

use base 'TEST::Kinetic::Store::DB';
use Test::More;
use Test::Exception;
use Kinetic::Store qw/:all/;

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

# Skip all of the tests in this class if Postgres isn't supported.
__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->supported('pg')
      ? 0
      : "Not testing PostgreSQL"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

# This method is used by TEST::Kinetic::Store::DB to check unique constraint
# error messages.
sub unique_attr_regex {
    my ($self, $col, $key) = @_;
    # Sometimes its an index that enforces the constraint. Other times its
    # a constraint trigger that we install.
    return qr/duplicate key violates unique constraint "(?:idx_$key\_$col|ck_$key\_$col\_unique)"/;
}

sub delete_fk_regex {
    my ($self, $col, $key, $table) = @_;
    return qr/update or delete on (?:table )?"$table" violates foreign key constraint "fk_$key\_$col"/;
}

sub insert_fk_regex {
    my ($self, $col, $key, $table) = @_;
    return qr/insert or update on table "$table" violates foreign key constraint "fk_$key\_$col"/;
}

sub update_fk_regex { shift->insert_fk_regex(@_) }

sub full_text_search : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = $test->test_objects;
    my $class = $foo->my_class;
    my $store = Kinetic::Store->new;
    TODO: {
        local $TODO  = 'Full text search is not yet implemented.';
        my $iterator = $store->query($class => 'oo');
        my @results;
        eval {@results = $test->_all_items($iterator)};
        is @results, 1, '... and we should have the correct number of results';
        #is_deeply $results[0], $foo, '... and they should be the correct results';
    }
}

1;
