package Kinetic::View::XSLT;

# $Id: XSLT.pm 1544 2005-04-16 01:13:51Z curtispoe $

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

use 5.008003;
use strict;
use version;
our $VERSION = version->new('0.0.1');
use Kinetic::Util::Exceptions
  qw/panic throw_exlib throw_not_found throw_required throw_unsupported/;
use Kinetic::Util::Constants qw/:xslt WWW_DIR/;
use aliased 'XML::LibXML';
use aliased 'XML::LibXSLT';

=head1 Name

Kinetic::View::XSLT - XSLT services provider

=head1 Synopsis

 use Kinetic::View::XSLT;

 my $xslt  = Kinetic::View::XSLT->new(type => 'REST');
 my $xhtml = $xslt->transform($rest_xml);

=head1 Description

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

 my $xslt = Kinetic::View::XSLT->new;
 my $xslt = Kinetic::View::XSLT->new(type => $type);;
    
The C<new()> constructor returns a C<Kinetic::View::XSLT> instance.  This object
can return XSLT stylesheets for presenting to a user agent or internally handle
the transformation, if requested.

The C<type> argument is optional.  If not supplied, it must be set via C<type>
prior to C<transform> being called.

=cut

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = bless {} => $class;
    if ( exists $args{type} ) {
        $self->type( $args{type} );
    }
    else {
        throw_required [
            'Required argument "[_1]" to [_2] not found',
            'type', __PACKAGE__ . '::new',
        ];
    }
    return $self;
}

##############################################################################
# Class Methods
##############################################################################

=head2 Class Methods

=cut

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Public methods

=cut

##############################################################################

=head3 type

  $xslt->type($type);
  my $type = $xslt->type;

The type determines which stylesheet will be used for current actions.

Types current supported:

=over 4

=item * REST

This stylesheet is used by L<Kinetic::Interface::REST|Kinetic::Interface::REST>
objects for transforming XML generated by the REST interface.

=item * instance

This stylesheet will transform XML provided by L<Kinetic::XML|Kinetic::XML>
to XHTML.

Throws a C<Kinetic::Util::Exception::Fatal::Unsupported> exception if the type
requested is not found.

=back

=cut

my %STYLESHEET = (
    instance => \&_stylesheet_instance,
    REST     => \&_stylesheet_rest,
);

sub type {
    my $self = shift;
    if (@_) {
        my $type = shift;
        unless ( exists $STYLESHEET{$type} ) {
            throw_unsupported [ "Unknown stylesheet requested: [_1]", $type ];
        }
        $self->{type} = $type;
        return $self;
    }
    return $self->{type};
}

=head3 stylesheet

  my $stylesheet = $xslt->stylesheet;

Returns XSLT stylesheet for the object.

=cut

sub stylesheet {
    my ($self) = @_;
    if ( my $ref = $STYLESHEET{ $self->type } ) {
        return $ref->();
    }
    else {

        # this is required in the constructor.  Should never happen
        panic [ 'Required attribute "[_1]" not set', 'type' ];
    }
}

##############################################################################

=head3 transform

  my $html = $xslt->transform($xml);

This method transforms the supplied xml to xhtml.  It assumes the xml is of
the type specified in the constructor or in the C<type> method.

=cut

sub transform {
    my $self = shift;
    unless (@_) {
        throw_required [
            'Required argument "[_1]" to [_2] not found',
            '$xml',
            __PACKAGE__ . '->transform',
        ];
    }
    my $xml = shift;

    my $parser = LibXML->new;
    my $transform;
    eval {
        my $doc       = $parser->parse_string($xml);
        my $style_doc = $parser->parse_string( $self->stylesheet );

        my $xslt  = LibXSLT->new;
        my $sheet = $xslt->parse_stylesheet($style_doc);
        my $html  = $sheet->transform($doc);
        $transform = $sheet->output_string($html);
    };
    throw_exlib $@ if $@;
    return $transform;
}

##############################################################################

=begin private

=head2 Private Instance Methods

=cut

my $SEARCH_XSLT;
sub _stylesheet_rest {
    unless ($SEARCH_XSLT) {
        my $file = WWW_DIR.SEARCH_XSLT;
        open my $fh, "<", $file or
            throw_not_found [ 'File [_1] not found', $file ];
        $SEARCH_XSLT = do { local $/; <$fh> };
    }
    return $SEARCH_XSLT;
}

my $INSTANCE_XSLT;
sub _stylesheet_instance {
    unless ($INSTANCE_XSLT) {
        my $file = WWW_DIR.INSTANCE_XSLT;
        open my $fh, "<", $file or
            throw_not_found [ 'File [_1] not found', $file ];
        $INSTANCE_XSLT = do { local $/; <$fh> };
    }
    return $INSTANCE_XSLT;
}

=end private

=cut

1;
__END__

##############################################################################

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
