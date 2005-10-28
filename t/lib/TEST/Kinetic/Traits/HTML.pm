package TEST::Kinetic::Traits::HTML;

#use Class::Trait 'base';
# requires desired_attributes()

use strict;
use warnings;
use Array::AsHash;
use HTML::Entities qw/encode_entities/;
use Kinetic::Util::Constants qw/:rest/;    # form params

# note that the following is a stop-gap measure until Class::Trait has
# a couple of bugs fixed.  Bugs have been reported back to the author.
#
# Traits would be useful here as the REST and REST::Dispatch classes are
# coupled, but not by inheritance.  The tests need to share functionality
# but since inheritance is not an option, I will be importing these methods
# directly into the required namespaces.

use Exporter::Tidy default => [
    qw/
      domain
      footer_html
      header_html
      instance_table
      normalize_search_args
      path
      query_string
      resource_list_html
      search_form
      url
      /
];

##############################################################################

=head1 Available methods

=head2 Instance methods

The following methods are are methods related to the production of HTML
documents.

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

##############################################################################

=head3 header_html

  my $header = $test->html_header($title);

Returns the top portion of an HTML document generated by XSLT, up to and
including the body tag.

=cut

sub header_html {
    my ( $test, $title ) = @_;
    my $html = <<"    END_HTML";
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
    <link rel="stylesheet" href="/css/rest.css"/>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>$title</title>
    END_HTML

    if ( $title =~ /instances/ ) {
        $html .= <<"        END_HTML";
    <script language="JavaScript1.2" type="text/javascript" src="/js/Kinetic/Search.js"></script>
  </head>
  <body onload="document.search_form.search.focus()">
        END_HTML
    }
    else {
        $html .= <<"        END_HTML";
  </head>
  <body>
        END_HTML
    }
    return $html;
}

sub footer_html {
    my $test = shift;
    return <<'    END_HTML';
  </body>
</html>
    END_HTML
}

##############################################################################

=head3 normalize_search_args

  $args = $test->normalize_search_args($args);

This method, taking an C<Array::AsHash> object, will clone the object and set
the args in the method expected by the REST dispatch class for searches.

=cut

sub normalize_search_args {
    my ( $test, $args ) = @_;
    $args = defined $args ? $args->clone : Array::AsHash->new;
    $args->default( SEARCH_TYPE, '', LIMIT_PARAM, 20, OFFSET_PARAM, 0, );
    if ( $args->exists(ORDER_BY_PARAM) ) {
        $args->default( SORT_PARAM, 'ASC' );
    }
    $args = Array::AsHash->new(
        {
            array => [
                $args->get_pairs( SEARCH_TYPE, LIMIT_PARAM,
                    OFFSET_PARAM, ORDER_BY_PARAM,
                    SORT_PARAM
                )
            ]
        }
    );
    return $args;
}

##############################################################################

=head3 search_form

  my $form = $test->search_form( $class_key, $args );

This method returns the HTML form generated by the XSLT.  C<$args> is the
normal C<Array::AsHash> object which is passed to the REST dispatch class.

=cut

sub search_form {
    my ( $test, $key, $args ) = @_;
    $key ||= 'one';
    $args = $test->normalize_search_args($args);

    my $order_options = '';
    my @options = map { [ $_ => ucfirst $_ ] } $test->desired_attributes;
    $args->default( ORDER_BY_PARAM, '' );
    foreach my $option (@options) {
        my $selected =
          $args->get(ORDER_BY_PARAM) eq $option->[0] ? ' selected="selected"' : '';
        $order_options .=
          qq{<option value="$option->[0]"$selected>$option->[1]</option>};
    }
    my $sort_options = '';
    $args->default( SORT_PARAM, 'ASC' );
    foreach my $order ( [ ASC => 'Ascending' ], [ DESC => 'Descending' ] ) {
        my $selected =
          $args->get(SORT_PARAM) eq $order->[0] ? ' selected="selected"' : '';
        $sort_options .=
          qq{<option value="$order->[0]"$selected>$order->[1]</option>};
    }
    my $search = encode_entities( $args->get(SEARCH_TYPE) );
    my $limit  = $args->get(LIMIT_PARAM);
    my $domain = $test->domain;
    my $path   = $test->path;
    my $query  = $test->query_string;
    my ($type) = $query =~ /@{[TYPE_PARAM]}=([[:word:]]+)/;
    $type ||= '';
    return <<"    END_FORM";
    <div class="search">
      <form action="/$path" method="get" name="search_form" onsubmit="doSearch(this); return false" id="search_form">
        <input type="hidden" name="@{[CLASS_KEY_PARAM]}" value="$key" />
        <input type="hidden" name="@{[DOMAIN_PARAM]}" value="$domain" />
        <input type="hidden" name="@{[PATH_PARAM]}" value="$path" />
        <input type="hidden" name="@{[TYPE_PARAM]}" value="$type" />
        <table>
          <tr>
            <td class="header">search:</td>
            <td>
              <input type="text" name="search" value="$search" />
            </td>
          </tr>
          <tr>
            <td class="header">limit:</td>
            <td>
              <input type="text" name="_limit" value="$limit" />
            </td>
          </tr>
          <tr>
            <td class="header">order by:</td>
            <td>
              <select name="_order_by">
                $order_options
              </select>
            </td>
          </tr>
          <tr>
            <td class="header">sort order:</td>
            <td>
              <select name="_sort_order">
                $sort_options
              </select>
            </td>
          </tr>
          <tr>
            <td colspan="4">
              <input type="submit" value="Search"/>
            </td>
          </tr>
        </table>
      </form>
    </div>
    END_FORM
}

##############################################################################

=head3 instance_table

  my $table = $test->instance_table({
    key     => $class_key,   # optional
    args    => $args,        # Array::AsHash (optional)
    objects => \@objects,    # required
  });

This method returns the instance table identical to that which the XSLT
generates.  The first argument should be an C<Array::AsHash> object and
the subsequent arguments should be C<Kinetic> objects.

Assumes C<query_string>, C<url> and C<desired_attributes> are set.

=cut

sub instance_table {
    my ( $test, $arg_for ) = @_;
    my $url        = $test->url;
    my $query      = $test->query_string;
    my @attributes = $test->desired_attributes;

    my $args      = $test->normalize_search_args( $arg_for->{args} );
    my $class_key = $arg_for->{key} || 'one';

    my $table = '<div class="listing"><table><tr>';
    foreach my $attr (@attributes) {
        my $url = $test->get_sort_url( $class_key, $args, $attr );
        $table .= qq{<th class="header"><a href="$url">$attr</a></th>};
    }
    $table .= '</tr>';
    my $odd_even = 0;
    foreach my $object ( @{ $arg_for->{objects} } ) {
        my $uuid = $object->uuid;
        $odd_even = !$odd_even || 0;    # creating alternating row colors
        $table .= qq{<tr class="row_$odd_even">};
        foreach my $attr (@attributes) {
            my $value = ( $object->$attr || '' );
            $table .= <<"            END_ATTR";
    <td>
    <a href="$url$class_key/lookup/uuid/$uuid$query">$value</a>
    </td>
            END_ATTR
        }
        $table .= '</tr>';
    }
    $table .= '</table></div>';
    return $table;
}

##############################################################################

=head3 resource_list_html

 my $resource_list_html = $test->resource_list_html;

This method will return the current resource list for an HTML document.

Assumes C<query_string> and C<url> are set.

=cut

sub resource_list_html {
    my ($test) = shift;
    my $base_url  = $test->url;
    my $query     = $test->query_string;
    my $resources = '<div id="sidebar"><ul>';
    foreach my $key ( sort Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        $resources .=
          qq'<li><a href="${base_url}$key/search$query">$key</a></li>\n';
    }
    $resources .= '</ul></div>';
    return $resources;
}
1;
