use strict;
use 5.008003;
use lib 'lib';
use Kinetic::Build;

my $build = Kinetic::Build->new(
    module_name        => 'Kinetic',
    license            => 'gpl',
    create_makefile_pl => 'passthrough',
    dist_author        => 'Kineticode, Inc. <info@kineticode.com>',
    requires           => {
        'Class::Meta'           => 0.44,
        'Data::UUID'            => 0.11,
#        'DateTime'              => 0.1705,
#        'DateTime::Incomplete'  => 0.02,
#        'DBI'                   => 1.43,
        'Exception::Class'      => 1.12,
#        'Exception::Class::DBI' => 0.92,
        'Exporter::Tidy'        => 0.06,
        'Lingua::Strfname'      => 0.10,
        'Locale::Maketext'      => 1.09,
        'version'               => 0.420,
        'Widget::Meta'          => 0.03,
#        'XML::Genx'             => 0.05,
#        'DBD::Pg'               => 1.32, # XXX Change to option.
#        'DBD::SQLite'           => 1.07, # XXX Change to option.
    },
    build_requires     => {
        'App::Info'             => 0.40,
        'Module::Build'         => 0.26,
        'Sub::Override'         => 0.05,
        'Test::More'            => 0.17,
        'Test::Differences'     => 0.47,
        'Test::File'            => 1.06, # XXX Update if OS patch applied.
        'Test::File::Contents'  => 0.02, # XXX Update if OS patch applied.
    },
);

$build->create_build_script;
