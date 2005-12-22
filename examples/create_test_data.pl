#!/usr/bin/perl

# $Id: rest_test.pl 1388 2005-03-17 05:53:43Z theory $

use strict;
use warnings;
use Getopt::Long;
use lib 't/lib/', 'lib', 't/sample/lib';
use Kinetic::Meta;
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';
use aliased 'Kinetic::DateTime';
use aliased 'Kinetic::Store';

our $VERSION = 1.0;

GetOptions(
    'instances=i' => \my $instances,
);
$instances ||= 20;

print "Creating test objects\n";

my $foo = One->new(
    name        => 'foo',
    description => 'This is the "foo" object',
);
$foo->save;

One->new(
    name        => 'bar',
    description => 'This is the "bar" object',
)->save;

One->new(
    name        => 'snorfleglitz',
    description => 'Who knows what the hell this is?',
)->save;

Two->new(
    name        => 'Two',
    description => 'Who are you?',
    date        => DateTime->now,
    one         => $foo,
    age         => 22
)->save;

Two->new(
    name        => 'Publius Ovidius Naso',
    description => 'The poet "Ovid"',
    date        => DateTime->now,
    one         => $foo,
    age         => 60
)->save;

print "Creating $instances 'Two' objects for paging tests ...\n\n";
{
    local $| = 1;    # temporarily turn off buffering
    for ( 1 .. $instances ) {
        printf "%4d", $_;
        print "\n" unless $_ % 10;
        Two->new(
            name        => "Two $_",
            description => "Object number $_",
            date        => DateTime->now,
            one         => $foo,
            age         => ( $_ + 2 ),
        )->save;
    }
}

__END__
print "Hit <RETURN> to delete test data\n";
<STDIN>;

my $store = Store->new;
my $dbh   = $store->_dbh;
print "Deleting objects in database\n";
foreach my $key ( Kinetic::Meta->keys ) {
    next if Kinetic::Meta->for_key($key)->abstract;
    eval { $dbh->do("DELETE FROM $key") };
    warn "Could not delete records from $key: $@" if $@;
}

__END__

=head1 REST Server test

Test the Kinetic Rest Server

=head1 SYNOPSIS

 rest_server.pl [options]

Options:

 -p, --port=$num       Specify a port number to run the server on.  Default 
                       is port 9000.
 -i, --instances=$num  The number of test 'Two' object instances to create for
                       paging tests.  Default is 20.
 -n, --no-cache        CSS, Javascript, images and XSLT will not be cached if
                       this option is set.  Useful for debugging.

=head1 NOTES

This script assumes that an B<empty> Kinetic data store has been set up.  It
will attempt to connect to the data store and add some objects to it.  Then it
will launch a test web server on port 9000 (you may specify an optional port
number on the command line).  Access the server by opening a browser and using
the url C<http://localhost:$port/>.

The script will hang, prompting you to hit <RETURN>.  When you do, the server
will be shut down and B<all> records deleted from the data store.
