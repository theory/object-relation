package Kinetic::Build;

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
use base 'Kinetic::Build::Base';

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::Build - Builds and Installs The Kinetic Platform

=head1 Synopsis

In F<Build.PL>:

  use strict;
  use Kinetic::Build;

  my $build = Kinetic::Build->new(
      module_name => 'MyApp',
  );

  $build->create_build_script;

=head1 Description

This module subclasses L<Module::Build|Module::Build> to provide added
functionality for installing Kinetic. The added functionality includes
configuration file management, configuation file setup for tests, data store
schema generation, and database building.

This module does I<not> install Kinetic applications. That functionality is
handled by L<Kinetic::AppBuild|Kinetic::AppBuild>.

Note that this class also includes the interface defined by
L<Kinetic::Build::Trait|Kinetic::Build::Trait>.

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 test_data_dir

  my $dir = $build->test_data_dir;

Returns the name of a directory that can be used by tests for storing
arbitrary files. The whole directory will be deleted by the C<cleanup>
action. This is a read-only class method.

=cut

use constant test_data_dir => File::Spec->catdir( 't', 'data' );

##############################################################################

=head2 Instance Methods

=head3 engine

  my $engine = $build->engine;
  $build->engine($engine);

The type of engine to be used for the application.  Possible values are
"apache" and "catalyst".  Defaults to "apache".

The "catalyst" engine is merely a test engine for easy development.

=cut

__PACKAGE__->add_property(
    name        => 'engine',
    label       => 'Kinetic engine',
    default     => 'apache',
    message     => 'Which engine should I use?',
    config_keys => [qw(engine class)],
    callback    => sub { s/.*:://; $_ = lc; return 1; },
    setup       => {
        apache   => 'Kinetic::Build::Setup::Engine::Apache2',
        catalyst => 'Kinetic::Build::Setup::Engine::Catalyst',
    },
);

##############################################################################

=head3 cache

  my $cache = $build->cache;
  $build->cache($engine);

The type of cache to be used for the application.  Possible values are
"memcached" and "file".  Defaults to "memcached".

The "file" cache is merely a test cache for easy development.

=cut

__PACKAGE__->add_property(
    name        => 'cache',
    label       => 'Kinetic cache',
    default     => 'file',
    message     => 'Which session cache should I use?',
    config_keys => [qw(cache class)],
    callback    => sub { s/.*:://; $_ = lc; return 1; },
    setup       => {
        memcached => 'Kinetic::Build::Setup::Cache::Memcached',
        file      => 'Kinetic::Build::Setup::Cache::File',
    },
);

##############################################################################

=head3 auth

  my $auth = $build->auth;
  $build->auth($engine);

The type of authorization to be used for the application.  Currently only
"kinetic" is supported.

=cut

__PACKAGE__->add_property(
    name    => 'auth',
    label   => 'Kinetic authorization',
    default => 'kinetic',
    message => 'Which type of authorization should I use?',
    config_keys => [qw(auth class)],
    callback    => sub { s/.*:://; $_ = lc; return 1; },
    setup => {
        kinetic => 'Kinetic::Build::Setup::Auth::Kinetic',
    },
);

##############################################################################

=head3 admin_username

  my $admin_username = $build->admin_username;
  $build->admin_username($admin_username);

The username to use for the default administrative user created for all TKP
installations. Defaults to "admin".

=cut

__PACKAGE__->add_property( admin_username => 'admin' );

##############################################################################

=head3 admin_password

  my $admin_password = $build->admin_password;
  $build->admin_password($admin_password);

The password to use for the default administrative user created for all TKP
installations. Defaults to "change me now!".

=cut

__PACKAGE__->add_property(
    name    => 'admin_password',
    label   => 'Administrative User password',
    default => 'change me now!',
    message => 'What password should be used for the default account?',
);

##############################################################################

=head2 Actions

=head3 config

=begin comment

=head3 ACTION_config

=end comment

This action modifies the contents of Kinetic::Util::Config to default to the
location of F<kinetic.conf> specified by the build process. You won't normally
call this action directly, as the C<build> and C<test> actions depend on it.

=cut

sub ACTION_config {
    my $self = shift;
    $self->depends_on('code');

    # Find Kinetic::Util::Config and hard-code the path to the
    # configuration file.
    my @path = qw(lib Kinetic Util Config.pm);
    my $old  = File::Spec->catfile( $self->blib, @path );

    # Just return if there is no configuration file.
    # XXX Can this burn us?
    return $self unless -e $old;

    # Find Kinetic::Util::Config in lib and just return if it
    # hasn't changed.
    my $lib = File::Spec->catfile(@path);
    return $self if $self->up_to_date( $lib, $old );

    # Figure out where we're going to install this beast.
    $path[-1] .= '.new';
    my $new     = File::Spec->catfile( $self->blib, @path );
    my $base    = $self->install_base;
    my $default = '/usr/local/kinetic/conf/kinetic.conf';
    my $config  = File::Spec->catfile( $base, qw(conf kinetic.conf) );

    # Just return if the default is legit.
    return if $base eq $default;

    # Update the file.
    open my $orig, '<', $old or die "Cannot open '$old': $!\n";
    open my $temp, '>', $new or die "Cannot open '$new': $!\n";
    while (<$orig>) {
        s/$default/$config/g;
        print $temp $_;
    }
    close $orig;
    close $temp;

    # Make the switch.
    rename $new, $old or die "Cannot rename '$old' to '$new': $!\n";
    return $self;
}

##############################################################################

=head3 build

=begin comment

=head3 ACTION_build

=end comment

Overrides Module::Build's C<build> action to add the C<config> action as a
dependency.

=cut

sub ACTION_build {
    my $self = shift;
    $self->depends_on('code');
    $self->depends_on('config');
    $self->SUPER::ACTION_build(@_);
    return $self;
}

##############################################################################

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides Module::Build's C<test> action to set up the F<t/data> directory for
use by tests. It will be deleted by the C<cleanup> action.

=cut

sub ACTION_test {
    my $self = shift;
    $self->depends_on('config');

    # Set up t/data for tests to fill with junk. We'll clean it up.
    my $data = $self->test_data_dir;
    File::Path::mkpath $data;
    $self->add_to_cleanup($data);

    return $self->SUPER::ACTION_test(@_);
}

##############################################################################

=head2 Instance Methods

=head3 init_app

  $build->init_app;

This method is overrides the parent method to initialize Kinetic objects in
the newly installed Kinetic data store. Currently, this means simply creating
an admin user, but other objects will no doubt be created in the future. The
parent class method is also called, so that version information will be
properly stored.

=cut

sub init_app {
    my $self = shift->SUPER::init_app(@_);

    require Kinetic::Party::User;
    Kinetic::Party::User->new(
        last_name  => 'User',
        first_name => 'Admin',
        username   => $self->admin_username,
        password   => $self->admin_password,
    )->save;
    return $self;
}

1;
__END__

##############################################################################

=head1 See Also

=over

=item L<Kinetic::AppBuild|Kinetic::AppBuild>

The Kinetic application builder and installer.

=item L<Kinetic::Build::Trait|Kinetic::Build::Trait>

Defines methods common to Kinetic::Build and Kinetic::AppBuild.

=back

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
