package Kinetic::Build::Test;

# $Id$

use strict;
use warnings;
use File::Spec;

=head1 Name

Kinetic::Test - Kinetic test script helper

=head1 Synopsis

  #!/usr/bin/perl -w

  use strict;
  use warnings;
  use Kinetic::Build::Test;
  use Test::More tests => 4;

Or modify the configuration for the duration of the running of the test
script:

  # Switch to SQLite.
  use Kinetic::Build::Test store => { class => 'Kinetic::Store::DBI::SQLite' };

=head1 Description

This class sets up the environment for testing. It should thus be used by all
Kinetic test scripts.

Seting up the environment consist of setting up the C<$KINETIC_CONF>
environment variable to point to the F<kinetic.conf> in either the F<t/conf>
directory or the F<conf> directory. If arguments are passed in when the module
is loaded, then the configuration file will be backed up, then modified with
the new values. For example, to temporarily set the value of the C<class>
directive in the C<store> configuration property to use SQLite, do this:

  use Kinetic::Build::Test store => { class => 'Kinetic::Store::DBI::SQLite' };

When the script finishes running, the modified F<kinetic.conf> file will be
deleted and the original file restored.

Kinetic::Build::Test also sets up US English as the localization during tests.

=cut

use Kinetic::Util::Context;
use Kinetic::Util::Language::en_us;
Kinetic::Util::Context->language(Kinetic::Util::Language->get_handle('en_us'));

my ($conf_file, $backup);

BEGIN {
    $conf_file = File::Spec->catfile(qw(t conf kinetic.conf));
    $ENV{KINETIC_CONF} = -e $conf_file
      ? $conf_file
      : File::Spec->catfile(qw(conf kinetic.conf));
    $conf_file = $ENV{KINETIC_CONF};
}

sub import {
    shift;
    return unless @_;
    open CONF, '<', $conf_file or die "cannot open $conf_file: $!";
    local $/;
    my %conf = eval <CONF>;
    close CONF;

    # Merge in new values.
    my %new = @_;
    while (my ($k, $v) = each %new) {
        $conf{$k}->{$_} = $v->{$_} for keys %$v;
    }

    $backup = $conf_file . '.bak';
    require File::Copy;
    File::Copy::copy($conf_file, $backup);
    open CONF, '>', $conf_file or die "cannot open $conf_file: $!";
    while (my ($k, $v) = each %conf) {
        print CONF "$k => {\n";
        while (my ($dir, $val) = each %$v) {
            print CONF "    $dir => ", defined $val ? "'$val',\n" : "undef,\n";
        }
        print CONF "},\n\n";
    }
    close CONF;
}

END {
    return unless $backup;
    unlink $conf_file;
    File::Copy::move($backup, $conf_file);
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
