package Kinetic::UI::REST::JSON;

# $Id: REST.pm 1544 2005-04-16 01:13:51Z theory $

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;

use version;
our $VERSION = version->new('0.0.1');

use Array::AsHash;
use Scalar::Util qw/blessed/;

use aliased 'Kinetic::Util::Iterator';

use Kinetic::Meta;
use Kinetic::Store;
use Kinetic::Util::Constants qw/:http :rest/;
use Kinetic::Util::Exceptions qw/throw_fatal throw_invalid_class/;

use Class::BuildMethods 'rest', 'class_key', 'formatter',
  method => { default => '' };

=head1 Name

Kinetic::UI::REST::JSON - JSON REST services provider

=head1 Synopsis

 use Kinetic::UI::REST::JSON;

 if (my $sub = Kinetic::UI::REST::XML->can($method)) {
   $sub->($rest);
 }

=head1 Description

This is the dispatch class to which
L<Kinetic::UI::REST|Kinetic::UI::REST> will dispatch methods.
This is kept in a separate class to ensure that REST servers do not call these
methods directly.

=cut

##############################################################################

=head3 new

  my $dispatch = Kinetic::UI::REST::JSON->new({ rest => $rest });

The constructor. The C<rest> parameter should be an object conforming to the
C<Kinetic::UI::Rest> interface.

=cut

sub new {
    my ( $class, $arg_for ) = @_;
    my $self = bless {}, $class;
    $self->rest( $arg_for->{rest} );
    return $self;
}

##############################################################################

=head3 rest

  my $rest = $dispatch->rest;
  $dispatch->rest($rest);

Getter/setter for REST object.

=head3 class_key

  my $class_key = $dispatch->class_key;
  $dispatch->class_key($class_key);

Getter/setter for class key we're working with.

=head3 class

  my $class = $dispatch->class;
  $dispatch->class($class);

This method will return the current class object we're searching on. If the
class object has not been explicitly set with this method, it will attempt to
build a class object for using the current class key.

=cut

sub class {
    my $self = shift;
    if (@_) {
        $self->{class} = shift;
        return $self;
    }
    $self->{class} ||= Kinetic::Meta->for_key( $self->class_key );
    return $self->{class};
}

##############################################################################

=head3 method

  my $method = $dispatch->method;
  $dispatch->method($method);

Getter/setter for method to be sent to class created from class key.

=head3 formatter

  my $formatter = $dispatch->formatter;
  $dispatch->formatter($formatter);

Getter/setter for formatter object used to turn method results into the
appropriate format for returning to the client.

At the present time, the formatter must provide the following method:

=over 4

=item * ref_to_format

 my $format = $formatter->ref_to_format($reference);

Given a reference to a Perl data structure, this method should render it in
the correct format.

=back

=head3 handle_rest_request

 $dispatch->handle_rest_request

=cut

sub handle_rest_request {
    my ( $self, $method, @args ) = @_;

    unless ( defined $method ) {
        return $self->_not_implemented;
    }
    my ( $class, $method_object, $ctor );
    eval { $class = Kinetic::Meta->for_key( $self->class_key ) };
    if ( $class && $method ) {
        $self->class($class);
        $method_object = $class->methods($method);
        $ctor = $method_object ? '' : $class->constructors($method);
    }

    return $ctor ? $self->_handle_constructor( $ctor, @args )
      : $method_object ? $self->_handle_method( $method_object, @args )
      : $self->_not_implemented($method);
}

sub _handle_constructor {
    my ( $self, $ctor, @args ) = @_;
    my $obj = $ctor->call( $self->class->package, @args );
    my $response = $self->formatter->ref_to_format($obj);
    return $self->rest->response($response);
}

sub _handle_method {
    my ( $self, $method, @args ) = @_;

    if ( $method->context == Class::Meta::CLASS ) {
        $self->rest->content_type($TEXT_CT);
        my $response = $method->call( $self->class->package, @args );
        if ( blessed $response && $response->isa(Iterator) ) {
            my @response;
            while ( my $object = $response->next ) {
                push @response => $object;
            }
            $response = \@response;
        }
        $response = $self->formatter->ref_to_format($response);
        return $self->rest->response($response);
    }
    else {

        # XXX we're not actually doing anything with this yet.
        #my $obj = $self->class->contructors('lookup')->call(@$args)
        #  or die;
        #$method->call( $obj, @$args );
    }
}

sub _not_implemented {
    my ( $self, $method ) = @_;
    $method = '' unless defined $method;
    my $rest = $self->rest;
    my $info = $rest->path_info;
    $rest->status($HTTP_NOT_IMPLEMENTED)
      ->response("No resource available to handle ($info$method)");
}

1;
