package Kinetic::UI::Email::Workflow;

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

use Kinetic::UI::Email::Workflow::Lexer qw/lex/;
use Kinetic::UI::Email::Workflow::Parser qw/parse/;

=head1 Name

Kinetic::UI::Email::Workflow - The workflow email UI

=head1 Synopsis

 my $wf = Kinetic::UI::Email::Workflow->new( {
     key_name => $workflow,
     job      => $job,
     user     => $user,
     org      => $organization,
 } );
 # or 
 my $wf = Kinetic::UI::Email::Workflow->new($from, $to);
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
     key_name => $workflow,
     job      => $job,
     user     => $user,
     org      => $organization,
 } );
 # or 
 my $wf = Kinetic::UI::Email::Workflow->new($from, $to);

Creates and returns a new workflow email UI object.

If supplied an email address instead of a hashref of components, the
constructor will return false if the email address doesn't match:

 $job+$workflow@$organization.$host

=cut

sub new {
    my $class = shift;
    my $self  = $class->_init(@_);
    return bless $self, $class;
}

sub _init {
    my ( $class, @args ) = @_;
    my $hash;
    if ( 'HASH' eq ref $args[0] ) {
        $hash = shift @args;
    }
    else {
        my ( $from, $to ) = @args;
        my $info = $class->_break_down_address($to) || return;
        $hash = {
            job      => $info->[0],
            key_name => $info->[1],
            org      => $info->[2],
            user     => $from
        };
    }
    my @keys = qw/job key_name org user/;
    my @errors;
    foreach my $key (@keys) {
        push @errors, $key unless exists $hash->{$key};
    }
    die "Missing keys (@errors)" if @errors;
    return $hash;
}

##############################################################################

=head3 host

  my $host = Kinetic::UI::Email::Workflow->host;

Returns the host of the Workflow site.

=cut

# XXX temporary
sub host {'workflow.com'}

sub _break_down_address {
    my ( $class, $address ) = @_;
    my $host = $class->host;

    # $job+$workflow@$org.$host
    if ($address =~ m{\A
            ([^\+]+)                    # job
            \+
            ([^@]+)                     # workflow
            \@
            ([^\.]+)                    # organization
            \.
            \Q$host\E
        \z}x
      )
    {
        return [ $1, $2, $3 ];
    }
    return;
}

##############################################################################

=head3 C<is_workflow_address>

  if (Kinetic::UI::Email::Workflow->is_workflow_address($address)) {
    ...
  }

This class method, when called with a string as the argument, will return true
if the string is a valid Workflow email address.

=cut

sub is_workflow_address {
    my ( $class, $address ) = @_;

    # $job+$workflow@$org.$host
    return $class->_break_down_address($address);
}

##############################################################################

=head3 workflow

 my $current_wf = $wf->workflow;

Returns the current workflow keyname.

=head3 job

 my $job = $wf->job;

Returns the current job for this workflow.

=head3 user

 my $user = $wf->user;

Returns the user for the current workflow stage.

=head3 org

 my $org = $wf->org;

Returns the organization which owns the current workflow.

=cut

sub workflow { shift->{key_name} }
sub job      { shift->{job} }
sub user     { shift->{user} }
sub org      { shift->{org} }

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

            my ( $process, $action, $stage, $note ) = @$command;

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
