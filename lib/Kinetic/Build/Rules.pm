package Kinetic::Build::Rules;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use warnings;
use Carp;
use version;

use FSA::Rules;
use App::Info::RDBMS::SQLite;

=head1 Name

Kinetic::Build::Rules - Validate a data store.

=head1 Synopsis

 use Kinetic::Build::Rules::SQLite;
 my $rules = Kinetic::Build::Rules::SQLite->new($build_object);
 $rules->validate;

=head1 Description

Rules to determine if we have enough information to create a given store.  This
is a base class that must be overridden by a subclass for the store type being
implemented.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructor

=head3 new

  my $rules = Kinetic::Build::Rules::SQLite->new($build_object);

Returns a new rules object.  Takes the current Kinetic::Build object as its
argument.

=cut

sub new {
    my ($class, $build) = @_;
    $class->_validate($build);
    my $info_object = $class->info_class->new($build->_app_info_params);
    my $app_name    = $info_object->key_name;
    bless {
        build    => $build,
        info     => $info_object,
        app_name => $app_name,
    } => $class;
}

##############################################################################

=head2 Normal class methods

=head3 _validate

  $class->_validate($build_object);

When passed the build object, this method ensures that the class has been
called correctly.  If the class has been instantiated directly or the build
object is not a C<Kinetic::Build>, this method will C<croak()>.

=cut

sub _validate {
    my ($class, $build) = @_;
    if (__PACKAGE__ eq $class) {
        # What module? I think we need a more descriptive error message here.
        Carp::croak "This module must be subclassed.";
    }
    unless (UNIVERSAL::isa($build, 'Kinetic::Build')) {
        Carp::croak "Thhe argument to the constructor must be a Kinetic::Build object";
    }
    return $class;
}

##############################################################################

=head1 Instance Interface

=head2 Public Instance Methods

=cut

##############################################################################

=head3 build

  $rules->build;

Returns the build object;

=cut

sub build { $_[0]->{build} }

##############################################################################

=head3 app_name

  $rules->app_name;

Returns the app_name (key_name) as determined by the C<App::Info> method.

=cut

sub app_name { $_[0]->{app_name} }

##############################################################################

=head3 info

  $rules->info;

Returns the C<App::Info> object for the data store.

=cut

sub info { $_[0]->{info} }

##############################################################################

=head3 validate

  $rules->validate;

This method will validate the store rules.  Returns true if the store can be
used.  Otherwise it will C<croak()>.

Internally this method calls C<_state_machine()>. See that method for details.
If you do not wish to use C<FSA::Rules> for rules validation, you will need to
override this method.

=cut

sub validate {
    my $self = shift;
    # XXX Hrm. _state_machine() doesn't seem like quite the right name to
    # me. More like states() or state_defs(). Also, why does it return two
    # values?
    my ($state_machine, $done) = $self->_state_machine;
    my $machine = FSA::Rules->new(@$state_machine);
    $machine->start;
    $self->{machine} = $machine; # internal only.  Used for debugging
    $machine->switch until $machine->at('done');
    return $self;
}

=begin private

=head2 Private Methods

=cut

##############################################################################

=head3 _is_required_version

 $rules->_is_required_version;

This is a common helper function that uses C<version> to determine if the
data store is of the minumum required version.  Returns a boolean value.

=cut

sub _is_required_version {
    my $self = shift;
    my $req_version = version->new($self->build->_required_version);
    my $got_version = version->new($self->info->version);
    return $got_version >= $req_version;
}

##############################################################################

=head3 _dbh

 $rules->_dbh([$dbh]);

A convenient place to cache a database handle, if necessary.  Always returns
the database handle, even when setting it.

=cut

sub _dbh {
    my $self = shift;
    $self->{_dbh} = shift if @_;
    return $self->{_dbh};
}

##############################################################################

=head3 _is_installed

  $rules->_installed;

This is a common helper function that uses C<App::Info> to determine if the
data store is installed.  Returns a boolean value.

=cut

sub _is_installed {
    return $_[0]->info->installed;
}

##############################################################################

=head3 _has_executable

  $rules->_has_excutable;

Uses C<App::Info> to determine if the executable is installed.  Returns a
boolean value.

=cut

sub _has_executable {
    return $_[0]->info->executable;
}

##############################################################################

=head1 Abstract Methods

=head2 Abstract Class Methods

=cut

##############################################################################

=head3 info_class

 $rules->info_class

Returns the C<App::Info> class for the data store.

=cut

sub info_class { die "info_class() must be overridden in the subclass" }

##############################################################################

=head2 Abstract Instance Methods

Description

=cut

##############################################################################

=head3 _state_machine

  my ($state_machine, $end_func) = $rules->_state_machine;

This is a protected method that must be overridden in a subclass.  By default
it must return arguments that the C<FSA::Rules> engine requires.

=cut

sub _state_machine { die "_state_machine() must be overridden in the subclass" }

1;

__END__

##############################################################################

=end private

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