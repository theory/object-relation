use strict;
use 5.008003;
use lib 'lib';
use Kinetic::Build;

my $skipper = qr/^lib.Kinetic.(?:Build|DateTime|Format|Meta|Store|View|UI|Util)/;
my $build = Kinetic::Build->new(
    module_name          => 'Kinetic',
    license              => 'gpl',
    create_makefile_pl   => 'passthrough',
    build_class          => 'Kinetic::Build',
    dist_author          => 'Kineticode, Inc. <info@kineticode.com>',
    recursive_test_files => 1,
    schema_skipper       => $skipper,
    requires             => {
        'aliased'                    => 0.11,
        'Array::AsHash'              => 0.12,
        'Class::Delegator'           => 0.04,
        'Class::Meta'                => 0.49,
        'Clone'                      => 0.15,
        'Data::Pageset'              => 1.01,
        'Data::UUID'                 => 0.11,
        'DateTime'                   => 0.24,
        'DateTime::Format::Strptime' => 1.0601,
        'DateTime::Incomplete'       => 0.02,
        'DBD::Pg'                    => 1.32, # XXX Change to option. Only included during development
        'DBD::SQLite'                => 1.09, # XXX Change to option.
        'DBI'                        => 1.43,
        'Exception::Class'           => 1.12,
        'Exception::Class::DBI'      => 0.92,
        'Exporter::Tidy'             => 0.06,
        'HOP::Lexer'                 => 0.01,
        'HOP::Parser'                => 0.01,
        'HOP::Stream'                => 0.01,
        'JSON'                       => 1.00,
        'Lingua::Strfname'           => 0.10,
        'List::Util'                 => 0,
        'Locale::Maketext'           => 1.09,
        'Params::Validate'           => 0.78,
        'Readonly'                   => 0,
        'Regexp::Common'             => 2.119,
        'version'                    => 0.420,
        'Widget::Meta'               => 0.03,
        'WWW::REST'                  => 0.01,
        'XML::Genx::Simple'          => 0.14,
        'XML::LibXML'                => 1.58,
        'XML::LibXSLT'               => 1.57,
        'XML::Simple'                => 2.13,
    },
    build_requires       => {
        'App::Info'                  => 0.42,
        'FSA::Rules'                 => 0.21,
        'HTTP::Server::Simple'       => 0.13,
        'Module::Build'              => 0.26,
        'Test::Class'                => 0.10,
        'Test::Differences'          => 0.47,
        'Test::Exception'            => 0.21,
        'Test::File'                 => 1.08,
        'Test::File::Contents'       => 0.02, # XXX Update if OS patch applied.
        'Test::JSON'                 => 0.01,
        'Test::MockModule'           => 0.04,
        'Test::More'                 => 0.17,
        'Test::Output'               => 0.07,
        'Test::Pod'                  => 1.06, # this is recommended, not required.
        'Test::Pod::Coverage'        => 0.08, # this is recommended, not required.
        'Test::WWW::Mechanize'       => 1.06,
        'Test::XML'                  => 0.07,
        'WWW::Mechanize'             => 1.16, # force Test::WWW::Mech to use the faster Mechanize
        'XML::XPath'                 => 1.13,
    },
);

$build->create_build_script;
