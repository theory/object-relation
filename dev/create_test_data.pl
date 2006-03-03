#!/usr/bin/perl

# $Id$

use strict;
use warnings;
use Getopt::Long;
BEGIN { $ENV{KINETIC_CONF} ||= 't/conf/kinetic.conf' }
use lib 't/lib/', 'lib', 't/sample/lib';
use Kinetic::Meta;
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';
use aliased 'Kinetic::DataType::DateTime';
use aliased 'Kinetic::Store';
use aliased 'Kinetic::Party::User';

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
    age         => 23
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
            age         => ( $_ + 24 ),
        )->save;
    }
}

print "Creating test user objects (ovid, ovidius) (theory, theory) ...\n\n";
User->new(
    username => 'ovid',
    password => 'ovidius',
)->save;
User->new(
    username => 'theory',
    password => 'theory',
)->save;

__END__

=head1 create_test_data.pl

Test the Kinetic Rest Server

=head1 SYNOPSIS

 create_test_data.pl [options]

Options:

 -i, --instances=$num  The number of test 'Two' object instances to create for
                       paging tests.  Default is 20.

=head1 NOTES

This script assumes that an B<empty> Kinetic data store has been set up.  It
will attempt to connect to the data store and add some objects to it.
