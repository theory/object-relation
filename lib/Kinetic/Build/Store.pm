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

  $kbs->build;

This method will build a database representing classes in the directory
specified by C<Kinetic::Build::source_dir()>.

=cut

sub build {
    my ($self) = @_;
    $self->do_actions;
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
