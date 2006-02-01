#!/usr/bin/perl

use strict;
use warnings;

use File::Find;
$|++;

my @dirs       = qw(lib/ t/);
my $file_count = 0;
find( \&wanted, @dirs );

my %subs;
my @counts;
while ( my ( $k, $v ) = each %subs ) {
    push @counts => [ $v, $k ];
}

@counts = sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } @counts;
foreach my $count (@counts) {
    printf "%3d : $count->[1]\n", $count->[0];
}

printf "Started at %s\n", scalar localtime;
find( \&used, @dirs );
printf "Ended at %s\n", scalar localtime;
@counts = ();
while ( my ( $k, $v ) = each %subs ) {
    push @counts => [ $v, $k ];
}

@counts = sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } @counts;
foreach my $count (@counts) {
    printf "%3d : $count->[1]\n", $count->[0];
}

my $curr_file = 0;

sub used {
    my $file = $_;
    return unless $file =~ /\.pm$/;
    return if /#/;    # ignore backup files
    my $fh;
    unless ( open $fh, '<', $file ) {
        warn "Could not open $file for reading: $!";
        return;
    }
    $curr_file++;
    print "Checking $file.  $curr_file out of $file_count\n";
    my @found = ();
    while ( defined( my $line = <$fh> ) ) {
        foreach my $sub ( keys %subs ) {
            next if $line =~ /sub\s+$sub/;
            next if $line =~ /^\s*#/;        # skip comments
            push @found => $sub if $line =~ /$sub/;
        }
    }
    delete @subs{@found};   # if we have found them, this is a huge perf boost
}

sub wanted {
    return unless /\.pm$/;
    return if $File::Find::name =~ /TEST/;       # skip test modules
    return if /#/;          # ignore backup files
    my $file = $_;
    my $fh;
    unless ( open $fh, '<', $file ) {
        warn "Could not open $file for reading: $!";
        return;
    }
    $file_count++;
    while ( defined( my $line = <$fh> ) ) {
        if ( $line =~ /sub\s+(\w+)\s+/ ) {
            my $sub = $1;
            next if $sub =~ /^ACTION/;
            $subs{$sub} = 0;
        }
    }
}
