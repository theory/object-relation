package Template::Plugin::Renderer;

# $Id: JSON.pm 2190 2005-11-08 02:05:10Z curtis $

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
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use base 'Template::Plugin';
use aliased 'Kinetic';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Meta::Attribute';
use Kinetic::Util::Exceptions qw/
  throw_fatal
  throw_invalid_class
  throw_unimplemented
  /;

=head1 Name

Kinetic::Render - Render Kinetic objects for different views

=head1 Synopsis

  use Kinetic::Render;
  my $render = Kinetic::Render->new( { 
    view   => 'read',  # or 'write'
  } );
  my $html   = $render->render($kinetic_object);

  my $class  = $kinetic_object->my_class;
  
  $render->view('write'); # for editing
  foreach my $attr ($class->attributes) {
    $render->render($attr);
  }

=head1 Description

This class is used for rendering objects for a given output type and view.
Unlike the L<Kinetic::Render|Kinetic::Render> class, this is a one-way process
and is not suitable for serialization/deserialization.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Render->new({ format => 'html' });

Creates and returns a new format object.  Requires a hashref as an argument.
The key C<format> in the hashref must be a valid format with the Kinetic
Platform supports.  Currently supported formats are:

=over 4 

=item * html

=back

=cut

sub new {
    my ( $class, %args ) = @_;
    bless \%args, $class;    # XXX tighten this up later
}

##############################################################################

=head3 render

  my $render = $renderer->render($object);

Render the L<Kinetic|Kinetic> object in the desired format.

=cut

my %renderer_for = (
    calendar => \&_render_calendar,
    checkbox => \&_render_checkbox,
    dropdown => \&_render_dropdown,
    search   => \&_render_search,
    text     => \&_render_text,
    textarea => \&_render_textarea,
);

sub render {
    my $self   = shift;
    my $object = shift;
    if (@_) {
        return $self->_render_attribute( $object, shift );
    }
    elsif ( $object->isa(Attribute) ) {
        my $widget = $object->widget_meta;
        my $type = $widget ? $widget->type : '';
        my $renderer = $renderer_for{$type};
        return '<input type="text">' unless $renderer; # XXX warn?
        return $self->$renderer($object, $widget);
    }
    else {

        # XXX Rendering an entire object
        # XXX will we ever use this?  If so, how?  We'll need some way of
        # specifying the format
    }
}

sub _render_attribute {
    my ( $self, $object, $attr ) = @_;
    return $attr->get($object);
}

sub _render_calendar {
    my ($self, $attribute, $widget) = @_;
    my $type = $widget->type;
    return '<input type="text"> ' . $type;
}

sub _render_checkbox {
    my ($self, $attribute, $widget) = @_;
    my $type = $widget->type;
    return '<input type="text"> ' . $type;
}

sub _render_dropdown {
    my ($self, $attribute, $widget) = @_;
    my $type = $widget->type;
    return '<input type="text"> ' . $type;
}

sub _render_search {
    my ($self, $attribute, $widget) = @_;
    my $type = $widget->type;
    return '<input type="text"> ' . $type;
}

sub _render_text {
    my ($self, $attribute, $widget) = @_;
    my $type = $widget->type;
    return '<input type="text"> ' . $type;
}

sub _render_textarea {
    my ($self, $attribute, $widget) = @_;
    my $type = $widget->type;
    return '<input type="text"> ' . $type;
}

1;

__END__

=head1 IMPLEMENTING A NEW FORMAT

Adding a new format is as simple as implementing the format with the format
name as the class name upper case, appended to C<Kinetic::Render>:

 package Kinetic::Render::HTML;

Factory classes must meet the following conditions:

=over 4

=item * Inherit from L<Kinetic::Render>.

The factory class should inherit from C<Kinetic::Render>. 

=item * C<new> is optional.

A constructor should not be supplied, but if it is, it should be named C<new>
and should call the super class constructor.

=item * Implement C<_init> method.

It should have an C<_init> method which sets up special properties, if any, of
the class.  If an init method is present, it should accept an optional hash
reference of properties necessary for the class and return a single argument.

=item * Implement C<format_to_ref> and C<ref_to_format> methods.

The input and output is described in this document.  Implementation behavior
is up to the implementor.

=back

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

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
