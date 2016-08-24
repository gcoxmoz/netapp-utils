#!/usr/bin/perl -w
#
# gcox@mozilla
#
use strict;

#
# Against a cDOT filer, jump in (assuming you have keys) as the cluster admin
# find which data aggrs are oversubscribed and by how much
#

my $filer = shift or die "Which filer?\n";
chomp $filer;

open (AGS, 'ssh admin@'.$filer.' aggr show -fields aggregate -has-mroot false |');
<AGS>;
<AGS>;
my @aggrs;
while (<AGS>) {
  last if (m#were displayed#);
  s#\s*\r?\n$##;
  push @aggrs, $_;
}
close AGS;

foreach my $aggr (@aggrs) {
   my %data = ();
   my $cmd = '';

   $cmd = 'ssh admin@'.$filer.' "set -units gb ; aggr show -aggregate '.$aggr.' -fields size"';
   open (CMD1, $cmd.'|');
   foreach my $line (<CMD1>) {
     next unless ( $line =~ m#$aggr\s+([0-9]+)GB\b# );
     $data{$aggr}{'agsize'} = $1;
     last;
   }
   close CMD1;

   $data{$aggr}{'volsize'} = 0;
   $cmd = 'ssh admin@'.$filer.' "set -units gb ; volume show -aggregate '.$aggr.' -fields size"';
   open (CMD2, $cmd.'|');
   foreach my $line (<CMD2>) {
     next unless ( $line =~ m#.*\s+([0-9]+)GB\b# );
     $data{$aggr}{'volsize'} += $1;
   }
   close CMD2;
   my $overage = $data{$aggr}{'volsize'} - $data{$aggr}{'agsize'};
   my $amt = abs($overage);
   my $warning = (($overage > 0) ? 'OVER ' : 'under'). ':';
   my $ratio = int($data{$aggr}{'volsize'} * 10000 / $data{$aggr}{'agsize'}) / 100 ;
   printf "%-30s \tAg: %7iGB\tVols: %7iGB\t%-6s %7iGB (%6.2f%%)\n", $aggr, $data{$aggr}{'agsize'}, $data{$aggr}{'volsize'}, $warning, $amt, $ratio ;
}
