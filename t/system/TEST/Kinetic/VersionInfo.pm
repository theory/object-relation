package TEST::Kinetic::VersionInfo;

# $Id$

use strict;
use warnings;

use base 'TEST::Kinetic';
use Test::More;

sub class_key { 'version_info' }

sub attr_values {
    return {
        app_name => '_foo_',
        version  => version->new('1.1.12'),
    };
}

# XXX This allows $Kinetic::VERSION to work. No idea why it's necessary.
use Kinetic;

#sub test_kinetic_version : Test(5) {
sub test_kinetic_version {
    my $self = shift;
    return 'Not testing Data Stores' unless $self->dev_testing;

    # We should have version info for Kinetic itself.
    ok my $vi = Kinetic::VersionInfo->lookup( app_name => 'Kinetic' ),
        'There should already be a Kinetic version object';
    is $vi->app_name, 'Kinetic', 'Its app_name should be "Kinetic"';
    isa_ok $vi->version, 'version', 'Its version object';
    isa_ok $Kinetic::VERSION, 'version', '$Kinetic::VERSION';
    is $vi->version, $Kinetic::VERSION, 'Its version number should be correct';
}

1;
__END__
