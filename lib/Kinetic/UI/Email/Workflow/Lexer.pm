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

use version;
our $VERSION = version->new('0.0.1');

sub _trim {
    my $value = shift;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

my $_stage = sub {
    my ( $label, $value ) = @_;
    $value =~ s/^{//;
    $value =~ s/}$//;
    $value = _trim($value);
    return [ $label, $value ];
};

my $_completed = sub {
    my ( $label, $value ) = @_;
    $value =~ s/^\[//;
    $value =~ s/\]$//;
    $value = _trim($value);
    return [ $label, ( $value ? 1 : 0 ) ];
};

my $_action = sub {
    my ( $label, $value ) = @_;
    return [ $label, lc _trim($value) ];
};

# XXX Right now this is very naive, but we'll keep tweaking as we go along.

my @TOKENS = (
    [ STAGE   => qr/{[^}]+}/,                         $_stage ],
    [ PERFORM => qr/\[\s*[[:print:]]+\s*\]/,          $_completed ],
    [ ACTION  => qr/[[:word:]]+[[:space:][:word:]]*/, $_action ],
    [ SPACE   => qr/\s+/,                             sub { } ],
);

=head1 Name

Kinetic::UI::Email::Workflow::Lexer - The workflow email lexers

=head1 Synopsis

 my $lexer = Kinetic::UI::Email::Workflow::Lexer->new;
 $lexer->lex($email_body);

=head1 Description

This class is for lexing the Kinetic Workflow app data into tokens which
L<Kinetic::UI::Email::Workflow::Parser|Kinetic::UI::Emai::Workflow::Parser>
can understand.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

 my $lexer = Kinetic::UI::Email::Workflow::Lexer->new;

Creates and returns a new lexer object.

=cut

sub new {
    my ($class) = @_;
    bless {}, $class;
}

##############################################################################

=head2 Instance interface

=head3 lex

  my $token = $lexer->lex($text);

Given the email body text, this methods returns the tokens suitable for the
parser to parse.

=cut

sub lex {
    my ( $self, $text ) = @_;
    my @result;
    my $lexer = string_lexer( $text, @TOKENS );
    while ( my $token = $lexer->() ) {

        # XXX the following line discards any data we cannot lex.  This allows
        # us to ignore the "autoquote" stuff in email:
        # > [x] {Assign Writer}
        # However, this may prove problematic for those folks whose email
        # clients use strange autoquote characters.  We may have to revisit
        # this.
        # XXX create a [ JUNK => $data ] token?
        next unless ref $token;
        if ( _is_action($token) ) {
            next if ! @result || @result && ! _is_perform( $result[-1] );
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

BEGIN {
    foreach my $type (qw/PERFORM ACTION STAGE/) {
        my $sub = "_is_" . lc $type;
        no strict 'refs';
        *$sub = sub {
            my $token = shift;
            return ref $token && $type eq $token->[0];
        };
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
