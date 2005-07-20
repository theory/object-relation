#!/usr/bin/perl

# $Id: rest_test.pl 1388 2005-03-17 05:53:43Z theory $

use strict;
use warnings;
use lib 't/lib/', 'lib', 't/sample/lib';
use Kinetic::Meta;
use Kinetic::Store;
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';
use TEST::REST::Server;

my $port = shift || 9000;

print "Creating test objects\n";
my $store = Kinetic::Store->new;
my $foo = One->new;
$foo->name('foo');
$foo->description('This is the "foo" object');
$store->save($foo);
my $bar = One->new;
$bar->name('bar');
$bar->description('This is the "bar" object');
$store->save($bar);
my $baz = One->new;
$baz->name('snorfleglitz');
$baz->description('Who knows what the hell this is?');
$store->save($baz);

print "Starting test server on localhost:$port\n";
my $server = TEST::REST::Server->new({
    domain => "http://localhost:$port/",
    path   => '',
    args   => [$port],
});

my $pid = $server->background;

print "Hit <RETURN> to stop the server\n";
<STDIN>;

my $dbh = $store->_dbh;
print "Deleting objects in database\n";
foreach my $key (Kinetic::Meta->keys) {
    next if Kinetic::Meta->for_key($key)->abstract;
    eval { $dbh->do("DELETE FROM $key") };
    warn "Could not delete records from $key: $@" if $@;
}

kill 9, $pid;

__END__

=head1 REST Server test

Test the Kinetic Rest Server

=head1 SYNOPSIS

 rest_server.pl [port_number]

=head1 NOTES

This script assumes that an B<empty> Kinetic data store has been set up.  It
will attempt to connect to the data store and add some objects to it.  Then it
will launch a test web server on port 9000 (you may specify an optional port
number on the command line).  Access the server by opening a browser and using
the url C<http://localhost:$port/>.

The script will hang, prompting you to hit <RETURN>.  When you do, the server
will be shut down and B<all> records deleted from the data store.
