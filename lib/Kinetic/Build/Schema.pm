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
use Kinetic::Meta;
use Kinetic::Meta::Class::Schema;
use Kinetic::Meta::Attribute::Schema;
use Kinetic::Util::Config qw(:store);
use File::Find;
use File::Spec;
use File::Path;
use Carp;

Kinetic::Meta->class_class('Kinetic::Meta::Class::Schema');
Kinetic::Meta->attribute_class('Kinetic::Meta::Attribute::Schema');

=head1 Name

Kinetic::Build::Schema - Kinetic data store schema generation

=head1 Synopsis

  use Kinetic::Schema;
  my $sg = Kinetic::Schema->new;
  $sg->generate_to_file($file_name);

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
  my $sg = Kinetic::Build::Schema->new( $store_class );

Creates and returns a new Schema object. This is a factory constructor; it
will return the subclass appropriate to the currently selected store class as
configured in F<kinetic.conf>. Pass in a specific store class name or call
C<new()> directly on a store subclass to override the class selected from
configuration.

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
C<load_classes()> method. Pass in a list of classes to set them specifically.

=cut

sub classes {
    my $self = shift;
    return $self->{classes} ? @{$self->{classes}} : () unless @_;
    $self->{classes} = \@_;
}

##############################################################################

=head2 Instance Methods

=head3 load_classes

  $sg->load_classes('lib');

Loads all of the Kinetic::Meta classes found in the specified directory and
its subdirectories. Use Unix-style directory naming; C<load_classes()> will
automatically convert it to be appropriate to the current operating system.
All Perl modules found in the directory will be loaded, but C<load_classes()>
will only store a the C<Kineti::Meta::Class> object for those modules that
inherit from C<Kinetic>.

=cut

sub load_classes {
    my $self = shift;
    my $dir = File::Spec->catdir(split m{/}, shift);
    unshift @INC, $dir;
    my @classes;
    my $find_classes = sub {
        return if /\.svn/;
        return unless /\.pm$/;
        return if /#/; # Ignore old backup files.
        my $class = $self->file_to_mod($File::Find::name);
        eval "require $class" or die $@;
        push @classes, $class->my_class if UNIVERSAL::isa($class, 'Kinetic');
    };

    find({ wanted => $find_classes, no_chdir => 1 }, $dir);
    $self->{classes} = \@classes;
    return $self;
}

##############################################################################

=head3 write_schema

  $sg->write_schema($file_name);
  $sg->write_schema($file_name, \%params);

Writes storage schema generation code to C<$file_name>. All classes loaded by
C<load_classes()> will have their schemas written to the file. The optional
hash reference takes a number of possible keys:

=over

=item order

An array refererence of class keys for classes to be written to the schema
file in the order in which they appear in the array. This is important for
classes that have dependencies on other classes (inheritance, composition).
Classes loaded by C<load_classes()> but not in this list will have their
schema generation code output after the classes specified by the C<order>
parameter.

=item with_kinetic

If set to a true value, this parameter causes the Kinetic framework's class
schema and setup SQL to be written to the file, as well. This is useful for
setting up a Kinetic application with a new database.

=back

=cut

sub write_schema {
    my $self = shift;
    my (@parts) = split m{/}, shift;
    my $params = shift || {};
    my $file = File::Spec->catfile(@parts);
    pop @parts;
    my $dir = File::Spec->catdir(@parts);
    mkpath $dir;
    open my $fh, '>', $file or die "Cannot open '$file': $!\n";

    if ($params->{with_kinetic}) {
        if (my $sql = $self->setup_sql) {
            print $fh $sql, "\n";
        }
        # XXX Add code to load the Kinetic classes here.
    }

    my %seen;
    if (my $keys = $params->{order}) {
        for my $key (@$keys) {
            $seen{$key} = 1;
            my $class = Kinetic::Meta->for_key($key)
              or croak "No such class for key '$key'";
            print $fh $self->schema_for_class($class), "\n";
        }
    }

    for my $class ($self->classes) {
        next if $seen{$class->key};
        print $fh $self->schema_for_class($class), "\n";
    }
    close $fh;
    return $self;
}

sub setup_sql { return }

##############################################################################

=head3 schema_for_class

  my $schema = $sg->schema_for_class($class);

Returns the schema that can be used to build the data store for the class
passed as an argument. The class can be either a class name or a
C<Kinetic::Meta::Class> object.

=cut

# Must be implemented in subclasses.

##############################################################################

=head3 file_to_mod

  my $module = $sg->file_to_mod($file);

Converts a file name to a Perl module name. The file name is expected to be a
relative file name ending in ".pm". It's okay if it starts with "t", "lib", or
"t/lib"; C<file_to_mod()> will simply strip of those directory names.

=cut

sub file_to_mod {
    my ($self, $file) = @_;
    $file =~ s/\.pm$// or die "$file is not a Perl module";
    my (@dirs) = File::Spec->splitdir($file);
    while ($dirs[0] && ($dirs[0] eq 't' || $dirs[0] eq 'lib')) {
        shift @dirs;
    }
    join '::', @dirs;
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
