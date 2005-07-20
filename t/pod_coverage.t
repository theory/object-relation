#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More;
eval "use Test::Pod::Coverage 0.08";
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;

my %TODO = map { $_ => 1 } qw/
    Kinetic::Store::Parser
    Kinetic::Util::Stream
/;
diag "Don't forget to update the pod at some point"
  if %TODO;

# Whether or not the POD coverage tests fails depends upon
# whether or not your are using prove or ./Build test
# This was *not* fun to debug

my %exceptions = (
    'Kinetic::Interface::REST'   => qr/^Dispatch|XSLT$/,
    'Kinetic::Store'             => qr/^ASC|DESC|EQ|NE$/,
    'Kinetic::Store::DB'         => qr/^Incomplete|Iterator|Meta|Search$/,
    'Kinetic::Store::Lexer'      => qr/^allinput|blocks|iterator_to_stream|make_lexer|tokens|records$/,
    'Kinetic::Store::Parser::DB' => qr/^Search$/,
    'Kinetic::Store::Search'     => qr/^Incomplete$/,
    'Kinetic::Util::Collection'  => qr/^Iterator$/,
    'Kinetic::View::XSLT'        => qr/^LibXML|LibXSLT$/,
    'Kinetic::XML'               => qr/^XML$/,
);

my @modules = grep { ! exists $exceptions{$_} } Test::Pod::Coverage::all_modules();
plan tests => @modules + keys %exceptions;

foreach my $module (@modules) {
    if (exists $TODO{$module}) {
        TODO: {
            local $TODO = "Known incomplete POD for $module";
            pod_coverage_ok($module);
        };
    }
    else {
        pod_coverage_ok($module);
    }
}

while (my ($module, $subs_to_ignore) = each %exceptions) {
    pod_coverage_ok( $module, { trustme => [$subs_to_ignore] } );
}
