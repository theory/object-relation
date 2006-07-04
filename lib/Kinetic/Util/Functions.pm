package Kinetic::Util::Functions;

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
our $VERSION = version->new('0.0.2');
use OSSP::uuid;
use MIME::Base64;
use File::Find;
use File::Spec;
use List::Util qw(first sum);
use Kinetic::Util::Exceptions qw/throw_fatal/;
use Kinetic::Util::Config qw/STORE_CLASS/;

=head1 Name

Kinetic::Util::Functions - Kinetic Utility Functions.

=head1 Synopsis

  use Kinetic::Util::Functions qw/:uuid/;
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
        load_store
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

 use Kinetic::Util::Functions ':class';

=cut

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

=head3 load_classes

  my $classes = load_classes($dir);
  my $classes = load_classes($dir, $regex);
  my $classes = load_classes($dir, @regexen);

Loads all of the Kinetic::Meta classes found in the specified directory and
its subdirectories. Use Unix-style directory naming for the $dir argument;
C<load_classes()> will automatically convert the directory path to the
appropriate format for the current operating system. All Perl module files
found in the directory or its subdirectories will be loaded, excepting those
that match one of the regular expressions passed in the $schema_skippers array
reference argument. C<load_classes()> will only store a the
L<Kinetic::Meta::Class|Kinetic::Meta::Class> object for those modules that
inherit from C<Kinetic>.

Returns an array reference of the classes loaded.

=cut

sub load_classes {
    my ($lib_dir, @skippers) = @_;
    my $dir = File::Spec->catdir(split m{/}, $lib_dir);
    unshift @INC, $dir;
    my @classes;
    my $find_classes = sub {
        local *__ANON__ = '__ANON__find_classes';
        return if /\.svn/;
        return unless /\.pm$/;
        return if /#/;    # Ignore old backup files.
        return if first { $File::Find::name =~ m/$_/ } @skippers;
        my $class = file_to_mod( $lib_dir, $File::Find::name );
        eval "require $class" or die $@;

        # Keep the class if it isa Kinetic and is not abstract.
        unshift @classes, $class->my_class
            if $class->isa('Kinetic') && !$class->my_class->abstract;
    };

    find({ wanted => $find_classes, no_chdir => 1 }, $dir);
    shift @INC;
    return \@classes;
}

=head3 load_store

  my $store = load_store($dir);
  my $store = load_store($dir, $regex);
  my $store = load_store($dir, @regexen);

Behaves like C<load_classes> but ensures that the appropriate data store class
is loaded first.

=cut

sub load_store {
    my ($lib_dir, @skippers) = @_;
    my $class = STORE_CLASS;
    eval "require $class" or die $@;
    load_classes( $lib_dir, @skippers );
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
