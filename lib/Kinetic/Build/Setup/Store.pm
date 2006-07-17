package Kinetic::Build::Setup::Store;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Build::Setup';
use Kinetic::Build;
use FSA::Rules;
my %private;

=head1 Name

Kinetic::Build::Setup::Store - Kinetic data store builder

=head1 Synopsis

  use Kinetic::Build::Setup::Store;
  my $kbs = Kinetic::Build::Setup::Store->new;
  $kbs->setup;

=head1 Description

This module builds a data store using the a schema output by
L<Kinetic::Store::Schema|Kinetic::Store::Schema> to the a file.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 schema_class

  my $schema_class = Kinetic::Build::Setup::Store->schema_class

Returns the name of the Kinetic::Store::Schema subclass that can be used
to generate the schema code to build the data store. By default, this method
returns the same name as the name of the Kinetic::Build::Setup::Store subclass,
but with "Store" replaced with "Schema".

=cut

sub schema_class {
    (my $class = ref $_[0] ? ref shift : shift)
      =~ s/Kinetic::Build::Setup::Store/Kinetic::Store::Schema/;
    return $class;
}

##############################################################################

=head3 store_class

  my $store_class = Kinetic::Build::Setup::Store->store_class

Returns the name of the Kinetic::Store subclass that manages the interface to
the data store for Kinetic applications. By default, this method returns the
same name as the name of the Kinetic::Build::Setup::Store subclass, but with "Build"
removed.

=cut

sub store_class {
    (my $class = ref $_[0] ? ref shift : shift) =~ s/Build::Setup:://;
    return $class;
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
