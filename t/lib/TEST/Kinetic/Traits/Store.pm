package TEST::Kinetic::Traits::Store;

# $Id$

use Class::Trait 'base';

use strict;
use warnings;

# note that the following is a stop-gap measure until Class::Trait has
# a couple of bugs fixed.  Bugs have been reported back to the author.

use aliased 'Test::MockModule';

my $debugging = 0;

##############################################################################

=head3 mock_dbh

  $test->mock_dbh;

This method sets C<< $test->{dbh} >> and also mocks up its C<begin_work> and
C<commit> methods so we don't accidentally commit anything to the test
database.

=cut

sub mock_dbh {
    my $test  = shift;
    my $store = Kinetic::Store::Handle->new({
        class => $ENV{KS_CLASS},
        cache => $ENV{KS_CACHE},
        user  => $ENV{KS_USER},
        pass  => $ENV{KS_PASS},
        dsn   => $ENV{KS_DSN},
    });

    $test->dbh( $store->_dbh );
    unless ($debugging) {    # give us an easy debugging hook
        $test->dbh->begin_work;
        $test->{dbi_mock} = MockModule->new( 'DBI::db', no_auto => 1 );
        $test->{dbi_mock}->mock( begin_work => 1 );
        $test->{dbi_mock}->mock( commit     => 1 );
        $test->{db_mock} = MockModule->new('Kinetic::Store::Handle::DB');
        $test->{db_mock}->mock( _dbh => $test->dbh );
    }
}

##############################################################################

=head3 unmock_dbh

  $test->unmock_dbh;

Unmocks previously mocked database handle. Carps if the database handle was
not previously mocked.

=cut

sub unmock_dbh {
    my $test = shift;
    if ($debugging) {
        $test->dbh->commit;
    }
    else {
        if ( exists $test->{dbi_mock} ) {
            delete( $test->{dbi_mock} )->unmock_all;
            $test->dbh->rollback unless $test->dbh->{AutoCommit};
            delete( $test->{db_mock} )->unmock_all;
        }
        else {
            require Carp;
            Carp::carp("Could not unmock database handle.");
        }
    }
}

##############################################################################

=head3 unmock_dbh

sub shutdown_dbh : Test(shutdown) {
    shift->disconnect_dbh;
}

Designed to be called in a shutdown test method, this method checks to see if
C<dbh()> returns a database handle, and if it does, it disconnects it. This is
important, so that all connections to the database can be disconnected before
dropping the database.

=cut

sub disconnect_dbh {
    my $self = shift;
    my $dbh  = $self->dbh or return $self;
    $dbh->disconnect;
    return $self;
}

##############################################################################

=head3 desired_attributes

  $test->desired_attributes(\@attribute_names);
  my @objects = $test->desired_attributes;

Simple getter/setter for attributes desired from objects.  If called in scalar
context, returns an array ref of attribute names.  Otherwise, returns a list of
them.

This method is called by several other trait methods which need to know which
attributes from which to pull data from objects.

=cut

sub desired_attributes {
    my $test = shift;
    unless (@_) {
        return wantarray ? @{ $test->{attributes} } : $test->{attributes};
    }
    $test->{attributes} = shift;
    return $test;
}

##############################################################################

=head3 force_inflation

  $object = $test->force_inflation($object);

This method is used by classes to force the inflation of values of Kinetic
objects when tested with is_deeply and friends.

=cut

sub force_inflation {
    my ( $test, $object ) = @_;
    return unless $object;
    no warnings 'void';
    foreach my $attr ( $object->my_class->attributes ) {
        if ( $attr->references ) {
            $test->force_inflation( $attr->get($object) );
        }
        else {
            $attr->get($object);
        }
    }
    return $object;
}

##############################################################################

=head3 clear_database

  $test->clear_database;

Clears the data store.

=cut

sub clear_database {

    # Call this method if you have a test which needs an empty database.
    my $test = shift;
    if ( $test->{dbi_mock} ) {
        $test->{dbi_mock}->unmock_all;
        $test->dbh->rollback;
        $test->dbh->begin_work;
        $test->{dbi_mock}->mock( begin_work => 1 );
        $test->{dbi_mock}->mock( commit     => 1 );
    }
    else {
        my %keys = map { $_ => 1 }
          grep { !Kinetic::Meta->for_key($_)->abstract } Kinetic::Meta->keys;

        # it's possible that we'll accidentally try to delete a key which has
        # an FK constraint on another key.  To avoid this, we keep deleting
        # keys until there are none left.  If, at any time, we have failed to
        # delete a key on a given pass, we know there was a circular
        # dependency and we carp.  This should not happen.

        while ( my $count = keys %keys ) {
            foreach my $key ( keys %keys ) {    # confused yet?
                eval { $test->{dbh}->do("DELETE FROM $key") };
                delete $keys{$key} unless $@;
            }
            if ( $count == keys %keys ) {
                my @keys = sort keys %keys;
                require Carp;
                Carp::carp(
                    "Could not delete all records from db for (@keys)");
            }
        }
    }
}

##############################################################################

=head3 dbh

  my $dbh = $test->dbh;
  $test->dbh($dbh);

Getter/setter for database handle.

=cut

sub dbh {
    my $self = shift;
    return $self->{dbh} unless @_;
    $self->{dbh} = shift;
    return $self;
}

1;
