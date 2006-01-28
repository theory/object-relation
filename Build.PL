use strict;
use 5.008003;
use lib 'lib';
use Kinetic::Build;

my $skipper =
  qr/^lib.Kinetic.(?:Build|DateTime|Engine|Format|Meta|Store|UI|Util|View|XML)/;
my %catalyst => (
    'Catalyst'                                               => 5.61,
    'Catalyst::Engine::Apache'                               => 1.05,
    'Catalyst::Plugin::Authentication'                       => 0,
    'Catalyst::Plugin::Authentication::Store::Minimal'       => 0,
    'Catalyst::Plugin::Authentication::Credential::Password' => 0,
    'Catalyst::Plugin::Session'                              => 0,
    'Catalyst::Plugin::Session::Store::File'                 => 0,
    'Catalyst::Plugin::Session::Store::Memcached'            => 0.02,
    'Catalyst::Plugin::Session::State::Cookie'               => 0,
    'Catalyst::Plugin::Static::Simple'                       => 0,
);

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
        %catalyst,
        'Class::BuildMethods'        => 0.10,
        'Class::Delegator'           => 0.04,
        'Class::Meta'                => 0.52,
        'Class::Meta::Declare'       => 0.02,
        'Clone'                      => 0.15,
        'Config::Std'                => '0.0.2',
        'Data::Pageset'              => 1.01,
        'DateTime'                   => 0.30,
        'DateTime::Format::Strptime' => 1.0601,
        'DateTime::Incomplete'       => 0.02,
        'DBD::Pg'                    => 1.32,   # XXX Change to option.
        'DBD::SQLite'                => 1.09,   # XXX Change to option.
        'DBI'                        => 1.43,
        'Exception::Class'           => 1.12,
        'Exception::Class::DBI'      => 0.92,
        'Exporter::Tidy'             => 0.06,
        'File::Pid'                  => 1.01,
        'HOP::Lexer'                 => 0.02,
        'HOP::Parser'                => 0.01,
        'HOP::Stream'                => 0.01,
        'JSON::Syck'                 => 0.05,
        'LockFile::Simple'           => 0.205,
        'Lingua::Strfname'           => 0.10,
        'List::Util'                 => 0,
        'Locale::Maketext'           => 1.09,
        'MIME::Base64'               => 0,
        'MIME::Types'                => 1.14,
        'OSSP::uuid'                 => 0,      # XXX Not on CPAN!
        'Params::Validate'           => 0.78,
        'Proc::Background'           => 1.08,
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
        'Apache::FakeRequest'       => 1.00,
        'App::Info'                 => 0.42,
        'CGI'                       => 3.11,
        'Class::Trait'              => 0.11,
        'FSA::Rules'                => 0.21,
        'HTTP::Server::Simple'      => 0.13,
        'Module::Build'             => 0.26,
        'Pod::Man'                  => 2.04,    # Supports =encoding
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
        'Test::Pod'                 => 1.06,    # recommended, not required.
        'Test::Pod::Coverage'       => 0.08,    # recommended, not required.
        'Test::WWW::Mechanize'      => 1.06,
        'Test::XML'                 => 0.07,
        'WWW::Mechanize'            => 1.16,    # force the faster Mechanize
        'XML::XPath'                => 1.13,
    },
);

$build->create_build_script;
