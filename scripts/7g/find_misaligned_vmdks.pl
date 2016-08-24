#!/usr/bin/perl -w
use strict;

#
# This is an awful / old script from the 7G world.  Back when nfsstat -d
# existed and could help you find misaligned VMs.
#
# Now there are 'recommended' ways to fix this with VSC, and most sane
# non-debian installs don't run afoul anymore.  But, just in case I'm
# ever in the situation again...
#

my $filer = shift || die "$0 FILERNAME\n";
my $magicword = 'FLOOBER'; # A nonsense word to buffer our sorting later

my %skips = (
  'sitename' => [ 'deliberate-misaligned1.mysite.com', ],
);

open (SSH, 'ssh root@'.$filer.' nfsstat -d |');
my $site = $filer;  # you probably want to do something smarter here.
die "Administrative failure, unable to determine site.\n" if (!$site);
my %skip = map { $_ => 1 } @{$skips{$site}};
my %data = ();
while (my $line = <SSH>) {
  next unless ($line =~ m#^\[Counter=(\d+)\]#);
  my $counter = $1;
  if ($line =~ m#Filename=(\S+)#) {
    my $filename = $1;
    $filename =~ m#/([^/]+)/#;
    my $host = $1;
    next if ($skip{$host});
    $data{$magicword}{$filename} += $counter;
  } elsif ($line =~ m#FSID=(\d+)#) {
    my $fsid = $1;
    $line =~ m#Fileid=(\d+)#;
    $data{$fsid}{$1} += $counter;
  } else {
    die "FIXME: unexpected line from filer $filer:\n$line\n";
  }
}
close SSH;

my $kl = 4; my $vl = 10;
foreach my $key (keys %{$data{$magicword}}) {
  my $val = $data{$magicword}{$key};
  $kl = length($key) if (length($key) > $kl);
  $vl = length($val) if (length($val) > $vl);
}

foreach my $key (sort {$data{$magicword}{$b} <=> $data{$magicword}{$a} } keys %{$data{$magicword}}) {
  printf "%-*s  %*d\n", $kl, $key, $vl, $data{$magicword}{$key};
}

delete $data{$magicword};
foreach my $key1 (sort keys %data) {
  foreach my $key2 (sort keys %{$data{$key1}}) {
    printf "%-*s  %*d\n", $kl, "VOL $key1 FILE $key2", $vl, $data{$key1}{$key2};
  }
}
