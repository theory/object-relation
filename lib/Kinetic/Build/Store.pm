package Kinetic::Build::Store;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;
use Kinetic::Build;
use Kinetic::Util::Config qw(:store);

=head1 Name

Kinetic::Build::Store - Kinetic data store builder

=head1 Synopsis

  use Kinetic::Build::Store;
  my $kbs = Kinetic::Build::Store->new;
  $kbs->build($filename);

=head1 Description

This module builds a data store using the a schema output by
L<Kinetic::Build::Schema|Kinetic::Build::Schema> to the a file. The data store
will be built for the data store class specified by the C<STORE_CLASS>
F<kinetic.conf> directive.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $kbs = Kinetic::Build::Store->new;

Creates and returns a new Store builder object. This is a factory constructor;
it will return the subclass appropriate to the currently selected store class
as configured in F<kinetic.conf>.

=cut

sub new {
    my $class = shift;
    unless ($class ne __PACKAGE__) {
        $class = shift || STORE_CLASS;
        $class =~ s/^Kinetic::Store/Kinetic::Build::Store/;
        eval "require $class" or die $@;
    }
    bless {
        metadata => Kinetic::Build->resume,
    } => $class;
}

##############################################################################

=head3 metadata

  my $metadata = $kbs->metadata;

Returns the C<Kinetic::Build> object used to determine build properties.

=cut

sub metadata { $_[0]->{metadata} }

##############################################################################

=head3 build

  $kbs->build($dir);

Passed the name of a directory where the appropriate classes are located, this
method will build a database representing those classes in the database
specified by C<Kinetic::Build>.

=cut

sub build {
    my ($self) = @_;
    $self->do_actions;
}

sub build_db {
    my $self = shift;
    
    my $schema_class = $self->_schema_class;
    eval "use $schema_class";
    die $@ if $@;
    my $sg = $schema_class->new;

    $sg->load_classes($self->metadata->source_dir);
    my (@tables, @behaviors);
    my %seen;
    for my $class ($sg->classes) {
        next if $seen{$class->key}++;
        push @tables    => $sg->table_for_class($class);
        push @behaviors => $sg->behaviors_for_class($class);
    }
    $self->_do(@tables, @behaviors);
    return $self;
}
 
##############################################################################

=head3 do_actions

  $build->do_actions;

Some must be performed before the store can be built.  This method pulls the
actions designated by the rules and runs all of them.

=cut

sub do_actions {
    my ($self) = @_;
    return $self unless my $actions = $self->metadata->notes('actions');
    foreach my $action (@$actions) {
        my ($method, @args) = @$action;
        $self->$method(@args);
    }
    return $self;
}

sub switch_to_db {
    my ($self, $db_name) = @_;
    $self->metadata->db_name($db_name);
    $self->_dbh(undef); # clear wherever we were
    $self->_dbh;        # and reset it
    return $self;
} 

##############################################################################

=head2 Private Methods 

=cut

=head3 _do

  $kbs->_do(@sql);

This method will attempt to C<$dbh-E<gt>do($sql)> until no more SQL can be
done.  This effectively brute forces the database ordering problem (e.g., when
you're trying to create a foreign key constraint on a column in a table you
haven't created yet.)

=cut

sub _do {
    my $self    = shift;
    my %actions = map { $_ => 1 } grep { $_ && /\w/ } @_;
    my $count   = keys %actions;
    my $dbh     = $self->_dbh;

    my (@failures, $schema_created);

    while ( ! $schema_created ) {
        foreach my $action (keys %actions) {
            eval {
                local $SIG{__WARN__} = sub {};
                $dbh->do($action)
            };
            if ($@) {
                push @failures => [$action => $@];
            } else {
                delete $actions{$action};
            }
        }
        if ( ! @failures ) {
            $schema_created = 1;
        } elsif ( $count == keys %actions ) {
            foreach my $failure (@failures) {
                warn "Action: \n$failure->[0]\nFailure reason: $@\n----------\n";
            }
            die "Database schema creation failed.";
        } else {
            @failures = ();
            $count    = keys %actions;
        }
    }
    return $self;
}

##############################################################################

=head3 _dbh

  $kbs->_dbh;

Returns the database handle to connect to the data store.

=cut

sub _dbh {
    my $self = shift;
    my $dsn  = $self->metadata->_dsn;
    my $user = $self->metadata->db_user;
    my $pass = $self->metadata->db_pass;
    my $dbh = DBI->connect( $dsn, $user, $pass, {RaiseError => 1}) 
      or require Carp && Carp::croak $DBI::errstr;
    $self->{dbh} = $dbh;
    return $dbh;
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
