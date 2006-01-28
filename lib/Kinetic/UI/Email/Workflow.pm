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
use HOP::Lexer 'string_lexer';

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::UI::Email::Workflow - The workflow email UI

=head1 Synopsis

 my $lexer = Kinetic::UI::Email::Workflow->new;
 XXX ...

=head1 Description

XXX

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

 my $lexer = Kinetic::UI::Email::Workflow->new;

Creates and returns a new workflow email UI object.

=cut

sub new {
    my ($class) = @_;
    bless {}, $class;
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
