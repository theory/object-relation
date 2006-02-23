package Kinetic::UI::TT::Plugin::Renderer;

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
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use HTML::Entities qw/encode_entities/;
use Scalar::Util qw/blessed/;

use Readonly;
Readonly my $ALLOWED_MODE     => qr/^view|edit|search$/;
Readonly my @CONSTRAINT_ORDER => qw/limit order_by sort_order/;
Readonly my %CONSTRAINTS      => map { $_ => "_render_$_" } @CONSTRAINT_ORDER;

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

    $value_for->{format}{view}        ||= '%s %s';
    $value_for->{format}{edit}        ||= '%s %s';
    $value_for->{format}{search}      ||= '%s %s %s %s';
    $value_for->{format}{constraints} ||= '%s %s';
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
    unless (@_) {
        my $mode = $self->mode;
        return $self->{$mode};
    }
    my $mode = shift;
    unless ( $mode =~ /^$ALLOWED_MODE|constraints$/ ) {
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
sub _c { shift->{context}{STASH}{c} } # XXX Yuck! (Catalyst object)

sub render {
    my $self  = shift;
    my $thing = shift;

    if ( blessed $thing && $thing->isa(Attribute) ) {
        if ( 'view' eq $self->mode ) {

            # XXX should throw an exception if there is no object
            my $object = shift;
            return sprintf $self->format, $thing->label, $thing->get($object);
        }

        my $type = $thing->widget_meta->type || '';

        if ( my $renderer = $renderer_for{$type} ) {
            $self->_properties($thing);
            return $self->$renderer($thing);
        }
        else {
            throw_unimplemented [
                'Could not determine widget type handler for "[_1]"',
                $thing->name
            ];
        }
    }
    elsif ( defined( my $method = $CONSTRAINTS{$thing} ) ) {
        return $self->$method(shift);
    }
}

sub _properties {
    my $self = shift;
    return $self->{properties} unless @_;
    my $attr      = shift;
    my $w         = $attr->widget_meta;
    my %value_for = (
        name   => encode_entities( $attr->name ),
        label  => encode_entities( $attr->label || ucfirst $attr->name ),
        tip    => encode_entities( $w->tip || '' ),
        size   => ( $w->size || 40 ),
        length => ( $w->length ),
        rows   => ( $w->rows || 4 ),
        cols   => ( $w->cols || 40 ),
        object => shift @_,
    );
    $value_for{length} ||= $value_for{size};
    $value_for{label_html}
      = qq{<label for="$value_for{name}">$value_for{label}</label>};
    $self->{properties} = \%value_for;
}

##############################################################################

=head2 constraints

  [% FOREACH constraint = Renderer.constraints %]
    [% Renderer.render(constraint, class_key) %]
  [% END %]

The C<constraints> method returns an arrayref of the constraints observed in
searches.

=cut

sub constraints { \@CONSTRAINT_ORDER }

#
# constraint rendering methods
#

sub _render_limit {
    my $self = shift;
    return sprintf $self->format('constraints'), 'Limit:',
      '<input type="text" name="_limit" value="20" />';
}

sub _render_order_by {
    my $self   = shift;
    my $key    = shift;
    my $class  = Kinetic::Meta->for_key($key);
    my $select = qq{<select name="_order_by">\n};
    foreach my $attr ( $class->attributes ) {
        $select .= sprintf qq{<option value="%s">%s</option>\n}, $attr->name,
          ($attr->label || ucfirst $attr->name);
    }
    $select .= '</select>';
    return sprintf $self->format('constraints'), 'Order by:', $select;
}

sub _render_sort_order {
    my $self = shift;
    return sprintf $self->format('constraints'), 'Sort order:',
      <<"    END_SORT_ORDER";
    <select name="_sort_order">
        <option value="ASC">Ascending</option>
        <option value="DESC">Descending</option>
    </select>
    END_SORT_ORDER
}

#
# various widget rendering methods
#

sub _render_calendar {
    my ( $self, $attribute, $object ) = @_;
    my $value_for = $self->_properties;
    $value_for->{main} = <<"    END_CALENDAR";
    <input name="$value_for->{name}" id="$value_for->{name}" type="text"/>
    <input id="$value_for->{name}_trigger" type="image" src="/ui/images/calendar/calendar.gif"/>
    <script type="text/javascript">
      Calendar.setup({
        inputField  : "$value_for->{name}",             // ID of the input field
        ifFormat    : "%Y-%m-%dT00:00:00", // the date format
        button      : "$value_for->{name}_trigger"    // ID of the button
      });
    </script>
    END_CALENDAR
    return $self->_do_render($value_for);
}

sub _render_checkbox {
    my ( $self, $attribute, $object ) = @_;
    my $value_for = $self->_properties;
    my $checked
      = $attribute->widget_meta->checked ? ' checked="checked"' : '';
    $value_for->{main}
      = qq{<input name="$value_for->{name}" id="$value_for->{name}" type="checkbox"$checked/>};
    return $self->_do_render($value_for);
}

sub _render_dropdown {
    my ( $self, $attribute, $object ) = @_;
    my $value_for = $self->_properties;
    my $html
      = qq{<select name="$value_for->{name}" id="$value_for->{name}">\n};
    foreach my $option ( @{ $attribute->widget_meta->options } ) {
        my ( $value, $name )
          = ( encode_entities( $option->[0] ),
            encode_entities( $option->[1] ) );
        $html .= qq{  <option value="$value">$name</option>\n};
    }
    $value_for->{main} = $html . '</select>';
    return $self->_do_render($value_for);
}

sub _render_search {
    my ( $self, $attribute, $object ) = @_;

    # XXX flesh this out when we figure it out
    my $value_for = $self->_properties;
    $value_for->{main} = '<input type="text"/> search';
    return $self->_do_render($value_for);
}

sub _render_text {
    my ( $self, $attribute, $object ) = @_;
    my $value_for = $self->_properties;
    $value_for->{main}
      = qq{<input name="$value_for->{name}" id="$value_for->{name}" type="text" size="$value_for->{size}" maxlength="$value_for->{length}" tip="$value_for->{tip}"/>};
    return $self->_do_render($value_for);
}

sub _render_textarea {
    my ( $self, $attribute, $object ) = @_;
    my $value_for = $self->_properties;
    $value_for->{main}
      = qq{<textarea name="$value_for->{name}" id="$value_for->{name}" rows="$value_for->{rows}" cols="$value_for->{cols}" tip="$value_for->{tip}"></textarea>};
    return $self->_do_render($value_for);
}

sub _do_render {
    my ( $self, $value_for ) = @_;
    if ( 'edit' eq $self->mode ) {
        return sprintf $self->format, $value_for->{label_html},
          $value_for->{main};
    }
    else {    # assume search
        my $logical = <<"        END_LOGICAL";
            <select name="_$value_for->{name}_logical" id="_$value_for->{name}_logical">
              <option value="">is</option>
              <option value="NOT">is not</option>
            </select>
        END_LOGICAL

        my $comparison = <<"        END_COMPARISON";
            <!--<select name="_$value_for->{name}_comp" id="_$value_for->{name}_comp" onchange="checkForMultiValues(this); return false">-->
            <select name="_$value_for->{name}_comp" id="_$value_for->{name}_comp">
              <option value="EQ">equal to</option>
              <option value="LIKE">like</option>
              <option value="LT">less than</option>
              <option value="GT">greater than</option>
              <option value="LE">less than or equal</option>
              <option value="GE">greater than or equal</option>
              <option value="NE">not equal</option>
              <!--<option value="BETWEEN">between</option>-->
              <option value="ANY">any of</option>
            </select>
        END_COMPARISON
        return sprintf $self->format, $value_for->{label_html}, $logical,
          $comparison, $value_for->{main};
    }
}

1;

__END__

=head1 RENDERING

Rendering a new object attribute is as simple as:

 [% USE Renderer %]
 [% Renderer.render(attr) %]

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
