package Kinetic::TestSetup;

# $Id$

use strict;
use warnings;
use File::Spec;

=head1 Name

Kinetic::TestSetup - Kinetic test script helper

=head1 Synopsis

  #!perl -w

  use strict;
  use Test::More;
  use lib 't/lib';
  use Kinetic::TestSetup;

Or modify the configuration for the duration of the running of the test
script:

  use lib File::Spec->catdir(qw(t lib));
  # Switch to SQLite.
  use Kinetic::TestSetup store => { class => 'Kinetic::Store::DBI::SQLite' };

=head1 Description

This class sets up the environment for testing. It should thus be used by all
test scripts.

Seting up the environment consist of setting up the C<$KINETIC_CONF>
environment variable to point to the F<kinetic.conf> in either the F<t/conf>
directory or the F<conf> directory. If arguments are passed in when the module
is loaded, then the configuration file will be backed up, then modified with
the new values. For example, to temporarily set the value of the C<class>
directive in the C<store> configuration property to use SQLite, do this:

  use Kinetic::TestSetup store => { class => 'Kinetic::Store::DBI::SQLite' };

When the script finishes running, the modified F<kinetic.conf> file will be
deleted and the original file restored.

=cut

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
            $val = 'undef' unless defined $val;
            print CONF "    $dir => '$val',\n";
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
