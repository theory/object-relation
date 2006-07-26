package TEST::Object::Traits::HTML;

use Class::Trait 'base';

our @REQUIRES = qw(desired_attributes);

use strict;
use warnings;
use HTML::Entities qw(encode_entities);

##############################################################################

=head1 Provided methods

=head2 Instance methods

The following methods are are methods related to the production of HTML
documents.

Requires:

=over 4

=item * desired_attributes

=back

=cut

##############################################################################

=head3 domain

 my $domain = $test->domain;
 $test->domain($domain);

Getter/setter for test domain.  Domain in this context is actually the base
URL (without the base path).  For example:

 http://www.example.com/      # good
 http://www.example.com/rest/ # bad

Currently no validation is performed.

A trailing slash "C</>" will be added if not supplied.

=cut

sub domain {
    my $test = shift;
    return $test->{domain} unless @_;
    my $domain = shift;
    $domain .= '/' unless $domain =~ m{/$};
    $test->{domain} = $domain;
    return $test;
}

##############################################################################

=head3 path

 my $path = $test->path;
 $test->path($path);

Getter/setter for test path.  Path in this context is actually the base
path (without the domain).  For example:

 rest/                        # good
 http://www.example.com/rest/ # bad

Currently no validation is performed.

A trailing slash "C</>" will be added if not supplied and if the path is
not the empty string or undefined.  A leading slash will be stripped.

The path will be set to the empty string if set with an undefined value.

=cut

sub path {
    my $test = shift;
    return $test->{path} unless @_;
    if ( defined( my $path = shift ) ) {
        $path .= '/' if $path && $path !~ m{/$};
        $path =~ s{^/}{}g;
        $test->{path} = $path;
    }
    else {
        $test->{path} = '';
    }
    return $test;
}

##############################################################################

=head3 query_string

  my $query_string = $test->query_string;
  $test->query_string('foo=bar');

This is the getter/setter for query strings.  An undefined query string will
set the query string to the empty string.

A defined query string will add a question mark to the beginning of a query
string if it does not exist.

=cut

sub query_string {
    my $test = shift;
    return $test->{query_string} || '' unless @_;
    if ( defined( my $query_string = shift ) ) {
        $query_string =~ s{^(?=[^?])}{?}g;
        $test->{query_string} = $query_string;
    }
    else {
        $test->{query_string} = '';
    }
    return $test;
}

##############################################################################

=head3 url

  my $url = $test->url;

Returns the full URL for the test (C<$domain.$path>).

Will croak if the domain has not been set.

=cut

sub url {
    my $test = shift;
    unless ( defined $test->domain ) {
        require Carp;
        Carp::croak("Test domain not set.  Cannot create url");
    }
    return $test->domain . $test->path;
}

1;
