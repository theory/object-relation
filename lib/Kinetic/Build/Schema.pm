package Kinetic::Build::Schema;

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

use Kinetic::Meta;
use Kinetic::Meta::Class::Schema;
use Kinetic::Meta::Attribute::Schema;
use Kinetic::Util::Config qw(:store);
use File::Find;
use File::Spec;
use File::Path;
use Carp;
use List::Util qw(first);

Kinetic::Meta->class_class('Kinetic::Meta::Class::Schema');
Kinetic::Meta->attribute_class('Kinetic::Meta::Attribute::Schema');

=head1 Name

Kinetic::Build::Schema - Kinetic data store schema generation

=head1 Synopsis

  use Kinetic::Build::Schema;
  my $sg = Kinetic::::Build::Schema->new;
  $sg->write_schema($file_name);

=head1 Description

This module generates and outputs to a file the schema information necessary
to create a data store for a Kinetic application. The schema will be generated
for the data store class specified by the C<STORE_CLASS> F<kinetic.conf>
directive.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $sg = Kinetic::Build::Schema->new;

Creates and returns a new Schema object. This is a factory constructor; it
will return the subclass appropriate to the currently selected store class as
configured in F<kinetic.conf>.

=cut

sub new {
    my $class = shift;
    unless ($class ne __PACKAGE__) {
        $class = shift || STORE_CLASS;
        $class =~ s/^Kinetic::Store/Kinetic::Build::Schema/;
        eval "require $class" or die $@;
    }
    bless {}, $class;
}

##############################################################################
# Instance Methods
##############################################################################

=head1 Instance Interface

=head2 Instance Attributes

=head3 classes

  my @classes = $sg->classes;
  $sg->classes(@classes);

The C<Kinetic::Meta::Class> objects representing classes loaded by the
C<load_classes()> method. The classes will be returned in an order appropriate
for satisfying dependencies; that is, classes that depend on other classes
will be returned after the classes on which they depend.

Pass in a list of classes to set them explicitly. Dependency ordering will not
be guaranteed after setting the classes, so be sure to pass them in in the
order you need them.

=cut

sub classes {
    my $self = shift;
    return $self->{classes} ? @{$self->{classes}} : () unless @_;
    $self->{classes} = \@_;
}

##############################################################################

=head2 Instance Methods

=head3 load_classes

  $sg->load_classes($dir);
  $sg->load_classes($dir, $regex);
  $sg->load_classes($dir, @regexen);

Loads all of the Kinetic::Meta classes found in the specified directory and
its subdirectories. Use Unix-style directory naming for the $dir argument;
C<load_classes()> will automatically convert the directory path to the
appropriate format for the current operating system. All Perl module files
found in the directory or its subdirectories will be loaded, excepting those
that match one of the regular expressions passed in the $schema_skippers array
reference argument. C<load_classes()> will only store a the
L<Kinetic::Meta::Class|Kinetic::Meta::Class> object for those modules that
inherit from C<Kinetic>.

=cut

sub load_classes {
    my ($self, $lib_dir, @skippers) = @_;
    my $dir = File::Spec->catdir(split m{/}, $lib_dir);
    unshift @INC, $dir;
    my @classes;
    my $find_classes = sub {
        local *__ANON__ = '__ANON__find_classes';
        return if /\.svn/;
        return unless /\.pm$/;
        return if /#/;    # Ignore old backup files.
        return if first { $File::Find::name =~ m/$_/ } @skippers;
        my $class = $self->file_to_mod( $lib_dir, $File::Find::name );
        eval "require $class" or die $@;

        # Keep the class if it isa Kinetic and is not abstract.
        unshift @classes, $class->my_class
            if $class->isa('Kinetic') && !$class->my_class->abstract;
    };

    find({ wanted => $find_classes, no_chdir => 1 }, $dir);
    shift @INC;

    # Store classes according to dependency order.
    my (@sorted, %seen);
    for my $class (
        map  { $_->[1] }
        sort { $a->[0] cmp $b->[0] }
        map  { [$_->key => $_ ] } @classes
    ) {
        push @sorted, $self->_sort_class(\%seen, $class)
          unless $seen{$class->key}++;
    }

    $self->{classes} = \@sorted;
    return $self;
}

##############################################################################

=head3 write_schema

  $sg->write_schema($file_name);
  $sg->write_schema($file_name, \%params);

Writes the data store schema generation code to C<$file_name>. If the file or
its directory path don't exist, they will be created. All classes loaded by
C<load_classes()> will have their schemas written to the file. The optional
hash reference takes a number of possible keys:

=over

=item with_kinetic

If set to a true value, this parameter causes the Kinetic framework's class
schema and setup code to be written to the file, as well. This is useful for
setting up a Kinetic application with a new database.

=back

=cut

sub write_schema {
    my $self = shift;
    my (@parts) = split m{/}, shift;
    my $params = shift || {};
    my $file = File::Spec->catfile(@parts);

    # Create the directory, if necessary, and open the file.
    pop @parts; # drop the filename
    my $dir = File::Spec->catdir(@parts);
    mkpath $dir if $dir; # don't do this if they didn't give us a filename
    open my $fh, '>', $file or croak "Cannot open '$file': $!\n";

    if (my $begin = $self->begin_schema) {
        print $fh $begin, "\n";
    }
    if ($params->{with_kinetic}) {
        if (my @code = $self->setup_code) {
            print $fh join ("\n", @code), "\n";
        }
        # XXX Add code to load the Kinetic classes here.
    }

    for my $class ($self->classes) {
        print $fh $self->schema_for_class($class), "\n";
    }
    print $fh $self->end_schema, "\n";

    close $fh;
    return $self;
}

##############################################################################

=head3 begin_schema

  my $code = $sg->begin_schema;

Returns any schema code to be output at the beginning of a schema file.
Returns C<undef> by default, but subclasses may override it.

=cut

sub begin_schema { return }

##############################################################################

=head3 end_schema

  my $code = $sg->end_schema;

Returns any schema code to be output at the end of a schema file. Returns
C<undef> by default, but subclasses may override it.

=cut

sub end_schema { return }

##############################################################################

=head3 setup_code

  my $code = $sg->setup_code;

Returns any schema code necessary for setting up a data store, such as
sequences or database functions. This code will be output by C<write_schema()>
before any of the class schema code. Returns C<undef> by default, but
subclasses may override it.

=cut

sub setup_code { return }

##############################################################################

=head3 schema_for_class

  my @schema = $sg->schema_for_class($class);

Returns a list of the schema statements that can be used to build the data
store for the class passed as an argument. The class can be either a class
name or a C<Kinetic::Meta::Class> object, but must have been loaded by
C<load_classes()>. This method is abstract; it must be implemented by
subclasses.

=cut

# Must be implemented in subclasses.

##############################################################################

=head3 file_to_mod

  my $module = $sg->file_to_mod($search_dir, $file);

Converts a file name to a Perl module name. The file name may be an absolute or
relative file name ending in F<.pm>.  C<file_to_mod()> will walk through both
the C<$search_dir> directories and the C<$file> directories and remove matching
elements of each from C<$file>.

=cut

sub file_to_mod {
    my ($self, $search_dir, $file) = @_;
    $file =~ s/\.pm$// or croak "$file is not a Perl module";
    my (@dirs)      = File::Spec->splitdir($file);
    my @search_dirs = split /\// => $search_dir;
    while (defined $search_dirs[0] and $search_dirs[0] eq $dirs[0]) {
        shift @search_dirs;
        shift @dirs;
    }
    join '::', @dirs;
}

##############################################################################

=begin private

=head1 Private Methods

=head2 Private Instance Methods

=head3 _sort_class

  my @classes = $schema->_sort_class(\%seen, $class);

Returns the Kinetic::Meta::Class::Schema object passed in, as well as any
other classes that are dependencies of the class. Dependencies are returned
before the classes that depend on them. This method is called recursively, so
it's important to pass a hash reference to keep track of all the classes seen
to prevent duplicates. This method is used by C<load_classes()>.

=cut

sub _sort_class {
    my ($self, $seen, $class) = @_;
    my @sorted;
    # Grab all parent classes.
    if (my $parent = $class->parent) {
        push @sorted, $self->_sort_class($seen, $parent)
          unless $seen->{$parent->key}++;
    }

    # Grab all referenced classes.
    for my $attr ($class->table_attributes) {
        my $ref = $attr->references or next;
        push @sorted, $self->_sort_class($seen, $ref)
          unless $seen->{$ref->key}++;
    }
    return @sorted, $class;
}

1;
__END__

##############################################################################

=end private

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
