#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;

use Kinetic::Build::Test;
use Test::More tests => 29;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.

use Test::Exception;
use Test::XML;

my $RENDERER;

BEGIN {
    use lib 'lib';
    $RENDERER = 'Kinetic::UI::TT::Plugin::Renderer';
    use_ok $RENDERER or die;
}

BEGIN {

    package Test::Language::en;
    use Kinetic::Util::Language::en;
    Kinetic::Util::Language::en->add_to_lexicon(
        map { $_ => $_ } (
            'Calendar',
            'Check tip',
            'Checkbox',
            'Foo',
            'Select a date',
            'Select one',
            'Select something',
            'Text area',
            'Thanks for the tip',
            'foo tip',
        )
    );

    package Some::Package;

    use Kinetic::Meta::Declare ':all';
    use aliased 'Kinetic::Meta::Widget';

    Kinetic::Meta::Declare->new(
        meta => [
            key         => 'some_package',
            plural_name => 'Some packages',
        ],
        attributes => [
            foo => {
                label       => 'Foo',
                widget_meta => Widget->new(
                    type => 'text',
                    tip  => 'foo tip',
                ),
            },
            check => {
                label       => 'Checkbox',
                type        => $TYPE_BOOL,
                widget_meta => Widget->new(
                    type    => 'checkbox',
                    checked => 1,
                    tip     => 'Check tip',
                ),
            },
            some_text_area => {
                label       => 'Text area',
                widget_meta => Widget->new(
                    type => 'textarea',
                    rows => 6,
                    cols => 20,
                    tip  => 'Thanks for the tip',
                ),
            },
            cal => {
                label       => "Calendar",
                widget_meta => Widget->new(
                    type => 'calendar',
                    tip  => "Select a date",
                )
            },
            select => {
                label       => "Select one",
                widget_meta => Widget->new(
                    type    => 'dropdown',
                    tip     => 'Select something',
                    options => [ [ 0 => 'Zero' ], [ 1 => 'One' ], ]
                )
            }
        ]
    );
}

sub wrap {
    my $text = shift;
    return "<html>$text</html>";
}

my $object = Some::Package->new(
    foo            => 'foo this, baby',
    check          => 1,
    some_text_area => 'text, text, baby',
    cal            => '2005-03-12T00:00:00',
    select         => 1,
);

#
# XXX Note the unusual way of calling the constructor.  Because a TT plugin's
# constructor has "context" passed after the class and the subsequent
# arguments are passed has a hashref, we pass "undef" for the context (the
# code is not relying on it) and this constructor is equilant to:
#
# [% USE Renderer( mode => 'edit', format => {} ) %]
#

can_ok $RENDERER, 'new';
ok my $r = $RENDERER->new( undef, { mode => 'view' } ),  # format has defaults
  '... and we should be able to create a new renderer';
isa_ok $r, $RENDERER, '... and the object it returns';

can_ok $r, 'mode';
throws_ok { $r->mode('foo') } 'Kinetic::Util::Exception::Fatal::Invalid',
  '... and attempting to set it to an illegal value should fail';

my $meta_class = $object->my_class;
my %attr_for   = map { $_->name => $_ } $meta_class->attributes;

can_ok $r, 'render';

is $r->render( $attr_for{foo}, $object ), 'Foo '.$object->foo,
  '"text" rendering in "view" mode should return the value';
is $r->render( $attr_for{check}, $object ),'Checkbox '. $object->check,
  '"checkbox" rendering in "view" mode should return the value';
is $r->render( $attr_for{some_text_area}, $object ), 'Text area '.$object->some_text_area,
  '"textarea" rendering in "view" mode should return the value';
is $r->render( $attr_for{cal}, $object ), 'Calendar '.$object->cal,
  '"calendar" rendering in "view" mode should return the value';
is $r->render( $attr_for{select}, $object ), 'Select one '.$object->select,
  '"dropdown" rendering in "view" mode should return the value';

#
# edit mode
#

ok $r->mode('edit'), 'Setting the mode to "edit" should succeed';

#
# text
#

ok my $html = $r->render( $attr_for{foo} ),
  'We should be able to render text widgets';
is_xml wrap($html),
  wrap(
    '<label for="foo">Foo</label> <input name="foo" id="foo" type="text" size="40" tip="foo tip" maxlength="40"/>'
  ), '... and it should return XHTML with valid defaults';

#
# checkbox
#

my $expected = wrap(
    '<label for="check">Checkbox</label>
    <input name="check" id="check" type="checkbox" checked="checked"/>'
);
ok $html = $r->render( $attr_for{check} ),
  'We should be able to render checkbox widgets';
is_xml wrap($html), $expected,
  '... and it should return XHTML with valid defaults';

#
# textarea
#

ok $html = $r->render( $attr_for{some_text_area} ),
  'We should be able to render textarea widgets';
$expected = <<END;
    <label for="some_text_area">Text area</label>
    <textarea 
        name="some_text_area"
        id="some_text_area"
        rows="6" 
        cols="20"
        tip="Thanks for the tip"/>
END
is_xml wrap($html), wrap($expected),
  '... and it should return XHTML with valid defaults';

#
# calendar
#

ok $html = $r->render( $attr_for{cal} ),
  'We should be able to render calendar widgets';

$expected = <<'END_EXPECTED';
<label for="cal">Calendar</label>
<input name="cal" id="cal" type="text"/>
<input id="cal_trigger" type="image" src="/ui/images/calendar/calendar.gif"/>
<script type="text/javascript"/>
END_EXPECTED

$html =~ s{(<script type="text/javascript">).*}{$1</script>}s;
$html =~ s/^\s+//gsm;

is_xml wrap($html), wrap($expected),
  '... and it should return XHTML with valid defaults';

#
# dropdown
#

ok $html = $r->render( $attr_for{select} ),
  'We should be able to render dropwdown widgets';

$expected = <<"END_EXPECTED";
 <label for="select">Select one</label> <select name="select" id="select">
   <option value="0">Zero</option>
   <option value="1">One</option>
 </select>
END_EXPECTED

is_xml wrap($html), wrap($expected),
  '... and it should return XHTML with valid defaults';

#
# constraints
#

my $key = $object->my_class->key;

$r->format( constraints => '<html><p>%s</p><p>%s</p></html>' );
can_ok $r, 'constraints';
my @expected = qw(limit order_by sort_order);
is_deeply $r->constraints, \@expected,
  '... and it should return the correct constraints';

is_xml $r->render('limit', $key),
    '<html><p>Limit:</p><p><input type="text" name="_limit" value="20"/></p></html>',
    '... and limit constraints should render correctly';

$expected = <<'END_EXPECTED';
<html>
    <p>Order by:</p>
    <p>
        <select name="_order_by">
            <option value="uuid">UUID</option>
            <option value="state">State</option>
            <option value="foo">Foo</option>
            <option value="check">Checkbox</option>
            <option value="some_text_area">Text area</option>
            <option value="cal">Calendar</option>
            <option value="select">Select one</option>
        </select>
    </p>
</html>
END_EXPECTED
is_xml $r->render('order_by', $key), $expected,
    '... and order by constraints should render correctly';

$expected = <<'END_EXPECTED';
<html>
    <p>Sort order:</p>
    <p>
        <select name="_sort_order">
            <option value="ASC">Ascending</option>
            <option value="DESC">Descending</option>
        </select>
    </p>
</html>
END_EXPECTED
is_xml $r->render('sort_order', $key), $expected,
    '... and sort order constraints should render correctly';

__END__

# XXX Holding off on this a bit while I figure out the best way to test it

#
# search mode
#

ok $r->mode('search'), 'Setting the mode to "search" should succeed';

#
# text
#

ok $html = $r->render( $attr_for{foo} ),
  'We should be able to render text widgets';
my $logical = <<"END_LOGICAL";
    <select name="_foo_logical" id="_foo_logical">
        <option value="">is</option>
        <option value="NOT">is not</option>
    </select>
END_LOGICAL

my $comparison = <<"END_COMPARISON";
    <select name="_foo_comp" id="_foo_comp" onchange="checkForMultiValues(this); return false">
        <option value="EQ">equal to</option>
        <option value="LIKE">like</option>
        <option value="LT">less than</option>
        <option value="GT">greater than</option>
        <option value="LE">less than or equal</option>
        <option value="GE">greater than or equal</option>
        <option value="NE">not equal</option>
        <option value="BETWEEN">between</option>
        <option value="ANY">any of</option>
    </select>
END_COMPARISON

$expected =  <<"END_EXPECTED";
    <label for="foo">Foo</label>
    $logical
    $comparison
    <input name="foo" id="foo" type="text" size="40" tip="foo tip" maxlength="40"/>
END_EXPECTED

is_xml wrap($html), wrap($expected),
  '... and it should return XHTML with valid defaults';

