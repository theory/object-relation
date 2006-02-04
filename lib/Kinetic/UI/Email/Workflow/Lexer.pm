package Kinetic::UI::Email::Workflow::Lexer;

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
use HOP::Lexer 'string_lexer';
use Exporter::Tidy lex => ['lex'];

use version;
our $VERSION = version->new('0.0.1');

sub _trim($) {
    if (! defined wantarray) {
        $_[0] =~ s/\A\s+//;
        $_[0] =~ s/\s+\z//;
        return;
    }
    my $value = shift;
    $value =~ s/\A\s+//;
    $value =~ s/\s+\z//;
    return $value;
}

my $_stage = sub {
    my ( $label, $value ) = @_;
    $value =~ s/\A{//;
    $value =~ s/}\z//;
    return [ $label, _trim $value ];
};

my $_completed = sub {
    my ( $label, $value ) = @_;
    $value =~ s/\A\[//;
    $value =~ s/\]\z//;
    return [ $label, ( _trim $value ? 1 : 0 ) ];
};

my $_action = sub {
    my ( $label, $value ) = @_;
    return [ $label, lc _trim $value ];
};

my $note_separator = qr/={5,}/;
my $_note = sub {
    my ( $label, $value ) = @_;
    $value =~ s/\A$note_separator//;
    $value =~ s/$note_separator\z//;
    $value = _strip_email_quotes($value);
    _trim $value;
    return unless $value;
    return [ $label, $value ];
};

{

    # We suppress the uninit warnings becuase the BEGIN block needs the token
    # labels, but the other values are not yet defined.  That's OK because it
    # doesn't need those other values.
    no warnings 'uninitialized';

    sub _tokens {
        [ NOTE    => qr/$note_separator.+?$note_separator/s, $_note ],
        [ STAGE   => qr/{[^}]+}/,                            $_stage ],
        [ PERFORM => qr/\[[[:print:]]+?\]/,                  $_completed ],
        [ ACTION  => qr/[[:word:]]+[ \t[:word:]]*/,          $_action ], # no newlines
        [ SPACE   => qr/[[:space:]]+/,                       sub { } ];
    }
}

BEGIN {

    # This creates subs for things like "_is_note($token)", which is merely a
    # helper subroutine which identifies a token type.
    foreach my $type ( map { $_->[0] } _tokens() ) {
        my $sub = "_is_" . lc $type;
        no strict 'refs';
        *$sub = sub {
            my $token = shift;
            return ref $token && $type eq $token->[0];
        };
    }
}

=head1 Name

Kinetic::UI::Email::Workflow::Lexer - The Workflow email lexer

=head1 Synopsis

 use Kinetic::UI::Email::Workflow::Lexer qw/lex/;
 my $tokens = lex($email_body);

=head1 Description

This module is for lexing the Kinetic Workflow app data into tokens which
L<Kinetic::UI::Email::Workflow::Parser|Kinetic::UI::Emai::Workflow::Parser>
can understand.

=head1 Interface

=head2 Exportable Functions

=head3 C<lex>

  my $token = lex($text);

Given the email body text, this subroutine returns tokens suitable for the
parser to parse.

=cut


# Craftily lifted from Text::AutoFormat
my $quotechar     = qq{[!#%=|:]};
my $quotechunk    = qq{(?:$quotechar(?![a-z])|(?:[a-z]\\w*)?>+)};
my $quoter        = qq{(?:(?i)(?:$quotechunk(?:[ \\t]*$quotechunk)*))};
my $leading_quote = qr/\A([ \t]*)($quoter?)([ \t]*)/;

sub _strip_email_quotes {
    my $data = shift;
    my @lines = split /\n/, $data;
    foreach (@lines) {

        # this line allows the "note" separator (==========) to remain intact.
        next if /$leading_quote$note_separator\s*\z/;
        s/$leading_quote//;
    }
    return join "\n", @lines;
}

sub lex {
    my ( $text ) = @_;
    $text = _strip_email_quotes($text);

    my $lexer = string_lexer( $text, _tokens() );
    my @result;
    while ( my $token = $lexer->() ) {

        # XXX the following line discards any data we cannot lex.  This allows
        # us to ignore the the "autoquote" stuff in email or superfluous
        # sentenctes.
        #
        #   > [x] {Assign Writer}
        #
        # XXX create a [ JUNK => $data ] token?
        next unless ref $token;
        if ( _is_action($token) ) {
            next if !@result || @result && !_is_perform( $result[-1] );
        }
        push @result => $token;

        # [ ] {Some Stage} implicitly becomes:
        # [ ] Complete {Some Stage}
        # This makes parsing simpler by forcing a standard token series:
        #   PERFORM, ACTION, STAGE
        if ( _is_perform($token) ) {
            my $next_token = $lexer->('peek');
            next unless ref $next_token;
            push @result => [ ACTION => 'complete' ]
              if _is_stage($next_token);
        }
    }
    return \@result;
}

1;
__END__

=head1 Email Format

The email format for the Workflow application is fairly straightforward.
There are several items which the lexer can recognize and turn into tokens.
All text which is not recognized is discarded.

Each "job" representing an instance of a workflow is divided into "stages" or
"tasks".
A stage in a job might look like this in email:

 [ ] {Write Story}

All stages will have curly brackets around them, thus, stage names cannot have
curly brackets in them.

For someone to mark this stage as "complete", they merely need to type some
printable, non-whitespace character in the box.  Extraneous whitespace does
not matter and all of the following are equivalent:

 [ x ] {Write Story}
 [X]      { Write Story }
 [.]      {Write Story}
 [ done ] {Write Story}

The lexer will recognize that this is a completed stage.

Some stages might have particular actions associated with them, such as
"return".  This would occur if a person assigned a task does not wish to
accept it (for example, if they'll be out of the office or it was assigned to
them in error).  All emails should have a "return" action available:

 [ ] Return {Write Story}

If that box is "checked", the task is not accepted and should be returned to
the person assigning the task.

Other commands not associated with stages are:

 [ ] Verbose email
 [ ] Compact email
 [ ] Help

The first two commands are mutually exclusive.  These commands toggle the
user's preference for very descriptive emails or brief emails.  The "Help"
command should trigger a one-time email to the user explaining how to use the
Workflow email system.

After commands associated with stages, any sections delimited with five or
more "equals" signs (C<=====>) will be notes attached to that command.  Empty
notes will not be included in the lexed stream of tokens.  Any note will be
associated with the previous command.

=head1 Example

Assuming that an editor has assigned a "Write Story" task to a potential
writer, a compact email similar to the following might be sent out:

 To:       oo_blunders+new_story@example.workflow.com
 CC:
 From:     bob@example.com
 Date:     Wed, 1 Feb 2006 14:55:05 -0500
 Subject:  Write Story "Object Oriented Blunders"
 
 You've been assigned "Write Story".  This task is due on Tuesday, February
 14, 2005.
 
 [ ] {Write Story}
 
 Notes:
 ==========================================
 
 
 ==========================================
 
 [ ] Return {Write Story}
 
 Reason for Return:
 ==========================================
 
 
 ==========================================
 
 [ ] Verbose email
 
 [ ] Help

Assuming that the writer who receives the story does not wish to accept it,
she might reply as follows:

 > To:       oo_blunders+new_story@example.workflow.com
 > CC:
 > From:     alice@example.com
 > Date:     Wed, 1 Feb 2006 14:55:05 -0500
 > Subject:  Write Story "Object Oriented Blunders"
 > 
 > You've been assigned "Write Story".  This task is due on Tuesday, February
 > 14, 2005.
 > 
 > [ ] {Write Story}
 > 
 > Notes:
 > ==========================================
 > 
 > 
 > ==========================================
 > 
 > [X ] Return {Write Story}
 > 
 > Reason for Return:
 > ==========================================
 > Charlie was supposed to write this, not I.
 > 
 > ==========================================
 > 
 > If you would like more verbose emails, please check the box below:
 > 
 > [ ] Verbose email
 > 
 > [ ] Help

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
