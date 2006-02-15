package Kinetic::Util::Config;

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

use File::Spec;
use Config::Std;
use Exporter::Tidy ();

=head1 Name

Kinetic::Util::Config - Kinetic application configuration

=head1 Synopsis

In kinetic.conf:

  [engine]
  httpd : /usr/local/apache/bin/httpd
  conf  : /usr/local/kinetic/conf/httpd.conf
  port  : 80
  user  : nobody
  group : nobody

  [store]
  class : Kinetic::Store::DB::Pg
  db_name : kinetic
  db_user : kinetic
  db_pass : kinetic
  dsn     : dbi:Pg:dbname=kinetic

In a Kinetic class:

  use Kinetic::Util::Config qw(:store);
  eval "require " . STORE_CLASS;

In another Kinetic class:

  use Kinetic::Util::Config qw(:engine);
  system(ENGINE_HTTPD);

To get all constants:

  use Kinetic::Util::Config qw(:all);

=head1 Description

This module reads in a configuration file and sets up constants that can be
used in Kinetic modules. The configuration file format is defined by the
modified INI format supported by L<Config::Std|Config::Std>. Each
configuration values is turned into a constant; multi-part configuration
values are turned into list constants, I<not> array reference constants. The
section labels are used as prefixes to the names of each constant generated
for each of their values. They are also used for labels for easy importation
of a group of related constants.

While no constants are exported by Kinetic::Util::Config by default, the
special C<all> tag can be used to export I<all> of the constants created from
the configuration file:

  use Kinetic::Util::Config qw(:all);

=cut

BEGIN {
    # Load the configuration file. It's hard-coded; if it ever changes,
    # it should also be changed in inst/lib/Kinetic/Build.pm.
    my $conf_file = $ENV{KINETIC_CONF}
      || '/usr/local/kinetic/conf/kinetic.conf';
    die "No such configuration file '$conf_file'" unless -f $conf_file;
    read_config($conf_file => my %conf);
    my %export;
    while (my ($label, $set) = each %conf) {
        my @export;
        my $prefix = uc $label;
        while (my ($const, $val) = each %$set) {
            $const = "$prefix\_" . uc $const;
            if (ref $val eq 'ARRAY') {
                eval "use constant $const => \@\$val";
            } else {
                eval "use constant $const => \$val";
            }
            push @export, $const;
        }
        $export{lc $label} = \@export;
    }
    Exporter::Tidy->import(%export);
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
