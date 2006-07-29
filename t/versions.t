#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More;
use Test::NoWarnings; # Adds an extra test.
use Class::Trait;     # Avoid warnings.
use File::Spec::Functions qw(catdir);
use version;

eval "use Test::Pod::Coverage 0.08";
my @modules;
if ($@) {
    plan skip_all => "Test::Pod::Coverage required for testing versions";
}
else {
    # Not loading Object::Relation::Engine:: modules as they often require constants
    # which will not always be available
    @modules =
      grep { $_ ne 'Object::Relation' } Test::Pod::Coverage::all_modules();
    plan tests => @modules + 2;
}

use Object::Relation;
ok defined Object::Relation->VERSION,
    "Object::Relation should have a version number";
my $version = Object::Relation->VERSION; # Returns a version object.
SKIP: {
    skip "Object/Relation.pm did not have a version", scalar @modules
      unless defined $version;

    foreach my $module (@modules) {
        my $file = _package_to_file($module);
        is _get_version($file), $version,
            "$module should have the same version as Object::Relation";
    }
}

sub _package_to_file {
    my $package_name = shift;
    my @parts = split /::/, $package_name;
    unshift @parts, 'lib';
    my $file = catdir(@parts) . ".pm";
    return $file;
}

sub _get_version {
    my $file = shift;
    open my $fh, "<", $file or die "Cannot open ($file) for reading: $!";
    my $lines = do { local $/; <$fh> };
    close $fh;
    my ($version) = $lines =~ /VERSION\s*=\s*['"]?([\d.]+)['"]?;/;
    $version = version->new($version);
    return if $@;
    return $version->numify;
}
