package TEST::Class::Kinetic;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;
use warnings;
use utf8;
use base 'Test::Class';
use Test::More;
use Cwd ();
use File::Path ();
use File::Find;
use File::Spec::Functions;
use Config::Std; # Avoid warnings.
use Test::NoWarnings ();
use aliased 'Test::MockModule';

BEGIN {
    # Tell Test::Builder to use the utf8 layer for its file handles.
    my $tb = Test::Builder->new;
    binmode $tb->$_, ':utf8' for qw(output failure_output todo_output);
}

__PACKAGE__->runtests unless caller;

=head1 Name

TEST::Class::Kinetic - The Kinetic test class base class

=head1 Synopsis

  use lib 't/lib';
  use TEST::Class::Kinetic 't/lib';
  TEST::Class::Kinetic->runall;

=head1 Description

This class is the base class for all Kinetic test classes. It inherits from
L<Test::Class|Test::Class>, and so, therefore, do its subclasses. Create new
subclasses to add new tests to the Kinetic framework.

In addition to the interface provided by Test::Class, TEST::Class::Kinetic
does the extra work of finding all test classes in a specified directory and
loading them. The tests in these classes can then be run by calling the
C<runall()>. This feature is most often used by test scripts in the C<t>
directory, rather than by test classes themselves.

The classes found in the directory specified in the C<use> statment are loaded
upon startup. Only those modules that inherit from TEST::Class::Kinetic will
be processed by a call to C<runall()>, however.

In addition, this module sets up a number of configurations and methods that
test subclasses can use to create directories, change directories, or check to
see if particular features are enabled. The supported features are parsed from
an environment variable, C<KINETIC_SUPPORTED>, which is set by C<./Build
test>. If tests aren't being run by the Kinetic build system, simply set the
environment variable to a space-delimited list of supported features, like so:

  KINETIC_CONF=t/conf/kinetic.conf KINETIC_SUPPORTED="sqlite pg" prove t/build.t

=cut

my @CLASSES;

sub import {
    my ($pkg, $dir) = @_;
    if ($ENV{RUNTEST}) {
        push @CLASSES,
          map { eval "require $_" or die $@; $_ } split /\s+/, $ENV{RUNTEST};
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

  Kinetic::Test->runall

Runs the tests in all of the classes loaded from the directory specified in
the C<use> statement.

=cut

sub runall { shift->runtests(@CLASSES) }

##############################################################################

=head3 dev_testing

  sub test_dev : Test(1) {
      reutrn "Not running dev tests" unless TEST::Class::Kinetic->dev_testing;
      ok 1, 'We can use run dev tests!';
      # ...
  }

This method returns true if development tests can be run (i.e., those that can
make changes to a data store) and falise if they cannot. Use it to determine
whether or not to run dev tests.

=cut

sub dev_testing { exists $ENV{KINETIC_SUPPORTED} }

##############################################################################

=head3 supported

  sub test_sqlite : Test(1) {
      return "Not testing SQLite"
        unless TEST::Class::Kinetic->supported('sqlite');
      ok 1, 'We can use SQLite!';
      # ...
  }

Pass a single argument to this method to find out whether a particular feature
of the Kinetic framework is supported. This makes it easy to determine whether
or not to skip a set of tests.

=cut

my %SUPPORTED = map { $_ => undef } split /\s+/, $ENV{KINETIC_SUPPORTED} || '';

sub supported { exists $SUPPORTED{$_[1]} }

##############################################################################

=head3 any_supported

  if (__PACKAGE__->any_supported(@features)) { ... }

This method returns a boolean value indicating whether or not I<any> features
of the Kinetic framework are supported. Takes a list of features.

Optionally

=cut

sub any_supported {
    my ($class, @features) = @_;
    foreach my $feature (@features) {
        return 1 if exists $SUPPORTED{$feature};
    }
    return;
}

##############################################################################

=head3 file_to_class

  my $class = TEST::Class::Kinetic->file_to_class($file_name);

This method takes a file name for an argument, converts it to a class name,
and then requires the clas. This is useful for tests that search the file
system for class files, and then want to load those classes. The class name is
assumed to start with an upper-case character, so all characters in the file
name up to the first upper-case character will be removed, and the remainder
of the file name will make up the class name. Thus, any of the following
exmples would be properly converted:

=over 4

=item F<t/lib/TEST/Kinetic/Build.pm>

Loads and returns "TEST::Kinetic::Build".

=item F<lib/Kinetic/Util/Language.pm>

Loads and returns "Kinetic::Util::Language".

=item F<Kinetic/Util/Config.pm>

Loads and returns "Kinetic::Util::Config".

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
    return ok 1, "TEST::Class::Kinetic loaded" if $class eq 'Class::Kinetic';
    use_ok $class or die;
    $test->{test_class} = $class;
}

##############################################################################

=head3 test_class

  my $test_class = $test->test_class;

Returns the name of the Kinetic class being tested. This will usually be the
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

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
