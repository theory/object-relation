package TEST::Kinetic::Build::Store;

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Build';

__PACKAGE__->runtests;
sub test_interface : Test(18) {
    my $self = shift;
    my $class = $self->test_class;
    for my $method (qw'new builder build test_build info_class info rules
                       validate config test_config min_version max_version
                       schema_class is_required_version store_class
                       serializable resume test_cleanup',
                    @_) {
        can_ok $class, $method;
    }
}

sub test_class_methods : Test(6) {
    my $self = shift;
    my $class = $self->test_class;
    is $class->store_class, 'Kinetic::Store', "Store class should correct";
    is $class->schema_class, 'Kinetic::Build::Schema',
      "Schema class should correct";
    is $class->max_version, 0, 'max_version should default to 0';
    throws_ok { $class->info_class }
      qr'info_class\(\) must be overridden in the subclass',
      'info_class() needs to be overridden';
    throws_ok { $class->min_version }
      qr'min_version\(\) must be overridden in the subclass',
      'min_version() needs to be overridden';
    throws_ok { $class->rules }
      qr'rules\(\) must be overridden in the subclass',
      'rules() needs to be overridden';
}

sub test_instance : Test(21) {
    my $self = shift;
    my $class = $self->test_class;

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );
    my $store = MockModule->new($class);
    $store->mock(info_class => 'TEST::Kinetic::TestInfo');

    # Create an object and try basic accessors.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;
    isa_ok $kbs->builder, 'Kinetic::Build';
    isa_ok $kbs->info, 'TEST::Kinetic::TestInfo',
      "The App::Info object should have been created";

    # Try validate().
    $store->mock(rules => sub {
                     Done => {
                         do => sub { ok 1, "validate() should execute rules";}
                     }
                 });
    ok $kbs->validate, "validate() shoud work";

    # Try is_required_version().
    $store->mock(min_version => 1 );
    ok $kbs->is_required_version, "We should have the required version";
    $store->mock(max_version => 0.5);
    ok ! $kbs->is_required_version, "The version number should be too high";
    $store->unmock('max_version');
    $store->mock(min_version => 2 );
    ok ! $kbs->is_required_version, "The version number should be too low";

    # Config methods need to be overridden.
    throws_ok { $class->config }
      qr'config\(\) must be overridden in the subclass',
      'config() needs to be overridden';
    throws_ok { $class->test_config }
      qr'test_config\(\) must be overridden in the subclass',
      'test_config() needs to be overridden';

    # Test build() and test_build().
    $kbs->{actions} = [['config']];
    my $meth = 'build';
    $store->mock(config => sub {
        ok 1, "Config should be called by $meth() actions"
    });
    ok $kbs->build, 'Build should return true';
    $meth = 'test_build';
    ok $kbs->test_build, 'test_build should return true';

    is $kbs->test_cleanup, $kbs, 'test_cleanup should just return';

    # Check serializable and resume.
    is $kbs->serializable, $kbs, 'serializable should return itself';
    is $kbs->builder, undef, '... And now there should be no builder';
    is $kbs->info, undef, '... or App::Info object.';
    is $kbs->resume($builder), $kbs, "resume() should return itself";
    is $kbs->builder, $builder, "... And now the builder should be back";
}

package TEST::Kinetic::TestInfo;
sub new { bless {} };
sub version { 1 }

1;
__END__
