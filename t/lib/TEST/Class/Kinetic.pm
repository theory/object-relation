package TEST::Class::Kinetic;

# $Id$

use strict;
use warnings;
use utf8;
use base 'Test::Class';
use Test::More;
use Cwd;
use DBI;
use File::Path ();
use File::Spec::Functions;

use aliased 'Kinetic::Build';
use aliased 'Test::MockModule';

my ($STARTDIR, $DSN, $DBH, $DBFILE);

BEGIN { 
    $STARTDIR = getcwd;
    $DBFILE = "$STARTDIR/t/data/kinetic.db";
    if (-e $DBFILE && -f _) {
        unlink $DBFILE or die "Cannot unlink $DBFILE: $!";
    }
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.0.8');

    my $builder;
    my $mb = MockModule->new('Kinetic::Build');
    $mb->mock(resume => sub { $builder });
    $mb->mock(check_manifest => sub { return });

    local @INC = (catdir(updir, updir, 'lib'), @INC);

    #chdir 't';
    #chdir 'sample';
    $ENV{KINETIC_CONF} = 't/conf/kinetic.conf';
    $builder = Build->new(
        dist_name       => 'Testing::Kinetic',
        dist_version    => '1.0',
        quiet           => 1,
        accept_defaults => 1,
        run_dev_tests   => 1,
    );
    $builder->source_dir('t/sample/lib');
    $builder->dispatch('setup_test');
    $DSN = "dbi:SQLite:dbname=$DBFILE";
    $DBH = DBI->connect($DSN, '', '', {RaiseError => 1});
}

END {}

sub _dbh     { $DBH    }
sub _dsn     { $DSN    }
sub _db_file { $DBFILE }

my $builder;
sub builder {
    my $test = shift;
    return $builder unless @_;
    $builder = shift;
    return $test;
}

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
    $self->{_cwd_} ||= getcwd;
    chdir $_ for @_;
    return $self;
}

sub mkpath {
    my $self = shift;
    return $self unless @_;
    my ($build, @cleanup);
    for my $dir (@_) {
        $build = catdir((defined $build ? $build : ()), $dir);
        next if -e $build;
        push @cleanup, $build;
        File::Path::mkpath($build);
    }
    push @{$self->{_paths_}}, @cleanup if @cleanup;
    return $self;
}

sub data_dir { catdir 't', 'data' }

##############################################################################

=head3 _start_dir

  my $start_dir = $test->_start_dir;

Read only.  Returns absolute path to the directory the tests are run from.

=cut

sub _start_dir { $STARTDIR }

##############################################################################

=head3 _test_lib

  my $test_lib = $test->_test_lib;

Returns absolute path to the test lib directory that Kinetic ojbects will use.
May be overridden.

=cut

sub _test_lib {
    return File::Spec->catfile(shift->_start_dir, qw/t lib/);
}


1;
__END__
