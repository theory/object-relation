package TEST::Kinetic::Interface::REST::Dispatch;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;

use Kinetic::Util::Constants qw/GUID_RE/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'Kinetic::Interface::REST';
use aliased 'Kinetic::Interface::REST::Dispatch';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub setup : Test(setup) {
    my $test  = shift;
    my $store = Store->new;
    $test->{dbh} = $store->_dbh;
    $test->{dbh}->begin_work;
    $test->{dbi_mock} = MockModule->new( 'DBI::db', no_auto => 1 );
    $test->{dbi_mock}->mock( begin_work => 1 );
    $test->{dbi_mock}->mock( commit     => 1 );
    $test->{db_mock} = MockModule->new('Kinetic::Store::DB');
    $test->{db_mock}->mock( _dbh => $test->{dbh} );
    my $foo = One->new;
    $foo->name('foo');
    $store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    $store->save($bar);
    my $baz = One->new;
    $baz->name('snorfleglitz');
    $store->save($baz);
    $test->{test_objects} = [ $foo, $bar, $baz ];
    $test->{param} = sub {
        my $self         = shift;
        my @query_string = @{ $test->_query_string || [] };
        my %param        = @query_string;
        if (@_) {
            return $param{ +shift };
        }
        else {
            my $i = 0;
            return grep { !( $i++ % 2 ) } @query_string;
        }
    };

    # set up mock cgi and path methods
    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => sub { $test->_path_info } );
    $cgi_mock->mock( param => $test->{param} );
    my $rest_mock = MockModule->new('Kinetic::Interface::REST');
    {
        local $^W;    # because CGI.pm is throwing uninitialized errors :(
        $rest_mock->mock( cgi => CGI->new );
    }
    $test->{cgi_mock}  = $cgi_mock;
    $test->{rest_mock} = $rest_mock;
    $test->{rest}      = REST->new(
        domain => 'http://somehost.com/',
        path   => 'rest/'
    );
    $test->_path_info('');
    $test->{query_string} = undef;
}

sub teardown : Test(teardown) {
    my $test = shift;
    delete( $test->{dbi_mock} )->unmock_all;
    $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
    delete( $test->{db_mock} )->unmock_all;
    delete( $test->{cgi_mock} )->unmock_all;
    delete( $test->{rest_mock} )->unmock_all;
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

sub class_list : Test(2) {
    my $test = shift;

    # we don't use can_ok because of the way &can is overridden
    ok my $class_list = *Kinetic::Interface::REST::Dispatch::_class_list{CODE},
      '_class_list() is defined in the Dispatch package';
    my $rest = $test->{rest};
    $class_list->($rest);
    my $expected = <<'    END_XML';
<?xml version="1.0"?>
    <?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
    <kinetic:description>Available resources</kinetic:description>
          <kinetic:resource id="one" xlink:href="http://somehost.com/rest/one/search"/>
          <kinetic:resource id="simple" xlink:href="http://somehost.com/rest/simple/search"/>
          <kinetic:resource id="two" xlink:href="http://somehost.com/rest/two/search"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->response, $expected,
      '... and calling it should return a list of resources';
}

sub handle : Test(4) {
    my $test = shift;
    ok my $handle =
      *Kinetic::Interface::REST::Dispatch::_handle_rest_request{CODE},
      '_handle_rest_request() is defined in the Dispatch package';
    my $rest = $test->{rest};

    my $key = One->my_class->key;

    # The error message used path info
    $test->_path_info("/$key/");
    $handle->( $rest, $key );
    is $rest->response, "No resource available to handle (/$key/)",
      'Calling _handle_rest_request() no message should fail';

    $handle->( $rest, $key, 'search' );
    ( my $response = $rest->response ) =~ s/@{[GUID_RE]}/XXX/g;
    my $expected = <<'    END_XML';
<?xml version="1.0"?>
    <?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                    xmlns:xlink="http://www.w3.org/1999/xlink">
    <kinetic:description>Available instances</kinetic:description>
        <kinetic:resource 
            id="XXX" 
            xlink:href="http://somehost.com/rest/one/lookup/guid/XXX"/>
        <kinetic:resource 
            id="XXX" 
            xlink:href="http://somehost.com/rest/one/lookup/guid/XXX"/>
        <kinetic:resource 
            id="XXX" 
            xlink:href="http://somehost.com/rest/one/lookup/guid/XXX"/>
    </kinetic:resources>
    END_XML
    is_xml $response, $expected,
'Calling _handle_rest_request with a path of /$key/search should return all instances of said key';

    my ( $foo, $bar, $baz ) = @{ $test->{test_objects} };
    my $foo_guid = $foo->guid;
    $handle->( $rest, $key, 'lookup', [ 'guid', $foo_guid ] );
    $expected = <<"    END_XML";
    <?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=instance"?>
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description"></attr>
        <attr name="guid">$foo_guid</attr>
        <attr name="name">foo</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML
    is_xml $rest->response, $expected,
        '... and $class_key/lookup/guid/$guid should return instance XML';
}

1;
