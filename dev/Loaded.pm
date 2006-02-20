package Loaded;

use strict;
use warnings;
use Module::Info;

sub versions {
    my @modules;
    my $max = 0;
    foreach my $module (sort keys %INC) {
        $module =~ s/\.pm$//;
        $module =~ s/\//::/g;
        next if $module =~ /^::/;
        next if __PACKAGE__ eq $module;
        if (length $module > $max) {
            $max = length $module;
        }
        my $mod = Module::Info->new_from_loaded($module);
        push @modules => [ $module, $mod ? $mod->version : 'Could not load' ];
    }
    @modules = sort { $a->[0] cmp $b->[0] } @modules;
    $max += 2;
    no warnings 'uninitialized';
    return join "\n", map { sprintf "%-${max}s %s", @$_ } @modules;
}

1;

__END__

=head1 Name

Loaded

=head1 Synopsis

 use Loaded;
 print Loaded->versions;

=head1 Description

This is a very simple module which merely dumps out the names of all modules
found in C<%INC> (except for itself) and and their version numbers.  This
makes it easy to find out what you've actually loaded instead of what you
thought you've loaded this is particularly useful when you've got
experimental modules or multiple versions of a module.

Running this module on itself, for my system at the time these docs were
written:

  perl -MLoaded -e 'print Loaded->versions'
  AutoLoader           5.60
  Carp                 1.04
  Config               
  DynaLoader           1.05
  Exporter             5.58
  File::Spec           3.14
  File::Spec::Unix     1.5
  Module::Info         0.290
  strict               1.03
  vars                 1.01
  version              0.49
  version::vxs         0.49
  warnings             1.03
  warnings::register   1.00
