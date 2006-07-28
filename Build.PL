use strict;
use 5.008003;
use lib 'lib';
use Module::Build;

my $build = Module::Build->new(
    module_name          => 'Object::Relation',
    license              => 'perl',
    dist_author          => 'Kineticode, Inc. <info@obj_relode.com>',
    recursive_test_files => 1,
    add_to_cleanup       => [ 't/data' ],
    requires             => {
        'aliased'                    => 0.11,
        'Array::AsHash'              => 0.31,
        'Class::BuildMethods'        => 0.10,
        'Class::Meta'                => 0.53,
        'Class::Meta::Express'       => 0.03,
        'Clone'                      => 0.15,   # ???
        'Data::Types'                => 0.06,
        'DateTime'                   => 0.30,
        'DateTime::Format::Strptime' => 1.0601,
        'DateTime::Incomplete'       => 0.02,
        'DBI'                        => 1.50,
        'Exception::Class'           => 1.12,
        'Exception::Class::DBI'      => 0.94,
        'Exporter::Tidy'             => 0.06,
        'File::Find::Rule'           => 0,
        'FSA::Rules'                 => 0.25,
        'HOP::Lexer'                 => 0.02,
        'HOP::Parser'                => 0.01,
        'HOP::Stream'                => 0.01,
        'JSON::Syck'                 => 0.05,
        'Lingua::EN::Inflect'        => 0,
        'List::Util'                 => 0,
        'List::MoreUtils'            => 0,
        'Locale::Maketext'           => 1.09,
        'MIME::Base64'               => 0,
        'MIME::Types'                => 1.14,
        'Data::UUID'                 => 0,
        'Regexp::Common'             => 2.119,
        'version'                    => 0.420,
        'Widget::Meta'               => 0.03,   # XXX Kill?
        'XML::Simple'                => 2.13,   # XXX Replace!
    },
    build_requires       => {
        'App::Info'                 => 0.48,
        'Cache::Cache'              => 1.04,
        'Class::Trait'              => 0.11,
        'DBD::SQLite'               => 1.12,
        'File::Path'                => 0,
        'Module::Build'             => 0.28,
        'Pod::Man'                  => 2.08,    # For utf8 Support.
        'Test::Class'               => 0.10,
        'Test::Differences'         => 0.47,
        'Test::Exception'           => 0.21,
        'Test::File'                => 1.08,
        'Test::File::Contents'      => 0.03,
        'Test::JSON'                => 0.01,
        'Test::MockModule'          => 0.04,
        'Test::More'                => 0.17,
        'Test::NoWarnings'          => 0.03,
        'Test::Output'              => 0.07,
        'Test::XML'                 => 0.07,
    },
);

$build->create_build_script;
