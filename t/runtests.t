#!/usr/local/bin/perl
use warnings;
use strict;
use Carp qw/croak/;
use File::Find;
use File::Spec;
use Kinetic::Build;
use Test::Class;
use lib 't/test_lib';

my @classes;
my $build = Kinetic::Build->resume;
Test::Class->runtests(@classes);

BEGIN {
    @classes = classes(shift);

    sub classes {
        my $test_dir = shift || 't';
        unshift @INC => $test_dir;
        my @classes;
        my $wanted = sub {
            my $file = $File::Find::name;
            return if /^\.(?:svn|cvs)/;
            return unless /\.pm$/;
            return if /#/; # Ignore old backup files.
            return if grep {$file =~ /^$_/} non_test_dirs();
            my $class = file_to_mod($file);
            if ($class) {
                eval "use $class";
                die "Could not require $class from $file: $@" if $@;
                push @classes => $class if $class->isa('Test::Class');
            }
        };
        find({ wanted => $wanted, no_chdir => 1 }, $test_dir);
        return grep $_ => @classes;
    }

    sub file_to_mod {
        my ($file) = @_;
        $file =~ s/\.pm$// or croak "$file is not a Perl module";
        my (@dirs) = File::Spec->splitdir($file);
        shift @dirs while $dirs[0] && $dirs[0] !~ /^[[:upper:]]/; # assumes only class file will be upper-cased
        my $class = join '::' => @dirs;
        return $class;
    }

    sub non_test_dirs {
        qw{
            t/build_sample
            t/conf
            t/lib
        }
    }
}
