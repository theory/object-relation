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
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Store->info_class

This abstract class method returns the name of the C<App::Info> class for the
data store. Must be overridden in subclasses.

=cut

sub info_class { die "info_class() must be overridden in the subclass" }

=head3 schema_class

  my $schmea_class = Kinetic::Build::Store->schema_class

Returns the name of the Kinetic::Build::Schema subclass that can be used
to generate the schema code to build the data store. By default, this method
returns the same name as the name of the Kinetic::Build::Store subclass,
but with "Store" replaced with "Schema".

=cut

sub schema_class {
    (my $class = ref $_[0] ? ref shift : shift)
      =~ s/Kinetic::Build::Store/Kinetic::Build::Schema/;
    return $class;
}

##############################################################################

=head3 min_version

  my $version = Kinetic::Build::Store->min_version

This abstract class method returns the minimum required version number of the
data store application. Must be overridden in subclasses.

=cut

sub min_version { die "min_version() must be overridden in the subclass" }

##############################################################################

=head3 max_version

  my $version = Kinetic::Build::Store->max_version

This abstract class method returns the maximum required version number of the
data store application. Returns zero by default, meaning that there is no
maximum version number.

=cut

sub max_version { 0 }

##############################################################################
# Constructors.
##############################################################################

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
    my $builder;
    eval { $builder = Kinetic::Build->resume };
    unless ($builder) {
        die "Cannot resume build: $@";
    }

    my $info_object = $class->info_class->new($builder->_app_info_params);
    bless {
        builder => $builder,
        info     => $info_object,
    } => $class;
}

##############################################################################

=head3 builder

  my $builder = $kbs->builder;

Returns the C<Kinetic::Build> object used to determine build properties.

=cut

sub builder { $_[0]->{builder} }

##############################################################################

=head3 info

  my $info = $kbs->info;

Returns the C<App::Info> object for the data store.

=cut

sub info { $_[0]->{info} }

##############################################################################

=head3 rules

  my @rules = $kbs->rules;

This is an abstract protected method that must be overridden in a subclass. By
default it must return arguments that the C<FSA::Rules> constructor requirea.

=cut

sub rules { die "rules() must be overridden in the subclass" }

##############################################################################

=head3 validate

  $kbs->validate;

This method will validate the store rules. Returns true if the store can be
used. Otherwise it will C<croak()>.

Internally this method calls C<rules()>. See that method for details. If you
do not wish to use C<FSA::Rules> for rules validation, you will need to
override the C<validate()> method.

=cut

sub validate {
    my $self = shift;
    my $machine = FSA::Rules->new($self->rules);
    $machine->start;
    $self->{machine} = $machine; # internal only.  Used for debugging
    $machine->switch until $machine->at('Done');
    return $self;
}

##############################################################################

=head3 config

  my @config = $kbs->config;

This abstract method is the interface for a data store to set up its
configuration file directives. It functions just like the C<*_config> methods
in C<Kinetic::Build>, but is specific to a data store.

=cut

sub config { die "config() must be overridden in the subclass" }

##############################################################################

=head3 test_config

  my @test_config = $kbs->test_config;

This abstract method is the interface for a data store to set up its testing
configuration file directives. It functions just like the C<*_config> methods
in C<Kinetic::Build>, but is specific to a data store and to the running
of tests. It should therefore set up for a data store that will not be used
in production.

=cut

sub test_config { die "test_config() must be overridden in the subclass" }

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
    return $self unless my $actions = $self->builder->notes('actions');
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
