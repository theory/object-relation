#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use diagnostics;

use Test::More tests => 443;
use Test::NoWarnings; # Adds an extra test.
use File::Spec;
use File::Find;

no warnings 'uninitialized';

sub file_to_class {
    my (@dirs) = File::Spec->splitdir( substr shift, 0, -3 );
    while ( $dirs[0] && ( $dirs[0] eq 't' || $dirs[0] eq 'lib' ) ) {
        shift @dirs;
    }
    join '::', @dirs;
}

my ( @langs, @libs );

BEGIN {
    my @path = qw(lib Kinetic Util Language);

    # Move up if we're running in t/.
    unshift @path, File::Spec->updir unless -d 't';

    my $find_langs = sub {
        return unless /\.pm$/;
        return if /#/;    # Ignore old backup files.
        unshift @langs, file_to_class $File::Find::name;
    };

    # Find all of the language classes and make sure that they load.
    find( $find_langs, File::Spec->catdir(@path) );
    foreach my $lang (@langs) {
        use_ok $lang or die;
    }

    # Find all libraries.
    my $find_libs = sub {
        return unless /\.pm$/;
        return if /#/;    # Ignore old backup files.
        return if $File::Find::name =~ /Language[^.]/;    # Ignore l10n libs.
        push @libs, $File::Find::name;
    };

    # Find all of the language classes and make sure that they load.
    find( $find_libs, File::Spec->catdir('lib') );
    find( $find_libs, File::Spec->catdir('t') ); # the might be in test libs, too
}

##############################################################################
# Just make sure maketext() works. Probably redundant.

my $self = shift;
ok my $lang = Kinetic::Util::Language->get_handle('en_us'),
  'Create language object';

is(
    $lang->maketext( 'Value "[_1]" is not a valid [_2] object', 'foo', 'bar' ),
    "Value \x{201c}foo\x{201d} is not a valid bar object",
    'Check maketext'
);

# Try adding to the lexicon.
Kinetic::Util::Language::en_us->add_to_lexicon( 'Thingy', 'Thingy' );
is( $lang->maketext('Thingy'), 'Thingy', "Check for added lexicon key" );

# Make sure we're throwing an exception properly.
eval { $lang->maketext('foo') };
ok( my $err = $@, 'Catch exception' );
isa_ok( $err, 'Kinetic::Util::Exception' );
isa_ok( $err, 'Kinetic::Util::Exception::Fatal' );
isa_ok( $err, 'Kinetic::Util::Exception::Fatal::Language' );

##############################################################################
# Make sure that all keys are present in all languages.
for my $class (@langs) {
    next if $class eq 'Bricolage::Util::Language::en';
    ( my $code = $class ) =~ s/^Kinetic::Util::Language:://;
    my $lang = Kinetic::Util::Language->get_handle($code);
    for my $key ( keys %Kinetic::Util::Language::en::Lexicon ) {

        # XXX We might need to look for quant to make this work
        # properly.
        ok $lang->maketext( $key, qw(one two three four five) ), "$code: $key";
    }
}

# Make sure that all localizations are actually used.
for my $key ( keys %Kinetic::Util::Language::en::Lexicon ) {
    ok find_text($key), qq{"$key" should be used};
}

sub find_text {
    my $text = shift;

    my $rx = qr/\Q$text/;    # XXX this can fail with escapes in strings
    for my $lib (@libs) {
        open my $in, '<', $lib or die "Cannot open '$lib': $!\n";
        while (<$in>) {
            return 1 if /$rx/;
        }
        close $in;
    }
    return;
}

1;
__END__
