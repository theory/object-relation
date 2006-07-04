package Kinetic::UI::REST::Dispatch;

# $Id$

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
our $VERSION = version->new('0.0.2');

use Scalar::Util qw/blessed/;

use aliased 'Kinetic::Util::Iterator';

use Kinetic::Meta;
use Kinetic::Store;
use Kinetic::Util::Constants qw/:http :rest/;
use Kinetic::Util::Context;

use Class::BuildMethods qw(
  class_key
  formatter
  language
  rest
);

=head1 Name

Kinetic::UI::REST::Dispatch - Dispatch REST services provider

=head1 Synopsis

 use Kinetic::UI::REST::Dispatch;

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

  my $dispatch = Kinetic::UI::REST::Dispatch->new({ rest => $rest });

The constructor. The C<rest> parameter should be an object conforming to the
C<Kinetic::UI::Rest> interface.

=cut

sub new {
    my ( $class, $arg_for ) = @_;
    my $self = bless {}, $class;
    $self->rest( $arg_for->{rest} );
    $self->language( Kinetic::Util::Context->language );
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

 $dispatch->handle_rest_request(@args);

This method sets the rest response and content type based upon the arguments
passed to it.  The C<@args> array is assumed to be an array of array refs.
Each array reference should have the "method" as the first item and the
"arguments" to that method as subsequent elements.  If an iterator, collection
or list is returned, subsequent array reference method and arguments will be
applied in turn to each item returned.  A transaction will wrap all if there
is more than one.  For example, if the arguments are as follows:

 [ squery => 'name => "foo"' ],
 [ name   => 'bar'           ],
 [ 'save'                    ]

Then we fetch every object who's name is "foo", change that name to "bar" and
save it.

This method expects that C<class_key> has been set prior to calling it.

=cut

# XXX the docs on this suck!
sub handle_rest_request {
    my ( $self, @method_chain ) = @_;

    $method_chain[0] ||= [];
    my ( $method, @args ) = @{ $method_chain[0] };

    unless ( defined $method_chain[0][0] ) {
        return $self->_bad_request(
            "No method supplied with " . $self->rest->path_info );
    }
    if ( @method_chain > 1 ) {
        return $self->_handle_chain(@method_chain);
    }
    else {
        return $self->_handle_single_request( @{ $method_chain[0] } );
    }
}

sub _handle_single_request {
    my ( $self, $method, @args ) = @_;
    my $results = $self->_execute_method( $method, @args );
    unless ($results) {
        return $self->_not_implemented($method);
    }
    my $response = $self->formatter->ref_to_format($results);
    return $self->rest->content_type( $self->formatter->content_type )
      ->response($response);
}

sub _handle_chain {
    my ( $self, @method_chain ) = @_;
    my $first_link = shift @method_chain;
    my ( $method, @args ) = @$first_link;
    my $rest = $self->rest;

    # XXX this is just a proof of concept.  I'll clean it up later.
    if ( 'new' ne $method && 'squery' ne $method && 'lookup' ne $method ) {
        return $rest->status($HTTP_NOT_IMPLEMENTED)->response(
            $self->language->maketext(
                'The first method in a chain must return objects. You used "[_1]"',
                $method,
            )
        );
    }
    my $result = $self->_execute_method( $method, @args );
    my @objects;
    if ( $result->isa('Kinetic') ) {
        @objects = $result;
    }
    else {    # assume it's an iterator
        while ( my $object = $result->next ) {
            push @objects => $object;
        }
    }

    foreach my $link (@method_chain) {
        my ( $method, @args ) = @$link;
        foreach my $object (@objects) {
            $object->$method(@args);
        }
    }
    my $response = $self->formatter->ref_to_format( \@objects );
    $self->rest->status($HTTP_OK)
      ->content_type( $self->formatter->content_type )->response($response);
    return $self;
}

sub _execute_method {
    my ( $self, $method, @args ) = @_;
    my $class = $self->class;
    if ( my $method_object = $class->methods($method) ) {
        if ( $method_object->context == Class::Meta::CLASS ) {
            return $method_object->call( $class->package, @args );
        }
        else {

            die "We aren't handling this yet!";

            # XXX we're not actually doing anything with this yet.
            #my $obj = $self->class->contructors('lookup')->call(@$args)
            #  or die;
            #$method->call( $obj, @$args );
        }
    }
    elsif ( my $ctor = $class->constructors($method) ) {
        return $ctor->call( $class->package, @args );
    }
}

sub _not_implemented {
    my ( $self, $method ) = @_;
    $method = '' unless defined $method;
    my $rest = $self->rest;
    my $info = $rest->path_info;
    $rest->status($HTTP_NOT_IMPLEMENTED)->response(
        $self->language->maketext(
            'No resource available to handle "[_1]"',
            "$info$method"
        )
    );
}

sub _bad_request {
    my ( $self, $message ) = @_;
    $self->rest->status($HTTP_BAD_REQUEST)->response($message);
}

1;
