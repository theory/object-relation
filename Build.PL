use strict;
use 5.008003;
use lib 'lib';
use Kinetic::Build;

my $build = Kinetic::Build->new(
    module_name          => 'Kinetic',
    license              => 'gpl',
    create_makefile_pl   => 'passthrough',
    build_class          => 'Kinetic::Build',
    dist_author          => 'Kineticode, Inc. <info@kineticode.com>',
    recursive_test_files => 1,
    requires             => {
        'aliased'               => 0.11,
        'Class::Meta'           => 0.44,
        'Clone'                 => 0.15,
        'Data::UUID'            => 0.11,
        'DateTime'              => 0.24,
#        'DateTime::Incomplete'  => 0.02,
        'DBI'                   => 1.43,
        'Exception::Class'      => 1.12,
        'Exception::Class::DBI' => 0.92,
        'Exporter::Tidy'        => 0.06,
        'Lingua::Strfname'      => 0.10,
        'Locale::Maketext'      => 1.09,
        'version'               => 0.420,
        'Widget::Meta'          => 0.03,
#        'XML::Genx'             => 0.05,
#        'DBD::Pg'               => 1.32, # XXX Change to option.
#        'DBD::SQLite'           => 1.08, # XXX Change to option.
    },
    build_requires       => {
        'App::Info'             => 0.42,
        'FSA::Rules'            => 0.21,
        'Module::Build'         => 0.26,
        'Sub::Override'         => 0.05,
        'Test::Class'           => 0.10,
        'Test::Differences'     => 0.47,
        'Test::Exception'       => 0.20,
        'Test::File'            => 1.08,
        'Test::File::Contents'  => 0.02, # XXX Update if OS patch applied.
        'Test::MockModule'      => 0.04,
        'Test::More'            => 0.17,
        'Test::Pod::Coverage'   => 0.08,    # this is recommended, not required.
    },
);

$build->create_build_script;
