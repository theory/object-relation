#!/usr/bin/perl -w

# $Id$

use strict;

use Test::More;

my $QPSMTPD;

BEGIN {
    eval "use Qpsmtpd";
    if ($@) {
        plan skip_all => "Qpsmtpd must be installed for the Qpsmtpd tests";
    }
    else {
        #plan 'no_plan';
        plan tests => 9;
    }

    # the following line merely verifies that it comples.  Qpsmtpd is actually
    # a trait which exports its methods into a qpsmtpd plugin
    $QPSMTPD = 'Kinetic::UI::Email::Workflow::Qpsmtpd';
    use_ok $QPSMTPD or die;
}

use Test::NoWarnings;    # Adds an extra test

use aliased 'Qpsmtpd::Address';
use Class::Trait $QPSMTPD;    # heh :)
my $qpsmtpd = bless {}, __PACKAGE__;    # double heh :)

my @recipients;
my @body;
{

    package Transaction;

    sub new { bless {}, shift }
    sub recipients    {@recipients}
    sub body_resetpos { }

    sub body_getline {
        return unless @body;
        shift(@body) . "\n";
    }
}

ok defined &_log_email, '_log_email should be flattened into our namespace';

ok defined &_for_workflow,
  '_for_workflow should be flattened into our namespace';
my $transaction = Transaction->new;
ok !$qpsmtpd->_for_workflow($transaction),
  '... and it should return false unless there are valid workflow recipients';

@recipients = map { Address->new($_) } qw(
  some@email.address
  not@home.com
  job+workflow@org.workflow.com
);
ok $qpsmtpd->_for_workflow($transaction),
  '... and it should return true if there are valid workflow recipients';

my $body = <<END_BODY;
>
> [X] Return {this stage}
>
END_BODY

@body = split /\n/, $body;

ok defined &_get_body, '_get_body should be flattened into our namespace';
is $qpsmtpd->_get_body($transaction), $body,
  '... and it should return the body of the email';

{
    no warnings 'redefine';
    sub _log_email { }
}

ok defined &hook_data_post,
  'hook_data_post should be flattened into our namespace';

# there's not much more I can do to really test this as the workflow stuff in
# the body hook is just a stub.  Thus, I don't know I'll really have anything
# working until WF is further along.
