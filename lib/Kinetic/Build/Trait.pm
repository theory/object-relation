package Kinetic::Build::Trait;

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

use Class::Trait 'base';

use strict;
use warnings;
use 5.008003;

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::Build::Trait - Methods Shared by Kinetic::Build and Kinetic::AppBuild

=head1 Synopsis

  use Class::Trait qw(Kinetic::Build::Trait);

=head1 Description

This module defines a trait that can be added to classes that build Kinetic
and Kinetic applications. Defining these methods in trait makes it very simple
to add them to whatever class needs them. In the Kinetic distribution, these
include L<Kinetic::Build|Kinetic::Build> and
L<Kinetic::AppBuild|Kinetic::AppBuild>.

=cut

##############################################################################

=head1 Interface

=head2 Instance Methods

=head3 find_script_files

Called by C<process_script_files()>, this method returns a hash reference of
all of the files in the F<bin> directory for processing and copying.

=cut

sub find_script_files { shift->find_files_in_dir('bin') }

##############################################################################

=head3 find_www_files

Called by C<process_www_files()>, this method returns a hash reference of all
of the files in the F<www> directory for processing and copying.

=cut

sub find_www_files { shift->find_files_in_dir('www') }

##############################################################################

=head3 process_www_files

This method is called during the C<build> action to copy the Web interfae
files to F<blib/www>.

=cut

sub process_www_files {
    my $self  = shift;
    my $files = $self->find_www_files;
    while (my ($file, $dest) = each %$files) {
        $self->copy_if_modified(
            from => $file,
            to => File::Spec->catfile($self->blib, $dest)
        );
    }
}

##############################################################################

=head3 find_files_in_dir

  $build->find_files_in_dir($dir);

Returns a hash reference of of all of the files in a directory, excluding any
with F<.svn> in their paths. Code borrowed from Module::Build's
C<_find_file_by_type()> method.

=cut

sub find_files_in_dir {
    my ( $self, $dir ) = @_;
    return {
        map { $_, $_ }
          map $self->localize_file_path($_),
        @{ $self->rscan_dir( $dir, sub { -f && !/[.]svn/ } ) }
    };
}

##############################################################################

=head3 fix_shebang_line

  $builder->fix_shegang_line(@files);

This method overrides that in the parent class in order to also process all of
the script files and change any lines containing

  use lib 'lib'

To instead point to the library directory in which the module files will be
installed, e.g., F</usr/local/kinetic/lib>. It then calls the parent method in
order to fix the shebang lines, too.

=cut

sub fix_shebang_line {
    my $self = shift;
    my $lib  = File::Spec->catdir( $self->install_base, 'lib' );

    for my $file (@_) {
        $self->log_verbose(
            qq{Changing "use lib 'lib'" in $file to "use lib '$lib'"} );

        open my $fixin,  '<', $file       or die "Can't process '$file': $!";
        open my $fixout, '>', "$file.new" or die "Can't open '$file.new': $!";
        local $/ = "\n";

        while (<$fixin>) {
            s/use\s+lib\s+'lib'/use lib '$lib'/xms;
            print $fixout $_;
        }

        close $fixin;
        close $fixout;

        rename $file, "$file.bak"
          or die "Can't rename $file to $file.bak: $!";

        rename "$file.new", $file
          or die "Can't rename $file.new to $file: $!";

        unlink "$file.bak"
          or
          $self->log_warn("Couldn't clean up $file.bak, leaving it there\n");
    }

    return $self->SUPER::fix_shebang_line(@_);
}

1;
__END__

##############################################################################

=head1 See Also

=over

=item L<Kinetic::Build|Kinetic::Build>

Builds and installs the Kinetic Platform.

=item L<Kinetic::AppBuild|Kinetic::AppBuild>

Builds and installs Kinetidc applications onto an existing installation of the
Kinetic Platform.

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
