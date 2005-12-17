#!/usr/bin/perl -w

# $Id: tt_renderer.t 1829 2005-07-02 01:53:14Z curtis $

use strict;
use warnings;

#use Test::More tests => 118;
use Test::More 'no_plan';

use Test::Exception;
use Test::XML;

my $RENDERER;

BEGIN {
    chdir 't' if -d 't';
    use lib '../lib';
    $RENDERER = 'Kinetic::Template::Plugin::Renderer';
    use_ok $RENDERER or die;
}

BEGIN {

    package Test::Language::en;
    use Kinetic::Util::Language::en;
    Kinetic::Util::Language::en->add_to_lexicon( map { $_ => $_ }
          ( 'Foo', 'foo tip', ' ', 'Thanks for the tip' ) );

    package Some::Package;

    use Kinetic::Meta;
    use aliased 'Kinetic::Meta::Widget';
    use Class::Meta::Declare qw/:all/;

    Class::Meta::Declare->new(
        meta       => [ use => 'Kinetic::Meta' ],
        attributes => [
            foo => {
                label => 'Foo',
                widget_meta => Widget->new(
                    type  => 'text',
                    tip   => 'foo tip',
                ),
            },
            check => {
                widget_meta => Widget->new(
                    type    => 'checkbox',
                    checked => 1
                ),
            },
            some_text_area => {
                widget_meta => Widget->new(
                    type => 'textarea',
                    rows => 6,
                    cols => 20,
                    tip  => 'Thanks for the tip',
                ),
            },
            cal => { widget_meta => Widget->new( type => 'calendar' ) }
        ]
    );
}

#
# XXX Note the unusual way of calling the constructor.  Becuase a TT plugin's
# constructor has "context" passed after the class and the subsequent
# arguments are passed has a hashref, we pass "undef" for the context (the
# code is not relying on it) and this constructor is equilant to:
#
# [% USE Renderer( mode => 'edit', format => {} ) %]
#

can_ok $RENDERER, 'new';
ok my $r = $RENDERER->new( undef, { mode => 'edit' } ),  # format has defaults
  '... and we should be able to create a new renderer';
isa_ok $r, $RENDERER, '... and the object it returns';

can_ok $r, 'mode';
throws_ok { $r->mode('foo') } 'Kinetic::Util::Exception::Fatal::Invalid',
  '... and attempting to set it to an illegal value should fail';

my $test_class = Some::Package->new;
my $meta_class = $test_class->my_class;
my %attr_for   = map { $_->name => $_ } $meta_class->attributes;

can_ok $r, 'render';

# text

ok my $html = $r->render( $attr_for{foo} ),
  'We should be able to render text widgets';
is_xml wrap($html),
  wrap('<label for="foo">Foo</label> <input name="foo" id="foo" type="text" size="40" tip="foo tip" maxlength="40"/>'),
  '... and it should return XHTML with valid defaults';

exit;
# checkbox

ok $html = $r->render( $attr_for{check} ),
  'We should be able to render checkbox widgets';
is_xml $html,
  '<input name="check" id="check" type="checkbox" checked="checked"/>',
  '... and it should return XHTML with valid defaults';

# textarea

ok $html = $r->render( $attr_for{some_text_area} ),
  'We should be able to render textarea widgets';
my $expected = <<END;
    <textarea 
        name="some_text_area"
        id="some_text_area"
        rows="6" 
        cols="20"
        tip="Thanks for the tip"/>
END
is_xml wrap($html), wrap($expected),
  '... and it should return XHTML with valid defaults';

# calendar
ok $html = $r->render( $attr_for{cal} ),
  'We should be able to render calendar widgets';

$expected = <<'END_EXPECTED';
<input name="cal" id="cal" type="text"/>
<input id="cal_trigger" type="image" src="/images/calendar/calendar.gif"/>
<script type="text/javascript"/>
END_EXPECTED

$html =~ s{(<script type="text/javascript">).*}{$1</script>}s;
$html =~ s/^\s+//gsm;

is_xml wrap($html), wrap($expected),
  '... and it should return XHTML with valid defaults';

sub wrap {
    my $text = shift;
    return "<html>$text</html>";
}
