package TEST::Class::Object::Relation;

# $Id: Object::Relation.pm 3069 2006-07-24 20:59:25Z theory $

use strict;
use warnings;
use utf8;
use base 'Test::Class';
use Test::More;
use Cwd ();
use File::Path ();
use File::Find;
use File::Spec::Functions;
use Test::NoWarnings ();
use aliased 'Test::MockModule';

BEGIN {
    # Tell Test::Builder to use the utf8 layer for its file handles.
    my $tb = Test::Builder->new;
    binmode $tb->$_, ':utf8' for qw(output failure_output todo_output);
}

__PACKAGE__->runtests unless caller;

=head1 Name

TEST::Class::Object::Relation - The Object::Relation test class base class

=head1 Synopsis

  use lib 't/lib';
  use TEST::Class::Object::Relation 't/system';
  TEST::Class::Object::Relation->runall;

=head1 Description

This class is the base class for all Object::Relation test classes. It inherits from
L<Test::Class|Test::Class>, and so, therefore, do its subclasses. Create new
subclasses to add new tests to the Object::Relation framework.

In addition to the interface provided by Test::Class, TEST::Class::Object::Relation
does the extra work of finding all test classes in a specified directory and
loading them. The tests in these classes can then be run by calling the
C<runall()> method. This feature is most often used by test scripts in the
C<t> directory, rather than by test classes themselves.

The classes found in the directory specified in the C<use> statment (which may
be specified as a Unix-style path; this module will convert it to the local
system notation) are loaded upon startup. Only those modules that inherit from
TEST::Class::Object::Relation will be processed by a call to C<runall()>, however.

In addition, this module sets up a number of configurations and methods that
test subclasses can use to create directories or change directories.

=cut

my @CLASSES;

sub import {
    my ($pkg, $dir) = @_;
    if ($dir) {
        $dir = catdir(split m{/}, $dir);
        unshift @INC, $dir;
    }
    if ($ENV{RUNTEST}) {
        push @CLASSES,  map { eval "require $_" or die $@; $_ }
            split /\s+/, $ENV{RUNTEST};
    } elsif ($dir) {
        my $want = sub {
            my $file = $File::Find::name;
            return if /^\.(?:svn|cvs)/;
            return unless /\.pm$/;
            return if /[#~]/; # Ignore backup files.
            my $class = __PACKAGE__->file_to_class($file);
            push @CLASSES, $class if $class->isa(__PACKAGE__);
        };

        find({ wanted => $want, no_chdir => 1 }, $dir);
    }
}

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 runall

  Object::Relation::Test->runall

Runs the tests in all of the classes loaded from the directory specified in
the C<use> statement.

=cut

sub runall { shift->runtests(@CLASSES) }

##############################################################################

=head3 file_to_class

  my $class = TEST::Class::Object::Relation->file_to_class($file_name);

This method takes a file name for an argument, converts it to a class name,
and then requires the clas. This is useful for tests that search the file
system for class files, and then want to load those classes. The class name is
assumed to start with an upper-case character, so all characters in the file
name up to the first upper-case character will be removed, and the remainder
of the file name will make up the class name. Thus, any of the following
exmples would be properly converted:

=over 4

=item F<t/lib/TEST/Object/Relation.pm>

Loads and returns "TEST::Object::Relation".

=item F<lib/Object/Relation/Language.pm>

Loads and returns "Object::Relation::Language".

=back

=cut

sub file_to_class {
    my ($pkg, $file) = @_;
    $file =~ s/\.pm$// or die "$file is not a Perl module";
    my (@dirs) = File::Spec->splitdir($file);
    # Assume that only test class file will be upper-cased.
    shift @dirs while $dirs[0] && $dirs[0] !~ /^[[:upper:]]/;
    my $class = join '::', @dirs;
    eval "require $class" or die $@;
    return $class;
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 a_test_load

This is a test method automatically run by the Test::Class framework. It
determines the class being tested (by removing "TEST::" from the package name
of the test class itself) and makes sure that it loads. The name of the class
being tested can thereafter be retreived from the C<test_class()> method. It
has the funny name it does to ensure that it runs before other tests in the
test class, so that the value returned by the C<test_class()> will be correct
for the rest of the methods in the class.

=cut

sub a_test_load : Test(startup => 1) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    return ok 1, "TEST::Class::Object::Relation loaded"
        if $class eq 'Class::Object::Relation'
        || $class eq 'Object::Relation';

    use_ok $class or die;
    $test->{test_class} = $class;
}

##############################################################################

=head3 test_class

  my $test_class = $test->test_class;

Returns the name of the Object::Relation class being tested. This will usually be the
same as the name of the test class itself with "TEST::" stripped out.

=cut

sub test_class { shift->{test_class} }

##############################################################################

=head3 chdirs

  $test->chdirs('t', 'data');

Changes into each of the directories specified. This is a great way to descend
into subdirectories, as the current working directory will be restored by the
execution of the C<tck_cleanup()> method when the test method that calls
C<chdirs()> returns.

=cut

sub chdirs {
    my $self = shift;
    $self->{_cwd_} ||= Cwd::getcwd;
    chdir $_ for @_;
    return $self;
}

##############################################################################

=head3 mkpath

  $test->mkpath('t', 'data', 'store');

Creates a new directory path based on the list of directories passed to it. In
the above example, the path to "t/data/store" would be created. The first
directory to be created that does not already exist will be completely deleted
(along with any contents that a test has put into it) by the execution of the
C<tck_cleanup()> method when the test method that calls C<mkpath()> returns.

In other words, the path created by <mkpath()> lasts only for the duration of
the test method that called it.

=cut

sub mkpath {
    my $self = shift;
    return $self unless @_;
    my ($build, $cleanup);
    for my $dir (@_) {
        $build = catdir((defined $build ? $build : ()), $dir);
        next if -e $build;
        $cleanup ||= $build;
        File::Path::mkpath($build);
    }
    push @{$self->{_paths_}}, $cleanup if $cleanup;
    return $self;
}

##############################################################################

=head3 tck_cleanup

This is a Test::Class "teardown" method. It executes after every test method
returns, changing back to the original working directory if it was changed by
any calls to C<chdirs()>, and deleting any paths created by any calls to
C<mkpath()>.

=cut

sub tck_cleanup : Test(teardown) {
    my $self = shift;
    chdir delete $self->{_cwd_} if exists $self->{_cwd_};
    if (my $paths = delete $self->{_paths_}) {
        File::Path::rmtree($_) for reverse @$paths;
    }
}

##############################################################################

=head2 Test Methods

=head3 z_no_warnings

This is a Test::Class C<shutdown> method that runs after all tests have run in
each test class. It ensures that were no warnings while the tests ran. If
there were none, its single test passes. If there were warnings, the test will
fail and a stack trace will be sent to diagnostic output.

=cut

sub z_no_warnings : Test(shutdown => 1) {
    Test::NoWarnings::had_no_warnings();
    Test::NoWarnings::clear_warnings();
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
