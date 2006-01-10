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

use version;
our $VERSION = version->new('0.0.1');

use Kinetic::Build;
use FSA::Rules;
my %private;

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

##############################################################################

=head3 schema_class

  my $schema_class = Kinetic::Build::Store->schema_class

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

=head3 store_class

  my $store_class = Kinetic::Build::Store->store_class

Returns the name of the Kinetic::Store subclass that manages the interface to
the data store for Kinetic applications. By default, this method returns the
same name as the name of the Kinetic::Build::Store subclass, but with "Build"
removed.

=cut

sub store_class {
    (my $class = ref $_[0] ? ref shift : shift) =~ s/Build:://;
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

=head3 rules

  my @rules = Kinetic::Build::Store->rules;

This is an abstract method that must be overridden in a subclass. By default
it must return arguments that the C<FSA::Rules> constructor requires.

=cut

sub rules { die "rules() must be overridden in the subclass" }

##############################################################################
# Constructors.
##############################################################################

=head2 Constructors

=head3 new

  my $kbs = Kinetic::Build::Store->new;
  my $kbs = Kinetic::Build::Store->new($builder);

Creates and returns a new Store builder object. Pass in the Kinetic::Build
object being used to validate the data store. If no Kinetic::Build object is
passed, one will be instantiated by a call to C<< Kinetic::Build->resume >>.
This is a factory constructor; it will return the subclass appropriate to the
currently selected store class as configured in F<kinetic.conf>.

=cut

sub new {
    my $class = shift;
    my $builder = shift || eval { Kinetic::Build->resume }
      or die "Cannot resume build: $@";

    my $self = bless {actions => []} => $class;
    $private{$self} = {
        builder => $builder,
        info    => $class->info_class->new($builder->_app_info_params)
    };
    return $self;
}

##############################################################################

=head3 builder

  my $builder = $kbs->builder;

Returns the C<Kinetic::Build> object used to determine build properties.

=cut

sub builder { $private{shift()}->{builder} ||= Kinetic::Build->resume }

##############################################################################

=head3 info

  my $info = $kbs->info;

Returns the C<App::Info> object for the data store.

=cut

sub info { $private{shift()}->{info} }

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
    $machine->switch until $machine->at('Done');
    return $self;
}

##############################################################################

=head3 is_required_version

  print "Is required version" if $rules->is_required_version;

This is a common helper method that uses the C<version> module to determine if
the data store is of the minumum required version and no more than the maximum
required version, if C<max_version()> returns a true value. Returns a boolean
value.

=cut

sub is_required_version {
    my $self = shift;
    my $min_version = version->new($self->min_version);
    my $got_version = version->new($self->info->version);
    my $max_version = $self->max_version
      or return $got_version >= $min_version;
    return $got_version >= $min_version
      && $got_version <= version->new($max_version);
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

This method will build a data store representing classes in the directory
specified by C<Kinetic::Build::source_dir()>.

=cut

sub build {
    my $self = shift;
    $self->$_ for $self->actions;
    return $self;
}

##############################################################################

=head3 test_build

  $kbs->test_build;

This method will build a temporary data store representing classes in the
directory specified by C<Kinetic::Build::source_dir()>. This temporary
data store can then be used for testing.

This implementation is merely an alias for the C<build()> method. Subclasses
may override it to add test-specific functionality.

=cut

*test_build = \&build;

##############################################################################

=head3 test_cleanup

  $kbs->test_cleanup;

This method will cleanup a temporary data store created by the C<test_build()>
meethod.

This implementation is a no-op, but can be overridden in subclasses to delete
drop a database or something similar.

=cut

sub test_cleanup { shift }

##############################################################################

=head3 resume

  $kbs->resume($builder);

Resumes the state of the Kinetic::Build::Store object after it has been
retreived from a serialized state. Pass a Kinetic::Build object to set the
C<builder> attribute.

=cut

sub resume {
    my $self = shift;
    $private{$self}->{builder} = shift if @_;
    return $self;
}

##############################################################################

=head3 actions

  my @ations = $kbs->actions;

Returns a list of the actions set up for the build by calls to the
C<add_actions()> method. Used internally by C<build()> to build a data store.

=cut

sub actions {
    my $self = shift;
    return @{$self->{actions}};
}

##############################################################################

=head3 add_actions

  $kbs->add_actions(@actions);

Adds actions to the list of actions returned by C<actions()>. Used internally
by the rules specified by C<rules()> to set up actions later called by
C<build()> to build a data store.

=cut

sub add_actions {
    my $self = shift;
    push @{$self->{actions}}, grep { !$self->{seen_actions}{$_}++ } @_;
    return $self;
}

##############################################################################

=head3 del_actions

  $kbs->del_actions(@actions);

Removes actions from the list of actions returned by C<actions()>. Used
internally by the rules specified by C<rules()> to prevent actions from being
called by C<build()> to build a data store.

=cut

sub del_actions {
    my $self = shift;
    my %delete = map { $_ => delete $self->{seen_actions}{$_} } @_;
    $self->{actions} = [ grep { ! exists $delete{$_} } @{$self->{actions} } ];
    return $self;
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
