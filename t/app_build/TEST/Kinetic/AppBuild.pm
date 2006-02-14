package TEST::Kinetic::AppBuild;

# $Id$

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use File::Spec::Functions qw(catdir updir catfile);
use Class::Trait; # Avoid warnings.
use Test::File;

sub teardown_builder : Test(teardown) {
    my $self = shift;
    if (my $builder = delete $self->{builder}) {
        $builder->dispatch('realclean');
    }
}

sub test_new : Test(6) {
    my $self  = shift;
    my $class = $self->test_class;
    ok my $builder = $self->new_builder;
    isa_ok $builder, $class, 'The builder';

    is $builder->install_base, catdir(updir, updir),
        'The install base is correct';
    is $builder->install_path->{www}, catdir(updir, updir, 'www'),
        'The www base should be correct';

    # Try a bogus install base directory.
    throws_ok { $self->new_builder( install_base => 'foo' ) }
        qr/Directory "foo" does not exist; use --install-base to specify the Kinetic base directory/,
        'We should catch an invalid install_base';

    # Try an install_base directory without Kinetic.
    throws_ok { $self->new_builder( install_base => 'lib' ) }
        qr/Kinetic does not appear to be installed in "lib"; use --install-base to specify the Kinetic base directory/,
        'We should catch an install_base without Kinetic';
}

sub test_files : Test(no_plan) {
    my $self  = shift;
    my $class = $self->test_class;
    ok my $builder = $self->new_builder;
    isa_ok $builder, $class, 'The builder';

    my $blib_file = 'blib/lib/TestApp/Simple.pm';
    my $bwww_file = 'blib/www/test.html';
    my $bbin_file = 'blib/script/somescript';

    file_not_exists_ok $blib_file, 'blib lib file should not yet exist';
    file_not_exists_ok $bwww_file, 'blib www file should not yet exist';
    file_not_exists_ok $bbin_file, 'blib bin file should not yet exist';

    $builder->dispatch('build');

    file_exists_ok $blib_file, 'blib lib file should now exist';
    file_exists_ok $bwww_file, 'blib www file should now exist';
    file_exists_ok $bbin_file, 'blib bin file should now exist';
}

sub new_builder {
    my $self  = shift;
    my $class = $self->test_class;
    return $self->{builder} = $class->new(
        dist_name    => 'TestApp::Simple',
        dist_version => '1.0',
        quiet        => 1,
        install_base => catdir(updir, updir),
        @_,
    );
}
1;
__END__
