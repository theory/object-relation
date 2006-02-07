package Kinetic::UI::Email::Workflow::Qpsmtpd;

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

use Class::Trait 'base';

use POSIX qw/strftime/;
use Qpsmtpd::Constants;
use aliased 'Qpsmtpd::Address';
use aliased 'Kinetic::UI::Email::Workflow';

=head1 Name

check_workflow - Qpsmtpd plugin for handling Workflow email.

=head1 Synopsis

See the incredible lack of documentation at L<http://smtpd.develooper.com/>.
For more fun, check the "let's assume you know more than Ovid does" article at
L<http://www.oreillynet.com/pub/a/sysadmin/2005/09/15/qpsmtpd.html>.

=head1 Description

This C<qpstmpd> plugin checks email to see if it's a workflow email.  If it
does, it takes appropriate action and discards the email.  Otherwise, it
declines to handle the email, allowing the rest of the C<qpstmpd> plugins to
handle it.

This plugin should be used I<before> spam plugins to avoid legitimate
workflow email getting flagged as spam.  Alternatively, in case you start
receiving spam to workflow email addresses, you'll have to tweak your spam
tools to handle this.

In actuality, this plugin is implemented as a trait to allow the methods to be
shoved in a class and be easy to test, but still allow the qpstmpd plugin
model to be used.  The plugin then looks like this:

 use Class::Trait 'Kinetic::UI::Email::Workflow::Qpsmtpd';

=head1 Methods

=head2 C<qpstmpd> methods

The following methods are called by C<qpstmpd>, not internally.

=head3 C<hook_data_post>

  $self->hook_data_post($transaction);

When Qpsmtpd intercepts email, it calls this method.  C<hook_data_post> will
check to see if this is a workflow email.  If so, it will XXX (fill this in
later).  Otherwise, it merely returned "DECLINED" and allows subsequent
plugins (if any) to handle the email.

=cut

sub hook_data_post {
    my ( $self, $transaction, $from ) = @_;

    if ( my $to = $self->_for_workflow($transaction) ) {

        # don't log email unless it's workflow email
        $self->_log_email($transaction);

        my $wf = Workflow->new( $from, $to );
        if ( $wf->handle( $self->_get_body($transaction) ) ) {

            # we had commands to execute
            # Probably want to send a confirmation email.
        }
        else {

            # no commands were executed
            # Probably need to return a message to the user asking for
            # clarification.
        }

        # XXX This still isn't right.  DONE appears to cause things to hang.
        # I'll have to research this more before I send a message to the list.
        return ( DONE, "successfully saved message.. continuing" );
    }
    else {
        return ( DECLINED, "successfully saved message.. continuing" );
    }
}

##############################################################################

=head2 Internal methods

The following methods are called internally, not by qpsmtpd.

=head3 C<_for_workflow>

  if (my $address = $self->_for_workflow($address)) {
      ...
  }


=cut

sub _for_workflow {
    my ( $self, $transaction ) = @_;

    # XXX what if more than on wf address is found?
    foreach my $recipient ( $transaction->recipients ) {
        return $recipient->address
          if Workflow->is_workflow_address( $recipient->address );
    }
    return;
}

##############################################################################

=head3 C<_log_email>

  $self->_log_email($transaction);

This method takes the current email and logs its to the mail/ directory
(relative to current working directory).  We'll likely change this in the
future.

=cut

sub _log_email {
    my ( $self, $transaction ) = @_;

    # as a decent default, log on a per-day-basis
    my $date = strftime( "%Y%m%d", localtime(time) );
    open my $out, ">>mail/$date"
      or return ( DECLINED, "Could not open log file.. continuing anyway" );

    $transaction->header->print($out);
    print $out $self->_get_body($transaction);
    close $out;
}

{
    my $body = '';

    sub _get_body {
        my ( $self, $transaction ) = @_;
        return $body if $body;
        $transaction->body_resetpos;
        while ( defined( my $line = $transaction->body_getline ) ) {
            $body .= $line;
        }
        return $body;
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
