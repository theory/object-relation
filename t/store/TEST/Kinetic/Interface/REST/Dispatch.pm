package TEST::Kinetic::Interface::REST::Dispatch;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;

use Kinetic::Util::Constants  qw/GUID_RE/;
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
    {
        local $^W; # because CGI.pm is throwing uninitialized errors :(
        $rest_mock->mock(cgi => CGI->new);
    }
    $test->{cgi_mock} = $cgi_mock;
    $test->{rest_mock} = $rest_mock;
    $test->{rest} = REST->new(
        domain => 'http://somehost.com/',
        path   => 'rest/'
    );
    $test->_path_info('');
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

sub test_can : Test(4) {
    my $test = shift;
    can_ok Dispatch, 'can';
    ok ! Dispatch->can('no_such_resource'),
        '... and calling it with a non-existent Kinetic key should fail';
    my $rest = $test->{rest};
    my $key  = One->my_class->key;
    ok my $sub = Dispatch->can($key),
        'Calling can for a valid key should return a subref';
    $test->_path_info('one');
    $sub->($rest); # return values are not guaranteed
    my $expected = <<'    END_XML';
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=browse"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>Available instances</kinetic:description>
      <kinetic:resource id="XXX" xlink:href="http://somehost.com/rest/one/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://somehost.com/rest/one/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://somehost.com/rest/one/XXX"/>
    </kinetic:resources>
    END_XML
    my $one_xml = $rest->response;
    $one_xml =~ s/@{[GUID_RE]}/XXX/g;
    is_xml $one_xml, $expected, 
        '... and calling it with a resource should return all instances of that resource';
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
<?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=browse"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">   
      <kinetic:description>Available resources</kinetic:description>
      <kinetic:resource id="one" xlink:href="http://somehost.com/rest/one"/>
      <kinetic:resource id="simple" xlink:href="http://somehost.com/rest/simple"/>
      <kinetic:resource id="two" xlink:href="http://somehost.com/rest/two"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->response, $expected, 
        '... and calling it should return a list of resources';
}

sub url_format : Test(5) {
    my $test = shift;
    # we don't use can_ok because of the way &can is overridden
    ok my $rest_url_format = *Kinetic::Interface::REST::Dispatch::_rest_url_format{CODE},
        '_rest_url_format() is defined in the Dispatch package';
    my $rest = $test->{rest};
    is $rest_url_format->($rest), 'http://somehost.com/rest/%s',
        '... and it should return a format without a resource or query string if they are not set';
    $test->_path_info('one');
    is $rest_url_format->($rest), 'http://somehost.com/rest/one/%s',
        '... but it should return the resource if requested';
    $test->_query_string(qw/type html/);
    is $rest_url_format->($rest), 'http://somehost.com/rest/one/%s?type=html',
        '... and the type, if it is set';
    $test->_query_string(qw/type xml/);
    is $rest_url_format->($rest), 'http://somehost.com/rest/one/%s',
        '... unless it is set to type=xml';
}

sub transform_xml_to_html : Test(no_plan) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};

    # we don't use can_ok because of the way &can is overridden
    ok my $class_list = *Kinetic::Interface::REST::Dispatch::_class_list{CODE},
        '_class_list() is defined in the Dispatch package';
    my $rest = $test->{rest};
    $class_list->($rest);

    $test->_query_string(qw/stylesheet browse/);
    ok my $transform = *Kinetic::Interface::REST::Dispatch::_transform{CODE},
        '_transform() is defined in the Dispatch package';

    my $html = $transform->($rest->response, $rest);
 
    my $expected = <<'    END_HTML';
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
 <html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Available resources</title>
  </head>
  <body>
    <table bgcolor="#eeeeee" border="1">
     <tr><th>Available resources</th></tr>
     <tr><td><a href="http://somehost.com/rest/one">one</a></td></tr>
     <tr><td><a href="http://somehost.com/rest/simple">simple</a></td></tr>
     <tr><td><a href="http://somehost.com/rest/two">two</a></td></tr>
    </table>
  </body>
</html>
    END_HTML
    is_xml $html, $expected, '... and the resource xml should be tranformed into the correct HTML';

    my $key  = One->my_class->key;
    my $sub = Dispatch->can($key);
    $test->_path_info('one');
    $sub->($rest);
    $expected = <<'    END_HTML';
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
 <html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Available instances</title>
  </head>
  <body>
    <table bgcolor="#eeeeee" border="1">
      <tr><th>Available instances</th></tr>
      <tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
      <tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
      <tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
    </table>
  </body>
</html>
    END_HTML
    $html = $transform->($rest->response, $rest);
    $html =~ s/@{[GUID_RE]}/XXX/g;
    is_xml $html, $expected, '... and the list of instances should be transformed correctly';

    $test->_query_string(qw/stylesheet instance/);
    $test->_path_info('one/'.$foo->guid);
    $sub->($rest);
    $expected = <<'    END_HTML';
<html xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
<head>
<title>Available instances</title>
</head>
<body><table bgcolor="#eeeeee" border="1">
<tr><th>Available instances</th></tr>
<tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
<tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
<tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
</table></body>
</html>
    END_HTML

    diag 'Finish object XSLT';
    return;
    $html = $transform->($rest->response, $rest);
    $html =~ s/@{[GUID_RE]}/XXX/g;
    #is_xml $html, $expected, '... and the instance XML should be transformed correctly';
    diag $html;
    diag $rest->response;
    <<'    END_XML';
    <?xml-stylesheet type="text/xsl" href="http://localhost:9000/?stylesheet=instance"?>
    <kinetic version="0.01">
      <instance key="simple">
        <attr name="description"></attr>
        <attr name="guid">10F62318-F7E5-11D9-9481-D6394B585510</attr>
        <attr name="name">foo</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML
}

1;
