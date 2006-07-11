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
our $VERSION = version->new('0.0.2');

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
functionality for installing Kinetic. The added functionality includes data
store schema generation, and database building.

Note that this class also includes the interface defined by
L<Kinetic::Build::Trait|Kinetic::Build::Trait>.

=cut

##############################################################################

=head1 Class Interface

=head2 Instance Methods

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
    callback    => sub { s/.*:://; $_ = lc; return 1; },
    setup       => {
        memcached => 'Kinetic::Build::Setup::Cache::Memcached',
        file      => 'Kinetic::Build::Setup::Cache::File',
    },
);

##############################################################################

=head2 Actions

=head3 test

=begin comment

=head3 ACTION_test

=end comment

Overrides Module::Build's C<test> action to set up the F<t/data> directory for
use by tests. It will be deleted by the C<cleanup> action.

=cut

sub ACTION_test {
    my $self = shift;

    # Set up t/data for tests to fill with junk. We'll clean it up.
    my $data = $self->test_data_dir;
    File::Path::mkpath $data;
    $self->add_to_cleanup($data);

    return $self->SUPER::ACTION_test(@_);
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
