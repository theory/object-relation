use Module::Build;

use strict;
use 5.005003;

my $build = Module::Build->new(
    module_name        => 'Kinetic',
    license            => 'gpl',
    create_makefile_pl => 'passthrough',
    dist_author        => 'Kineticode, Inc. <info@kineticode.com>',
    requires => {
        'Class::Meta'           => 0.44,
        'Data::UUID'            => 0,
        'DateTime'              => 0.1705,
        'DateTime::Incomplete'  => 0,
        'DBI'                   => 0,
        'Exception::Class'      => 1.12,
#        'Exception::Class::DBI' => 0,
        'Exporter::Tidy'        => 0,
        'Lingua::Strfname'      => 0,
        'Locale::Maketext'      => 0,
        'version'               => 0,
        'Widget::Meta'          => 0.03,
        'XML::Writer'           => 0,
    },
    build_requires => {
        'Module::Build'         => 0.26,
        'Test::More'            => 0.17,
        'Test::Differences'     => 0.47,
    },
);

$build->create_build_script;
