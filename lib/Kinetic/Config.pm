package Kinetic::Config;

# $Id$

use strict;
use File::Spec;
use Exporter::Tidy ();

=head1 Name

Kinetic::Config - Kinetic application configuration

=head1 Synopsis

In kinetic.conf:

  apache => {
      bin     => '/usr/local/apache/bin/httpd',
      conf    => '/usr/local/kinetic/conf/httpd.conf',
      port    => '80',
      user    => 'nobody',
      group   => 'nobody'
  },

  store => {
      class   => 'Kinetic::Store::DBI::Pg',
      db_name => 'kinetic',
      db_pass => 'kinetic',
      db_user => 'kinetic',
      db_host => undef,
      db_port => undef,
  }

In a Kinetic class:

  use Kinetic::Config qw(:store);
  eval "require " . STORE_CLASS;

In another Kinetic class:

  use Kinetic::Config qw(:apache);
  system(APACHE_BIN);

To get all constants:

  use Kinetic::Config qw(:all);

=head1 Description

This module reads in a configuration file and sets up constants that can be
used in Kinetic modules. The configuration file consists of Perl code that,
when C<eval>ed by Kinetic::Config, generates a hash of hash references. Each
hash reference is turned into a series of constants, one for each key/value
pair. They keys in the main hash are used as prefixes to the name of each
constant generated from the values stored in the associated hash reference.
They are also used for labels for easy importation of a group of related
constants.

While no constants are exported by Kinetic::Config by default, the
special C<all> tag can be used to export I<all> of the constants created from
the configuration file:

  use Kinetic::Config qw(:all);

=cut

BEGIN {
    # Load the configuration file. It's hard-coded; if it ever changes,
    # it should also be changed in inst/lib/Kinetic/Build.pm.
    my $conf_file = delete $ENV{KINETIC_CONF}
      || '/usr/local/kinetic/conf/kinetic.conf';
    die "No such configuration file '$conf_file'" unless -f $conf_file;
    open CONF, $conf_file or die "Cannot open $conf_file: $!";
    local $/;
    my %conf = eval <CONF>;
    close CONF;
    my %export;
    while (my ($label, $set) = each %conf) {
        my @export;
        my $prefix = uc $label;
        while (my ($const, $val) = each %$set) {
            $const = "$prefix\_" . uc $const;
            eval "use constant $const => \$val";
            push @export, $const;
        }
        $export{$label} = \@export;
    }
    Exporter::Tidy->import(%export);
}

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
