#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 8;
use File::Spec;
use File::Find;

my @path = qw(lib Kinetic Language);
# Move up if we're running in t/.
unshift @path, File::Spec->updir unless -d 't';
my @langs;
my $find_langs = sub {
    return unless /\.pm$/;
    return if /#/; # Ignore old backup files.
    unshift @langs, file_to_class($File::Find::name);
};

# Find all of the language classes and make sure that they load.
find($find_langs, File::Spec->catdir(@path));
use_ok $_ for @langs;


##############################################################################
# Just make sure maketext() works. Probably redundant.

my $self = shift;
ok my $lang = Kinetic::Language->get_handle('en_us'),
  'Create language object';
is($lang->maketext('Value "[_1]" is not a [_2] object', 'foo', 'bar'),
   'Value "foo" is not a bar object', 'Text maketext' );

# Make sure we're throwing an exception properly.
eval { $lang->maketext('foo') };
ok( my $err = $@, 'Catch exception');
isa_ok( $err, 'Kinetic::Exception');
isa_ok( $err, 'Kinetic::Exception::Fatal');
isa_ok( $err, 'Kinetic::Exception::Fatal::Language');

sub file_to_class {
    my (@dirs) = File::Spec->splitdir(substr shift, 0, -3);
    while ($dirs[0] && ($dirs[0] eq 't' || $dirs[0] eq 'lib')) {
        shift @dirs;
    }
    join '::', @dirs;
}

1;
__END__
