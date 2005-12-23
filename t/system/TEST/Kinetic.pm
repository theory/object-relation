package TEST::Kinetic;

# $Id$

use strict;
use warnings;

use base 'TEST::Class::Kinetic';

use Test::More;
use aliased 'Test::MockModule';

sub class_key { 'kinetic' }
sub class     { Kinetic::Meta->for_key(shift->class_key) };

sub dbh {
    my $self = shift;
    return $self->{dbh} unless @_;
    $self->{dbh} = shift;
    return $self;
}

sub setup : Test(setup) {
    my $self = shift;
    return $self unless $self->dev_testing;

    my $store   = Kinetic::Store->new;

    if ($store->isa('Kinetic::Store::DB')) {
        # Set up a mocked database handle with a running transaction.
        my $db_mock      = MockModule->new('Kinetic::Store::DB');
        $self->{db_mock} = $db_mock;
        my $dbh          = $store->_dbh;

        $db_mock->mock( _dbh => $dbh );
        $db_mock->mock( _begin_work => $store );
        $db_mock->mock( _commit     => $store );
        $db_mock->mock( _rollback   => $store );

        $dbh->begin_work;
        $self->dbh( $dbh );
    }

    # XXX Add support for non-DB data stores when/if necessary.
    return $self;
}

sub teardown : Test(teardown) {
    my $self = shift;
    return $self unless $self->dev_testing;

    # If we mocked DB and have a db handle, unmock and rollback.
    my $db_mock = delete $self->{db_mock} or return $self;
    $db_mock->unmock_all;
    my $dbh = $self->dbh or return $self;
    $dbh->rollback;

    # XXX Add support for non-DB data stores when/if necessary.
    return $self;
}

sub shutdown : Test(shutdown) {
    my $self = shift;
    return $self unless $self->dev_testing;

    # If there's a database handle, disconnect!
    my $dbh  = $self->dbh or return $self;
    $dbh->disconnect;

    # XXX Add support for non-DB data stores when/if necessary.
    return $self;
}

sub _test_load : Test(1) {
    my $self = shift;
    my $class_pkg = $self->test_class;
    use_ok $class_pkg or die;
}

sub test_new : Test(6) {
    my $self = shift;
    my $key  = $self->class_key;
    ok my $class = Kinetic::Meta->for_key($key), "Get $key class object";
    return qq{abstract class "$key"} if $class->abstract;

    ok my $pkg = $class->package, "Get $key package";
    ok my $obj = $pkg->new,       "Construct new $pkg object";

    isa_ok $obj, $pkg;
    isa_ok $obj, 'Kinetic';
    is $obj->uuid, undef,   '...Its UUID should be undef';

    # Test attributes.
}

sub test_save : Test(8) {
    my $self = shift;
    my $key  = $self->class_key;
    ok my $class = Kinetic::Meta->for_key($key), "Get $key class object";
    return qq{abstract class "$key"} if $class->abstract;

    ok my $pkg   = $class->package, "Get $key package";
    ok my $obj   = $pkg->new,       "Construct new $pkg object";
    is $obj->uuid, undef,           'UUID should be undef';

    return 'Not testing Data Stores' unless $self->dev_testing;

    ok $obj->save,                  "Save the $pkg object";
    ok my $uuid = $obj->uuid,       'UUID should be defined';

    # Now look it up.
    ok $obj = $pkg->lookup( uuid => $obj->uuid ), 'Look up the object';
    is $obj->uuid, $uuid, 'It should have the same UUID';
}

1;
__END__
