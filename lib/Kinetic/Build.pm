package Kinetic::Build;

# $Id$

use strict;
use 5.008003;
use base 'Module::Build';
use File::Spec;
use File::Path ();

=head1 Name

Kinetic::Build - Kinetic application installer

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
functionality for installing Kinetic and Kinetic applications. The added
functionality includes configuration file management, configuation file setup
for tests, data store schema generation, and database building.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $cm = Kinetic::Build->new(%init);

Overrides Module::Build's constructor to add Kinetic-specific build elements.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    # Add elements we need here.
    $self->add_build_element('conf');
    return $self;
}

##############################################################################

=head1 Instance Interface

=head2 Actions

=head3 config

=begin comment

=head3 ACTION_config

=end comment

This action modifies the contents of Kinetic::Util::Config to default to the
location of F<kinetic.conf> specified by the build process. You won't normally
call this action directly, as the C<build> and C<test> actions depend on it.

=cut

# This action modifies the location of the config file in
# Kinetic::Util::Config.
sub ACTION_config {
    my $self = shift;
    $self->depends_on('code');

    # Find Kinetic::Util::Config and hard-code the path to the
    # configuration file.
    my $old = File::Spec->catfile($self->blib,
                                  qw(lib Kinetic Util Config.pm));
    my $new = File::Spec->catfile($self->blib,
                                  qw(lib Kinetic Util Config.pm.new));
    # Figure out where we're going to install this beast.
    my $base = $self->install_base
      || File::Spec->catdir($self->config->{installprefix}, 'kinetic');
    my $default = '/usr/local/kinetic/conf/kinetic.conf';
    my $config = File::Spec->catfile($base, qw(conf kinetic.conf));

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
}

##############################################################################

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides Module::Build's C<test> action to add the C<config> action as a
dependency.

=cut

# The test action depends on the config action.
sub ACTION_test {
    my $self = shift;
    $self->depends_on('config');
    $self->SUPER::ACTION_test(@_);
}

##############################################################################

=head3 build

=begin comment

=head3 ACTION_build

=end comment

Overrides Module::Build's C<test> action to add the C<config> action as a
dependency.

=cut

# The build action depends on the config action.
sub ACTION_build {
    my $self = shift;
    $self->depends_on('config');
    $self->SUPER::ACTION_build(@_);
}

##############################################################################

=head2 Methods

=head3 process_conf_files

This method is called during the C<build> action to copy the configuration
files to F<blib/conf> and F<t/conf>. Their contents are also modified to
reflet the options selected during C<perl Build.PL>.

=cut

# Copy the configuration files to blib and t.
sub process_conf_files {
    my $self = shift;
    $self->add_to_cleanup('t/conf');
    my $files = $self->find_conf_files;
    # XXX Do any conversions to kinetic.conf and friends here.
    return unless %$files;
    return $self->_copy_to($files, $self->blib, 't');
}

##############################################################################

=head3 find_conf_files

Called by C<process_conf_files()>, this method returns a hash reference of
configuration file names for processing and copying.

=cut

sub find_conf_files  { shift->_find_files_in_dir('conf') }

##############################################################################

=begin private

=head1 Private Methods

=head2 Instance Methods

=head3 _copy_to

  $build->_copy_to($files, @dirs);

This method copies the files in the C<$files> hash reference to each of the
directories specified in C<@dirs>.

=cut

# Use this method to copy a hash of files to a list of directories.
sub _copy_to {
    my $self = shift;
    my $files = shift;
    return unless %$files;
    while (my ($file, $dest) = each %$files) {
        for my $dir (@_) {
            $self->copy_if_modified(from => $file,
                                    to => File::Spec->catfile($dir, $dest) );
        }
    }
}

##############################################################################

=head3 _find_files_in_dir

  $build->_find_files_in_dir($dir);

Returns a hash reference of of all of the files in a directory, excluding any
with F<.svn> in their paths. Code borrowed from Module::Buld's
C<_find_file_by_type()> method.

=cut

sub _find_files_in_dir {
    my ($self, $dir) = @_;
    return { map {$_, $_}
             map $self->localize_file_path($_),
             @{ $self->rscan_dir($dir, sub { -f && !/\.svn/ }) } };
}

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
