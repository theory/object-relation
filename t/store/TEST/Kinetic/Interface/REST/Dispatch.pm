package TEST::Kinetic::Interface::REST::Dispatch;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;

use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(0) }

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'Kinetic::Interface::REST';
use aliased 'Kinetic::Interface::REST::Dispatch';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
      ? 0
      : "Not testing Data Stores"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub setup : Test(setup) {
    my $test = shift;
    my $store = Store->new;
    $test->{dbh} = $store->_dbh;
    $test->{dbh}->begin_work;
    $test->{dbi_mock} = MockModule->new('DBI::db', no_auto => 1);
    $test->{dbi_mock}->mock(begin_work => 1);
    $test->{dbi_mock}->mock(commit => 1);
    $test->{db_mock} = MockModule->new('Kinetic::Store::DB');
    $test->{db_mock}->mock(_dbh => $test->{dbh});
    my $foo = One->new;
    $foo->name('foo');
    $store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    $store->save($bar);
    my $baz = One->new;
    $baz->name('snorfleglitz');
    $store->save($baz);
    $test->{test_objects} = [$foo, $bar, $baz];
    $test->{param} = sub {
        my $self = shift;
        my @query_string = @{$test->_query_string || []};
        my %param = @query_string;
        if (@_) {
            return $param{+shift};
        }
        else {
            my $i = 0;
            return grep { ! ($i++ % 2) } @query_string;
        }
    };

    # set up mock cgi and path methods
    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock(path_info => sub { $test->_path_info });
    $cgi_mock->mock(param => $test->{param});
    my $rest_mock = MockModule->new('Kinetic::Interface::REST');
    $rest_mock->mock(cgi => CGI->new);
    $test->{cgi_mock} = $cgi_mock;
    $test->{rest_mock} = $rest_mock;
    $test->{rest} = REST->new;
}

sub teardown : Test(teardown) {
    my $test = shift;
    delete($test->{dbi_mock})->unmock_all;
    $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
    delete($test->{db_mock})->unmock_all;
    delete($test->{cgi_mock})->unmock_all;
    delete($test->{rest_mock})->unmock_all;
}

sub _all_items {
    my ($test, $iterator) = @_;
    my @iterator;
    while (my $object = $iterator->next) {
        push @iterator => $test->_force_inflation($object);
    }
    return @iterator;
}

my $should_run;
sub _should_run {
    return $should_run if defined $should_run;
    my $test    = shift;
    my $store   = Store->new;
    my $package = ref $store;
    $should_run = ref $test eq "TEST::$package";
    return $should_run;
}

sub _query_string {
    my $test = shift;
    if (@_) {
        $test->{query_string} = [@_];
        return $test;
    }
    return $test->{query_string};
}

sub _path_info {
    my $test = shift;
    if (@_) {
        $test->{path_info} = shift;
        return $test;
    }
    return $test->{path_info};
}

sub echo : Test(5) {
    my $test = shift;
    can_ok Dispatch, 'echo';
    my $echo = *Kinetic::Interface::REST::Dispatch::echo{CODE};
    $test->_path_info('/echo/');
    my $rest = $test->{rest};
    $echo->($rest);
    is $rest->response, '',
        '... and calling with echo in the path should strip "echo"';
    is $rest->content_type, 'text/plain',
        '... and set the correct content type';

    $test->_path_info('/echo/foo/bar/baz/');
    $echo->($rest);
    is $rest->response, 'foo.bar.baz',
        '... and it should return extra path components separated by dots';

    $test->_query_string(qw/this that a b/);
    $echo->($rest);
    is $rest->response, 'foo.bar.baz.a.b.this.that',
        '... and query string items will be sorted and joined with dots';
}

sub can : Test(no_plan) {
    my $test = shift;
    can_ok Dispatch, 'can';
    ok ! Dispatch->can('no_such_resource'),
        '... and calling it with a non-existent Kinetic key should fail';
    my $rest = $test->{rest};
    my $key  = One->my_class->key;
    ok my $sub = Dispatch->can($key),
        'Calling can for a valid key should return a subref';
    ok $sub->($rest), "... and calling that subref should succeed";
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $expected = '';
    foreach my $object (sort { $a->guid cmp $b->guid } $foo, $bar, $baz) {
        $expected .= $object->guid."\t".$object->name."\n";
    }
    chomp $expected;
    #my $response = join "\n" => sort split "\n" => $rest->response;
    #is $response, $expected,
    #    'Calling a resource with no path info should a list of all objects';
    diag $rest->response;
}

1;
