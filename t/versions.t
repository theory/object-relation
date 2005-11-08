#!/usr/bin/perl -w

# $Id: accessors.t 1829 2005-07-02 01:53:14Z curtis $

use strict;
use warnings;
use Test::More;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(0) }

eval "use Test::Pod::Coverage 0.08";
my @modules;
if ($@) {
    plan skip_all => "Test::Pod::Coverage required for testing versions";
}
else {
    @modules =
      #grep { /^Kinetic/ }    # XXX remove after testing
      grep { $_ ne 'Kinetic' } Test::Pod::Coverage::all_modules();
    plan tests => @modules + 1;
}

use Kinetic;
ok defined Kinetic->VERSION, "Kinetic should have a version number";
my $version = Kinetic->VERSION;
SKIP: {
    skip "Kinetic.pm did not have a version", scalar @modules
      unless defined $version;

    foreach my $module (@modules) {
        eval "require $module";
        if ( my $error = $@ ) {
            if ( $error =~ /Unknown tag/ )
            {    # we probably have the wrong db class
              SKIP: {
                    skip "Wrong data store for $module", 1;
                }
            }
            else {
                fail "Could not load ($module): $@";
            }
        }
        else {
            is $module->VERSION, $version,
              "$module should have the same version as Kinetic.pm";
        }
    }
}
