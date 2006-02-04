package Kinetic::UI::Email::Workflow;

# $Id: Kinetic.pm 2542 2006-01-19 01:38:21Z curtis $

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

use Kinetic::UI::Email::Workflow::Lexer qw/lex/;
use Kinetic::UI::Email::Workflow::Parser qw/parse/;

=head1 Name

Kinetic::UI::Email::Workflow - The workflow email UI

=head1 Synopsis

 my $wf = Kinetic::UI::Email::Workflow->new( {
     workflow => $workflow,
     job      => $job,
     user     => $user,
 } );
 $wf->handle($email_body);

=head1 Description

XXX

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

 my $wf = Kinetic::UI::Email::Workflow->new( {
     workflow => $workflow,
     job      => $job,
     user     => $user,
 } );

Creates and returns a new workflow email UI object.

=cut

sub new {
    my ( $class, $args ) = @_;
    bless $args, $class;
}

##############################################################################

=head3 workflow

 my $current_wf = $wf->workflow;

Returns the current workflow.

=head3 job

 my $job = $wf->job;

Returns the current job for this workflow.

=head3 user

 my $user = $wf->user;

Returns the user for the current workflow stage.

=cut

sub workflow { shift->{workflow} }
sub job      { shift->{job} }
sub user     { shift->{user} }

##############################################################################

=head3 handle

  $wf->handle($email_body);

Given the body of the email, this method parses the workflow commands from the
body and attempts to execute the correct actions.

=cut

# should probably have a human readable error message, too
sub handle {
    my ( $self, $body ) = @_;
    my $commands = parse( lex($body) );
    if (@$commands) {
        foreach my $command (@$commands) {

            # do something
        }
        return 1;
    }
    else {

        # we couldn't parse any commands.  Let 'em know that
        return;
    }
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
