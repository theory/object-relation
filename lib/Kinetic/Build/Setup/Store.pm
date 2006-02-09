package Kinetic::Build::Setup::Store;

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

use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Build::Setup';
use Kinetic::Build;
use FSA::Rules;
my %private;

=head1 Name

Kinetic::Build::Setup::Store - Kinetic data store builder

=head1 Synopsis

  use Kinetic::Build::Setup::Store;
  my $kbs = Kinetic::Build::Setup::Store->new;
  $kbs->setup;

=head1 Description

This module builds a data store using the a schema output by
L<Kinetic::Build::Schema|Kinetic::Build::Schema> to the a file. The data store
will be built for the data store class specified by the C<STORE_CLASS>
F<kinetic.conf> directive.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 schema_class

  my $schema_class = Kinetic::Build::Setup::Store->schema_class

Returns the name of the Kinetic::Build::Schema subclass that can be used
to generate the schema code to build the data store. By default, this method
returns the same name as the name of the Kinetic::Build::Setup::Store subclass,
but with "Store" replaced with "Schema".

=cut

sub schema_class {
    (my $class = ref $_[0] ? ref shift : shift)
      =~ s/Kinetic::Build::Setup::Store/Kinetic::Build::Schema/;
    return $class;
}

##############################################################################

=head3 store_class

  my $store_class = Kinetic::Build::Setup::Store->store_class

Returns the name of the Kinetic::Store subclass that manages the interface to
the data store for Kinetic applications. By default, this method returns the
same name as the name of the Kinetic::Build::Setup::Store subclass, but with "Build"
removed.

=cut

sub store_class {
    (my $class = ref $_[0] ? ref shift : shift) =~ s/Build::Setup:://;
    return $class;
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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
