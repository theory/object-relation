package Kinetic::UI::Catalyst;

use strict;
use warnings;

use Cwd;
use File::Spec::Functions qw(catdir);

use aliased 'Kinetic::Build::Schema';

use version;
our $VERSION = version->new('0.0.1');

my ( $schema, $root );

BEGIN {

    $root = $ENV{KINETIC_ROOT} || getcwd();

    # XXX this needs to be externally configurable
    $schema = Schema->new;
    $schema->load_classes( catdir( $root, 't/sample/lib' ) );
}

#
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
# Static::Simple: will serve static files from the applications root directory
#

my @DEBUG;

BEGIN {
    unless ( $ENV{HARNESS_ACTIVE} ) {

        # Don't display debugging information when running tests
        # We'll eventually want to have finer-grained control over this
        @DEBUG = '-Debug';
    }
}

use Catalyst @DEBUG, qw/
  Authentication
  Authentication::Store::Minimal
  Authentication::Credential::Password
  Session
  Session::Store::File
  Session::State::Cookie
  Static::Simple
  /;

__PACKAGE__->config(
    name    => 'Kinetic Catalyst Interface',
    classes => [
        grep { !Kinetic::Meta->for_key($_)->abstract }
          sort Kinetic::Meta->keys
    ],
    'V::TT' => {
        INCLUDE_PATH => __PACKAGE__->path_to('www/templates/tt'),
        PLUGIN_BASE  => 'Kinetic::UI::TT::Plugin',
    },
    authentication => {
        users => {
            ovid   => { password => 'divo' },
            theory => { password => 'theory' }
        }
    }
);

__PACKAGE__->setup;

=head1 NAME

Kinetic::UI::Catalyst - Catalyst UI for Kinetic Platform

=head1 SYNOPSIS

    script/server.pl

=head1 DESCRIPTION

Catalyst based application.

=head1 METHODS

=head2 default

=cut

##############################################################################

=head2 begin

This is the default start action for all Catalyst actions.  It checks to see
if we have an authenticated user and, if not, forwards them to the login page.

See L<Kinetic::UI::Catalyst::C::Login|Kinetic::UI::Catalyst::C::Login> for
more information.

=cut

sub begin : Private {
    my ( $self, $c ) = @_;

    my $cwd = getcwd();
    opendir CWD, $cwd or die "Could not open $cwd: $!";
    my @dirs = readdir(CWD) or die "Could not readdir $cwd: $!";
    $c->stash->{debug} = {
        conf => $ENV{KINETIC_CONF},
        env  => \%ENV,
    };

    # move this to its own method
    if ( defined( my $version = $ENV{MOD_PERL_API_VERSION} ) ) {
        if ( 2 <= $version ) {
            require Apache2::Directive;

            my $tree         = Apache2::Directive::conftree();
            my $documentroot = $tree->lookup('DocumentRoot');
            my $vhost        = $tree->lookup( 'VirtualHost', 'localhost' );
            my $servername   = $vhost->{'ServerName'};

            $c->stash->{debug}{tree}  = $tree->as_hash;
            $c->stash->{debug}{vhost} = $vhost;
        }
    }

    # force login for all pages
    unless ( $c->user ) {
        $c->req->action(undef);
        $c->forward( 'login', 'login' );
    }
}

#
# Output a friendly welcome message
#

sub default : Private {
    my ( $self, $c ) = @_;

    # Hello World
    #$c->response->body( $c->welcome_message );
    $c->stash->{template} = 'default.tt';
    $c->forward('Kinetic::UI::Catalyst::V::TT');
}

#
# Uncomment and modify this end action after adding a View component
#
#=head2 end
#
#=cut
#
#sub end : Private {
#    my ( $self, $c ) = @_;
#
#    # Forward to View unless response body is already defined
#    $c->forward( $c->view('') ) unless $c->response->body;
#}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
