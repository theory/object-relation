package TEST::Kinetic::Traits::HTML;

#use Class::Trait 'base';

use strict;
use warnings;

# note that the following is a stop-gap measure until Class::Trait has
# a couple of bugs fixed.  Bugs have been reported back to the author.
#
# Traits would be useful here as the REST and REST::Dispatch classes are
# coupled, but not by inheritance.  The tests need to share functionality
# but since inheritance is not an option, I will be importing these methods
# directly into the required namespaces.

use Exporter::Tidy default => [ qw/ 
    domain
    instance_table
    path
    search_form
/ ];

sub domain {
    my $test = shift;
    return $test->{domain} unless @_;
    my $domain = shift;
    $domain .= '/' unless $domain =~ m{/$};
    $test->{domain} = $domain;
    return $test;
}

sub path {
    my $test = shift;
    return $test->{path} unless @_;
    my $path = shift;
    $path .= '/' if $path && $path !~ m{/$};
    $test->{path} = $path;
    return $test;
}

sub search_form {
    my ( $test, $class_key, $search, $limit, $order_by ) = @_;
    my $domain = $test->domain;
    my $path   = $test->path;
    return <<"    END_FORM";
    <form method="get" name="search_form" onsubmit="javascript:do_search(this); return false" id="search_form">
      <input type="hidden" name="class_key" value="$class_key" />
      <input type="hidden" name="domain" value="$domain" />
      <input type="hidden" name="path" value="$path" />
      <table>
        <tr>
          <td>Search:</td>
          <td>
            <input type="text" name="search" value="$search" />
          </td>
        </tr>
        <tr>
          <td>Limit:</td>
          <td>
            <input type="text" name="limit" value="$limit" />
          </td>
        </tr>
        <tr>
          <td>Order by:</td>
          <td>
            <input type="text" name="order_by" value="$order_by" />
          </td>
        </tr>
        <tr>
          <td>Sort order:</td>
          <td>
            <select name="sort_order">
              <option value="ASC">Ascending</option>
              <option value="DESC">Descending</option>
            </select>
          </td>
        </tr>
        <tr>
          <td colspan="2">
            <input type="submit" value="Search" onclick="javascript:do_search(this)" />
          </td>
        </tr>
      </table>
    </form>
    END_FORM
}

sub instance_table {
    my ($test, $query,  @objects) = @_;
    my $url = $test->domain.$test->path;
    $query = "?$query" if $query;
    my $table = '<table bgcolor="#eeeeee" border="1"><tr>';
    my @attributes = $test->desired_attributes;
    foreach my $attr (@attributes) {
        $table .= "<th>$attr</th>";
    }
    $table .= '</tr>';
    foreach my $object (@objects) {
        my $uuid = $object->uuid;
        $table .= '<tr>';
        foreach my $attr (@attributes) {
            my $value = ($object->$attr||'');
            $table .= <<"            END_ATTR";
    <td>
    <a href="${url}one/lookup/uuid/$uuid$query">$value</a>
    </td>
            END_ATTR
        }
        $table .= '</tr>';
    }
    $table .= '</table>';
    return $table;
}

1;
