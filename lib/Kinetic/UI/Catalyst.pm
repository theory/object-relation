package Kinetic::UI::Catalyst;

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
use warnings;

use Cwd;
use Kinetic::Meta;
use Kinetic::Util::Config qw(:kinetic :cache);
use aliased 'Kinetic::UI::Catalyst::Log';
use Kinetic::UI::Catalyst::Cache;
use Kinetic::Util::Functions qw(:class);
use Kinetic::Util::Exceptions qw(:all);
use File::Spec::Functions ();

use version;
our $VERSION = version->new('0.0.1');

BEGIN {
    load_classes(
        File::Spec::Functions::catdir( KINETIC_ROOT, 'lib' ),
        qr/Kinetic.(?:Build|DataType|Engine|Format|Meta|Store|UI|Util|Version)/
    );
}

#
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
# Static::Simple: will serve static files from the applications root directory
#
use Catalyst
    '-Home=' . KINETIC_ROOT, # XXX Might actually work in the future.
#    ($ENV{HARNESS_ACTIVE} ? '-Debug' : ()),
    CACHE_CATALYST_CLASS->session_class,
    qw(
        Authentication
        Authentication::Store::Minimal
        Authentication::Credential::Password
        Session
        Session::State::Cookie
        Static::Simple
    );

# This *must* come first so that home is set for everything else.
__PACKAGE__->config({
    home => KINETIC_ROOT,
});

__PACKAGE__->config({
    name    => 'Kinetic Catalyst Interface',
    root    => __PACKAGE__->path_to(qw/www root/),
    classes => [
        grep { !$_->abstract }
        map  { Kinetic::Meta->for_key($_) }
        sort Kinetic::Meta->keys
    ],
    'V::TT' => {
        INCLUDE_PATH => __PACKAGE__->path_to(qw/www views tt/),
        PLUGIN_BASE  => 'Kinetic::UI::TT::Plugin',
    },
    authentication => {
        users => {
            ovid   => { password => 'divo' },
            theory => { password => 'theory' }
        }
    },
    CACHE_CATALYST_CLASS->config,
});

__PACKAGE__->log(Log->new);
__PACKAGE__->setup;

##############################################################################

=head1 Name

Kinetic::UI::Catalyst - Catalyst UI for Kinetic Platform

=head1 Synopsis

  bin/kineticd start

=head1 Description

Catalyst based application.

=head1 Methods

=head2 begin

This is the default start action for all Catalyst actions.  It checks to see
if we have an authenticated user and, if not, forwards them to the login page.

See L<Kinetic::UI::Catalyst::C::Login|Kinetic::UI::Catalyst::C::Login> for
more information.

=cut

sub begin : Private {
    my ( $self, $c ) = @_;

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

##############################################################################

=head2 default


Outputs a friendly welcome message.

=cut

sub default : Private {
    my ( $self, $c ) = @_;

    # Hello World
    #$c->response->body( $c->welcome_message );
    $c->stash->{template} = 'default.tt';
    $c->forward('Kinetic::UI::Catalyst::V::TT');
}

1;
__END__

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
