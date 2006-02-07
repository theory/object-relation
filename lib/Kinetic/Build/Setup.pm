package Kinetic::Build::Setup;

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

Kinetic::Build::Setup - Kinetic external dependency detection and setup

=head1 Synopsis

  use Kinetic::Build::Setup;
  my $kbs = Kinetic::Build::Setup->new;
  $kbs->setup;

=head1 Description

This module is the base class for classes that need to detect and configure
external dependencies, such as data stores (databases), engines (Web servers),
caching, etc. It assumes that an L<App::Info|App::Info> subclass will be used
for detecting external dependencies, and expects L<FSA::Rules|FSA::Rules> to
be used to validate said external dependencies and to collect information for
configuring them.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Setup->info_class

This abstract class method returns the name of the L<App::Info|App::Info>
class for the dependency to be set up. Returns C<undef> by default;
override in a subclass if an C<App::Info> class is to be used to validate
an external dependency.

=cut

sub info_class { return }

##############################################################################

=head3 min_version

  my $version = Kinetic::Build::Setup->min_version

This abstract class method returns the minimum required version number of the
external dependency to be set up. Must be overridden in subclasses.

=cut

sub min_version { die "min_version() must be overridden in the subclass" }

##############################################################################

=head3 max_version

  my $version = Kinetic::Build::Setup->max_version

This abstract class method returns the maximum required version number of the
external dependency to be setup. Returns zero by default, meaning that there
is no maximum version number.

=cut

sub max_version { 0 }

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Setup->rules;

This is an abstract method that must be overridden in a subclass. By default
it must return arguments that the C<FSA::Rules> constructor requires. These
rules must also set the FSA::Rules C<done> attribute to indicate when they
have finished running, otherwise a call to C<validate()> might never exit.
Or else throw an exception, of course, if something goes wrong.

=cut

sub rules { die "rules() must be overridden in the subclass" }

##############################################################################
# Constructors.
##############################################################################

=head2 Constructors

=head3 new

  my $kbs = Kinetic::Build::Setup->new;
  my $kbs = Kinetic::Build::Setup->new($builder);

Creates and returns a new Setup object. Pass in the Kinetic::Build object that
is managing the installation. If no Kinetic::Build object is passed, one will
be instantiated by a call to C<< Kinetic::Build->resume >>.

=cut

sub new {
    my $class = shift;
    my $builder = shift || eval { Kinetic::Build->resume }
      or die "Cannot resume build: $@";

    my $self = bless { actions => [] } => $class;
    my $info;
    if (my $info_class = $class->info_class) {
        $info = $info_class->new($builder->_app_info_params);
    }

    $private{$self} = {
        builder => $builder,
        info    => $info,
    };
    return $self;
}

##############################################################################
# Instance Metnhods
##############################################################################

=head1 Instance Methods

=head3 builder

  my $builder = $kbs->builder;

Returns the C<Kinetic::Build> object used to determine build properties.

=cut

sub builder { $private{shift()}->{builder} ||= Kinetic::Build->resume }

##############################################################################

=head3 info

  my $info = $kbs->info;

Returns the C<App::Info> object for the data setup.

=cut

sub info { $private{shift()}->{info} }

##############################################################################

=head3 validate

  $kbs->validate;

This method will validate the setup rules. Returns true if the dependency can
be used. Otherwise it will C<croak()>.

Internally this method calls C<rules()>. See that method for details. If you
do not wish to use L<FSA::Rules|FSA::Rules> for rules validation, you will
need to override the C<validate()> method.

=cut

sub validate {
    my $self = shift;
    my $machine = FSA::Rules->new($self->rules);
    $machine->run;
    return $self;
}

##############################################################################

=head3 is_required_version

  print "Is required version" if $kbs->is_required_version;

This is a common helper method that uses the C<App::Info> object returned from
C<info()> and the C<version> module to determine if the external dependency is
of the minumum required version and no more than the maximum required version,
if C<max_version()> returns a true value. Returns a boolean value.

If you are not using an C<App::Info> class to validate a dependency, you must
either override this method in your subclass.

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

This abstract method is the interface for a setup class to set up its
configuration file directives. It functions just like the C<*_config> methods
in C<Kinetic::Build>, but is specific to a data store. It must be overridden
in a subclass.

=cut

sub config { die "config() must be overridden in the subclass" }

##############################################################################

=head3 test_config

  my @test_config = $kbs->test_config;

This abstract method is the interface for a setup class to set up its testing
configuration file directives. It functions just like the C<*_config> methods
in C<Kinetic::Build>, but is specific to a data store and to the running of
tests. It should therefore set up for a data store that will not be used in
production. It must be overridden in a subclass.

=cut

sub test_config { die "test_config() must be overridden in the subclass" }

##############################################################################

=head3 setup

  $kbs->setup;

This method will build call each of the methods returned from the C<actions()>
method to set up an external dependency for TKP. If the dependency is to be
set up by other means, this method must be overridden.

=cut

sub setup {
    my $self = shift;
    $self->$_ for $self->actions;
    return $self;
}

##############################################################################

=head3 test_setup

  $kbs->test_setup;

This method will temporarily set up the dependency for testing. This
implementation is merely an alias for the C<setup()> method. Subclasses may
override it to add test-specific functionality.

=cut

*test_setup = \&setup;

##############################################################################

=head3 test_cleanup

  $kbs->test_cleanup;

This method will cleanup a temporary setup created by the C<test_setup()>
meethod.

This implementation is a no-op, but can be overridden in subclasses to delete
drop a database or something similar.

=cut

sub test_cleanup { shift }

##############################################################################

=head3 resume

  $kbs->resume($builder);

Resumes the state of the Kinetic::Build::Setup object after it has been
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
C<add_actions()> method. Used internally by C<setup()> to set up a dependency.

=cut

sub actions {
    my $self = shift;
    return @{$self->{actions}};
}

##############################################################################

=head3 add_actions

  $kbs->add_actions(@actions);

Adds actions to the list of actions returned by C<actions()>. Used by the
rules specified by C<rules()> to set up actions later called by C<setup()> to
set up a dependency.

=cut

sub add_actions {
    my $self = shift;
    push @{$self->{actions}}, grep { !$self->{seen_actions}{$_}++ } @_;
    return $self;
}

##############################################################################

=head3 del_actions

  $kbs->del_actions(@actions);

Removes actions from the list of actions returned by C<actions()>. Used by the
rules specified by C<rules()> to prevent actions from being called by
C<setup()> to set up a dependency.

=cut

sub del_actions {
    my $self = shift;
    my %delete = map { $_ => delete $self->{seen_actions}{$_} } @_;
    $self->{actions} = [ grep { ! exists $delete{$_} } @{$self->{actions} } ];
    return $self;
}

sub DESTROY {
    my $self = shift;
    delete $private{$self};
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
