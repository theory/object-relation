use Module::Build;

use strict;
use 5.005003;

my $build = Module::Build->new(
    module_name        => 'App::Kinetic',
    license            => 'perl', # Switch to GPL?
    create_makefile_pl => 'passthrough',
    dist_author        => 'Kineticode <info@kineticode.com>',
    dist_abstract      => 'The Kinetic application framework',
    requires           => {  },
);

$build->create_build_script;
