#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib', 't/store', 't/lib', 't/sample/lib';
use TEST::Kinetic::UI::REST;
use TEST::Kinetic::Store;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(0) }

foreach my $module (sort keys %INC) {
    $module =~ s/\.pm$//;
    $module =~ s/\//::/g;
    next if $module =~ /^::/;
    eval "use $module";
    if ($@) {
        print "Cannot use ($module): $@";
    }
    else {
        printf "$module->VERSION %s\n", $module->VERSION || 'unknown';
    }
}
