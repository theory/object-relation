package Kinetic::Store::Functions;

# $Id$

use strict;
use version;
our $VERSION = version->new('0.0.2');
use OSSP::uuid;
use MIME::Base64;
use File::Find::Rule;
use File::Spec;
use List::Util qw(first sum);
use Kinetic::Store::Exceptions qw/throw_fatal/;

=head1 Name

Kinetic::Store::Functions - Kinetic Utility Functions.

=head1 Synopsis

  use Kinetic::Store::Functions qw/:uuid/;
  my $uuid = create_uuid();

=head1 Description

This class is a centralized repository for Kinetic utility functions.

=cut

use Exporter::Tidy
    uuid => [qw(
        create_uuid
        uuid_to_bin
        uuid_to_hex
        uuid_to_b64
    )],
    gtin => [qw(isa_gtin)],
    class => [qw(
        file_to_mod
        load_classes
    )],
;

##############################################################################

=head2 :uuid

These functions manage UUIDs.

=over

=item * create_uuid()

Generates and returns a version 4 UUID string.

=item * uuid_to_bin

Converts a UUID from its string representation into its binary representation.

=item * uuid_to_hex

Converts a UUID from its string representation into its hex representation.

=item * uuid_to_b64

Converts a UUID from its string representation into its base 64
representation.

=back

=cut

sub create_uuid {
    my $uuid = OSSP::uuid->new;
    $uuid->make('v4');
    return $uuid->export('str');
}

sub uuid_to_bin {
    my $uuid = OSSP::uuid->new;
    $uuid->import(str => shift);
    return $uuid->export('bin');
}

sub uuid_to_hex {
    (my $uuid = shift) =~ s/-//g;
    return "0x$uuid";
}

sub uuid_to_b64 {
    encode_base64(uuid_to_bin(shift));
}

##############################################################################

=head2 :gtin

=head3 isa_gtin

  print "$gtin is valid\n" if isa_gtin($gtin);

Returns true if GTIN argument is valid, and false if it is not.

The checksum is calculated according to this equation:

=over

=item 1

Add the digits in the 1s, 100s, 10,000s, etc. positions together and multiply
by three.

=item 2

Add the digits in the 10s, 1,000s, 100,000s, etc. positions to the result.

=item 3

Return true if the result is evenly divisible by 10, and false if it is not.

=back

See
L<http://www.gs1.org/productssolutions/idkeys/support/check_digit_calculator.html#how>
for tables describing how GTIN checkdigits are calculated.

=cut

# This function must return 0 or 1 to properly work in SQLite.
# http://www.justatheory.com/computers/programming/perl/stepped_series.html

sub isa_gtin ($) {
    my @nums = reverse split q{}, shift;
    no warnings 'uninitialized';
    (
        sum( @nums[ map { $_ * 2 + 1 } 0 .. $#nums / 2 ] ) * 3
      + sum( @nums[ map { $_ * 2     } 0 .. $#nums / 2 ] )
    ) % 10 == 0 ? 1 : 0;
}

##############################################################################

=head2 Class handling functions

The following functions are generic utilities for handling classes.  They can
be imported individually or with the C<:class> tag.

 use Kinetic::Store::Functions ':class';

=cut

##############################################################################

=head3 file_to_mod

  my $module = file_to_mod($search_dir, $file);

Converts a file name to a Perl module name. The file name may be an absolute or
relative file name ending in F<.pm>.  C<file_to_mod()> will walk through both
the C<$search_dir> directories and the C<$file> directories and remove matching
elements of each from C<$file>.

=cut

sub file_to_mod {
    my ($search_dir, $file) = @_;
    $file =~ s/\.pm$// or throw_fatal [ "[_1] is not a Perl module", $file ];
    my (@dirs)      = File::Spec->splitdir($file);
    my @search_dirs = split /\// => $search_dir;
    while (defined $search_dirs[0] and $search_dirs[0] eq $dirs[0]) {
        shift @search_dirs;
        shift @dirs;
    }
    join '::', @dirs;
}

##############################################################################

=head3 load_classes

  my $classes = load_classes(@dirs);
  my @classes = load_classes(@dirs, $rule);

Uses L<File::Find::Rule|File::Find::Rule> to find and load all Perl modules
found in the directories specified and their subdirectories, and returns a
list or array reference of the Kinetic::Store::Meta::Class objects for each that
inherits from C<Kinetic> and is not abstract. If the last argument so the
method is not a File::Find::Rule object, one will be created that ignores
directories named F<.svn> and C<CVS> and loads all files that end in F<.pm>
and do not contain "#" in their names. If you need something more strict or
lenient, create your own File::Find::Rule object and pass it as the last
argument. Use Unix-style directory naming for the directory arguments;
C<load_classes()> will automatically convert the them to the appropriate
format for the current operating system.

=cut

sub load_classes {
    my $rule = ref $_[-1] ? pop : File::Find::Rule->or(
        File::Find::Rule->directory
                        ->name( '.svn', 'CVS' )
                        ->prune
                        ->discard,
        File::Find::Rule->name( qr/\.pm$/ )
                        ->not_name( qr/#/ )
   );

    my @classes;
    for my $lib_dir (@_) {
        my $dir = File::Spec->catdir(split m{/}, $lib_dir);
        unshift @INC, $dir;
        $rule->start($dir);
        while ( my $file = $rule->match ) {
            my $class = file_to_mod( $lib_dir, $file );
            eval "require $class" or die $@;

            # Keep the class if it isa Kinetic and is not abstract.
            unshift @classes, $class->my_class
                if $class->isa('Kinetic') && !$class->my_class->abstract;
        }
        shift @INC;
    }

    return wantarray ? @classes : \@classes;
}

1;

__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
