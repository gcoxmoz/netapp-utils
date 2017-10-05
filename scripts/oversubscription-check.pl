#!/usr/bin/perl -w
#
# gcox@mozilla
#
use strict;
use warnings;

#
# Against a cDOT filer, jump in (assuming you have keys) as the cluster admin
# find which data aggrs are oversubscribed and by how much
#

my $filer = shift or die "Which filer?\n";
chomp $filer;

open (my $ags_fh, '-|', 'ssh admin@'.$filer.' aggr show -fields aggregate -has-mroot false') or die "Can't open a command pipe for aggr show: $!\n";
<$ags_fh>;
<$ags_fh>;
my @aggrs;
while (<$ags_fh>) {
   last if (m#were displayed#);
   s#\s*\r?\n$##;
   push @aggrs, $_;
}
close $ags_fh;

foreach my $aggr (@aggrs) {
    my %data = ();
    my $cmd = '';

    $cmd = 'ssh admin@'.$filer.' "set -units gb ; aggr show -aggregate '.$aggr.' -fields size"';
    open (my $cmd1_fh, '-|', $cmd) or die "Can't open a command pipe for '$cmd': $!\n";
    while (my $line = <$cmd1_fh>) {
        if ( $line =~ m#$aggr\s+([0-9]+)GB\b# ) {
            $data{$aggr}{'agsize'} = $1;
            last;
        }
    }
    close $cmd1_fh;

    $data{$aggr}{'volsize'} = 0;
    $cmd = 'ssh admin@'.$filer.' "set -units gb ; volume show -aggregate '.$aggr.' -fields size"';
    open (my $cmd2_fh, '-|', $cmd) or die "Can't open a command pipe for '$cmd': $!\n";
    while (my $line = <$cmd2_fh>) {
        if ( $line =~ m#.*\s+([0-9]+)GB\b# ) {
            $data{$aggr}{'volsize'} += $1;
        }
    }
    close $cmd2_fh;
    my $overage = $data{$aggr}{'volsize'} - $data{$aggr}{'agsize'};
    my $amt = abs($overage);
    my $warning = (($overage > 0) ? 'OVER ' : 'under'). ':';
    my $ratio = int($data{$aggr}{'volsize'} * 10000 / $data{$aggr}{'agsize'}) / 100 ;
    printf "%-30s \tAg: %7iGB\tVols: %7iGB\t%-6s %7iGB (%6.2f%%)\n", $aggr, $data{$aggr}{'agsize'}, $data{$aggr}{'volsize'}, $warning, $amt, $ratio ;
}
