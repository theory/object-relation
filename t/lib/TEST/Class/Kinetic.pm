package TEST::Class::Kinetic;

# $Id$

use strict;
use warnings;
use utf8;
use base 'Test::Class';
use Test::More;
use Cwd ();
use File::Path ();
use File::Spec::Functions;
use aliased 'Test::MockModule';

__PACKAGE__->runtests;

my %SUPPORTED = map { $_ => undef } split /\s+/, $ENV{KINETIC_SUPPORTED};

sub supported { exists $SUPPORTED{$_[1]} }

sub a_test_load : Test(startup => 1) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    return ok 1, "TEST::Class::Kinetic loaded" if $class eq 'Class::Kinetic';
    use_ok $class or die;
    $test->{test_class} = $class;
}

sub test_class { shift->{test_class} }

sub cleanup : Test(teardown) {
    my $self = shift;
    chdir delete $self->{_cwd_} if exists $self->{_cwd_};
    if (my $paths = delete $self->{_paths_}) {
        File::Path::rmtree($_) for reverse @$paths;
    }
}

sub chdirs {
    my $self = shift;
    $self->{_cwd_} ||= Cwd::getcwd;
    chdir $_ for @_;
    return $self;
}

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


1;
__END__
