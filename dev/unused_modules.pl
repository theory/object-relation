#!/usr/bin/perl

use strict;
use warnings;

use File::Find;

my %modules = (
    'App::Info'                  => 0,
    'CGI'                        => 0,
    'Class::BuildMethods'        => 0,
    'Class::Meta'                => 0,
    'Class::Meta::Express'       => 0,
    'Class::Trait'               => 0,
    'Clone'                      => 0,
    'Config::Std'                => 0,
    'DBD::Pg'                    => 0,
    'DBD::SQLite'                => 0,
    'DBI'                        => 0,
    'DateTime'                   => 0,
    'DateTime::Format::Strptime' => 0,
    'DateTime::Incomplete'       => 0,
    'Exception::Class'           => 0,
    'Exception::Class::DBI'      => 0,
    'Exporter::Tidy'             => 0,
    'FSA::Rules'                 => 0,
    'HOP::Lexer'                 => 0,
    'HOP::Parser'                => 0,
    'HOP::Stream'                => 0,
    'JSON::Syck'                 => 0,
    'Lingua::Strfname'           => 0,
    'List::Util'                 => 0,
    'Locale::Maketext'           => 0,
    'MIME::Base64'               => 0,
    'MIME::Types'                => 0,
    'Module::Build'              => 0,
    'OSSP::uuid'                 => 0,
    'Proc::Background'           => 0,
    'Readonly'                   => 0,
    'Regexp::Common'             => 0,
    'Test::Class'                => 0,
    'Test::Differences'          => 0,
    'Test::Exception'            => 0,
    'Test::File'                 => 0,
    'Test::File::Contents'       => 0,
    'Test::JSON'                 => 0,
    'Test::MockModule'           => 0,
    'Test::More'                 => 0,
    'Test::NoWarnings'           => 0,
    'Test::Output'               => 0,
    'Test::Pod'                  => 0,
    'Test::Pod::Coverage'        => 0,
    'Test::XML'                  => 0,
    'Widget::Meta'               => 0,
    'XML::Simple'                => 0,
    'aliased'                    => 0,
    'version'                    => 0,
);

my @dirs = qw(lib/ t/);
find( \&wanted, @dirs );

my @counts;
while ( my ( $k, $v ) = each %modules ) {
    push @counts => [ $v, $k ];
}

@counts = sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } @counts;
foreach my $count (@counts) {
    printf "%3d : $count->[1]\n", $count->[0];
}

sub wanted {
    my $file = $_;
    return unless $file =~ /\.(?:pm|t)$/;
    return if /#/;    # ignore backup files
    my $fh;
    unless ( open $fh, '<', $file ) {
        warn "Could not open $file for reading: $!";
        return;
    }
    my $code = do { local $/; <$fh> };
    foreach my $module ( keys %modules ) {

        $modules{$module}++ if $code =~ /$module/;
    }
}
