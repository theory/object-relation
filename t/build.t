#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use File::Find;
use File::Spec::Functions;
BEGIN {
    # All build tests execute in the sample directory with its
    # configuration file.
    chdir 't'; chdir 'sample';
    $ENV{KINETIC_CONF} = catfile 'conf', 'kinetic.conf';
}

# Make sure we get access to all lib directories we're likely to need.
use lib catdir(updir, 'build'),              # Build test classes
        catdir(updir, 'lib'),                # Base test class, utility
        catdir(updir, updir, 'blib', 'lib'), # Build library
        catdir(updir, updir, 'lib');         # Distribution library

use TEST::Class::Kinetic;

my @classes;

TEST::Class::Kinetic->runtests(@classes);

BEGIN {
    if ($ENV{RUNTEST}) {
        push @classes,
          map { eval "require $_" or die $!; $_ }
          split /\s+/, $ENV{RUNTEST};
    } else {
        find({ wanted => \&wanted, no_chdir => 1 },
             catdir updir, 'build', 'TEST');
    }

    sub wanted {
        my $file = $File::Find::name;
        return if /^\.(?:svn|cvs)/;
        return unless /\.pm$/;
        return if /[#~]/; # Ignore backup files.
        if (my $class = file_to_mod($file)) {
            eval "require $class" or die $@;
            push @classes => $class;
        }
    };

    sub file_to_mod {
        my ($file) = @_;
        $file =~ s/\.pm$// or die "$file is not a Perl module";
        my (@dirs) = File::Spec->splitdir($file);
        # Assume that only test class file will be upper-cased.
        shift @dirs while $dirs[0] && $dirs[0] !~ /^[[:upper:]]/;
        my $class = join '::' => @dirs;
        return $class;
    }

}

__END__
