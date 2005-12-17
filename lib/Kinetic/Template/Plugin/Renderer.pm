package Kinetic::Template::Plugin::Renderer;

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

use HTML::Entities qw/encode_entities/;
use Readonly;
Readonly my $ALLOWED_MODE => qr/^view|edit|search$/;

use base 'Template::Plugin';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Meta::Attribute';
use Kinetic::Util::Exceptions qw/
  throw_invalid
  throw_unimplemented
  /;

=head1 NAME

Kinetic::Template::Plugin::Renderer - Render Kinetic object attributes

=head1 Synopsis

 [% USE Renderer %]
 [% Renderer.render(attr) %]

=head1 Description

This class is used for rendering objects for a given output type and view.
Unlike the L<Kinetic::Format|Kinetic::Format> class, this is a one-way process
and is not suitable for serialization/deserialization.

=cut

##############################################################################

=head3 new

 [% USE Renderer %]

The constructor is automatically called by Template Toolkit.

=cut

sub new {
    my ( $class, $template_context, $value_for ) = @_;

    $value_for->{format} ||= {};
    unless ( 'format mode' eq join ' ', sort keys %$value_for ) {
        throw_invalid [
            'Invalid keys passed to constructor: "[_1]"',
            join ' ', sort keys %$value_for
        ];
    }
    my $self = bless { context => $template_context },
      $class;    # XXX tighten this up later
    $self->mode( $value_for->{mode} );

    $value_for->{format}{view}   ||= '%s';
    $value_for->{format}{edit}   ||= '%s %s';
    $value_for->{format}{search} ||= '%s %s %s';
    while ( my ( $mode, $format ) = each %{ $value_for->{format} } ) {
        $self->format( $mode, $format );
    }
    return $self;
}

##############################################################################

=head3 mode

  [% Renderer.mode('view') %]
  [% IF 'view' == Renderer.mode %]

Getter/setter for rendering mode.  The allowed values for mode are C<view>,
C<edit> and C<search>.  Attempting to set the mode to a different value will
throw an exception.

=cut

sub mode {
    my $self = shift;
    return $self->{mode} unless @_;
    my $mode = shift;
    unless ( $mode =~ $ALLOWED_MODE ) {
        throw_invalid [ 'Unknown render mode "[_1]"', $mode ];
    }
    $self->{mode} = $mode;
    return $self;
}

##############################################################################

=head3 format

  [% Renderer.format('edit', '<td>%s</td><td>%s</tt>') %]

Set the format for a given render mode.

XXX Flesh out POD

=cut

sub format {
    my $self = shift;
    my $mode = shift;
    unless ( $mode =~ $ALLOWED_MODE ) {
        throw_invalid [ 'Unknown render mode "[_1]"', $mode ];
    }
    return $self->{$mode} unless @_;
    $self->{$mode} = shift;
    return $self;
}

##############################################################################

=head3 render

  my $render = $renderer->render($attribute);

Render the L<Kinetic|Kinetic> object attribute according to its
L<Kinetic::Meta::Widget|Kinetic::Meta::Widget> information.

=cut

my %renderer_for = (
    calendar => \&_render_calendar,
    checkbox => \&_render_checkbox,
    dropdown => \&_render_dropdown,
    search   => \&_render_search,
    text     => \&_render_text,
    textarea => \&_render_textarea,
);

sub _context { shift->{context} }

sub render {

    # eventually we'll have to handle 'view' mode
    my $self   = shift;
    my $object = shift;
    if ( $object->isa(Attribute) ) {
        if ( 'view' eq $self->mode ) {
            unless (@_) {
                throw_invalid [];
            }
            my $kinetic_object = shift;
            return sprintf $self->format('view'),
              $object->get($kinetic_object);
        }
        my $widget = $object->widget_meta;
        my $type = $widget ? $widget->type : '';
        if ( my $renderer = $renderer_for{$type} ) {
            return $self->$renderer($object);
        }
        else {
            throw_unimplemented [
                'Could not determine widget type handler for "[_1]"',
                $object->name
            ];
        }
    }
    else {

        # XXX Rendering an entire object
        # XXX will we ever use this?  If so, how?  We'll need some way of
        # specifying the format
    }
}

sub _render_calendar {
    my ( $self, $attribute, $object ) = @_;
    my $w    = $attribute->widget_meta;
    my $type = $w->type;
    my $name = encode_entities( $attribute->name );
    return <<"    END_CALENDAR"
    <input name="$name" id="$name" type="text"/>
    <input id="${name}_trigger" type="image" src="/images/calendar/calendar.gif"/>
    <script type="text/javascript">
      Calendar.setup({
        inputField  : "$name",             // ID of the input field
        ifFormat    : "%Y-%m-%dT00:00:00", // the date format
        button      : "${name}_trigger"    // ID of the button
      });
    </script>
    END_CALENDAR
}

sub _render_checkbox {
    my ( $self, $attribute, $object ) = @_;
    my $w       = $attribute->widget_meta;
    my $name    = encode_entities( $attribute->name );
    my $checked = $w->checked ? ' checked="checked"' : '';
    return qq{<input name="$name" id="$name" type="checkbox"$checked/>};
}

sub _render_dropdown {
    my ( $self, $attribute, $object ) = @_;
    my $w    = $attribute->widget_meta;
    my $name = encode_entities( $attribute->name );
    my $html = qq{<select name="$name" id="$name">\n};
    foreach my $option ( @{ $w->options } ) {
        my ( $value, $name )
          = ( encode_entities( $option->[0] ),
            encode_entities( $option->[1] ) );
        $html .= qq{  <option value="$value">$name</option>\n};
    }
    return $html . '</select>';
}

sub _render_search {
    my ( $self, $attribute, $object ) = @_;
    my $w    = $attribute->widget_meta;
    my $type = $w->type;
    return '<input type="text"> ' . $type;
}

sub _render_text {
    my ( $self, $attribute, $object ) = @_;
    my $w          = $attribute->widget_meta;
    my $label      = encode_entities( $attribute->label );
    my $name       = encode_entities( $attribute->name );
    my $tip        = encode_entities( $w->tip || '' );
    my $size       = $w->size || 40;
    my $length     = $w->length || $size;
    my $html_label = qq{<label for="$name">$label</label>};
    my $input
      = qq{<input name="$name" id="$name" type="text" size="$size" maxlength="$length" tip="$tip"/>};
    return sprintf $self->format('edit'), $html_label, $input;
}

sub _render_textarea {
    my ( $self, $attribute, $object ) = @_;
    my $w    = $attribute->widget_meta;
    my $rows = $w->rows || 4;
    my $cols = $w->cols || 40;
    my $name = encode_entities( $attribute->name );
    my $tip  = encode_entities( $w->tip || '' );
    return
      qq{<textarea name="$name" id="$name" rows="$rows" cols="$cols" tip="$tip"></textarea>};
}

{
    my %from_widget = (
        tip    => '',
        size   => 40,
        length => 40,
        rows   => 4,
        cols   => 40,
    );
    my %from_attribute = (
        label => sub { ucfirst( _fetch_values( @_, 'name' )->{name} ) },
        name  => ''
    );

    sub _fetch_values {
        my ( $attribute, $widget, @names ) = @_;
        my %value_for;
        foreach my $name (@names) {
            my $value;
            if (exists $from_widget{$name}) {
                $value = $widget->$name;
                unless (defined $value) {
                    my $default = $from_widget{$name};
                    if ('CODE' eq ref $default) {
                        $default = $default->($attribute, $widget);
                    }
                    $value = $default;
                }
            }
            elsif (exists $from_attribute{$name}) {
                my $value = $attribute->$name;
                unless (defined $value) {
                    my $default = $from_attribute{$name};
                    if ('CODE' eq ref $default) {
                        $default = $default->($attribute, $attribute);
                    }
                    $value = $default;
                }
            }
            else {
                # throw exception
            }
            $value_for{$name} = $value;
        }
        return \%value_for;
    }
}
1;

__END__

=head1 RENDERING

Rendering a new object attribute is as simple as:

 [% USE Renderer %]
 [% Renderer.render(attr) %]

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this pr292:	final indentation level: 1

Final nesting depth of '{'s is 1
The most recent un-matched '{' is on line 263
263: sub _fetch_values {
                       ^
ogram; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
292:	To see 1 non-critical warnings rerun with -w
292:	To save a full .LOG file rerun with -g
