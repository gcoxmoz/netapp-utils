#!/usr/bin/perl -wT
#
# gcox@mozilla
#
use strict;
use Getopt::Long;
$ENV{'PATH'} = '';  # Taint-check safety

#
# Designed to report issues with NetApp junction mounts
# Can't use the usual nagios check, since the mounts don't appear in fstab or conventional df.
#
# Caveat: any subvol which goes unused is auto-unmounted and thus unchecked.
# Of course, if you're not using something, it's hard to fill it up, so, who cares.
#

my $help           = 0;
my $warning_level  = 91;
my $critical_level = 95;
#
# Edging high here; these percentages are aimed at 91 and 95 so that
# standard monitoring will have a chance to light off at 90 and let the
# storage team have a shot at catching it before it goes into paging
# the oncall.
#
my $check_inodes   = 0;
# 
# default to false on inodes because it's a doubly-expensive check
# when you plow down through a big messy series of junctions,
# and really not an issue that most people will run into.
# But still, make it an option.
#

my $usage =<<"EOF";
Usage: $0 [options] mountpath

  -w/--warning   warning  level percentage (default $warning_level)
  -c/--critical  critical level percentage (default $critical_level)
  --inodes       Check inodes              (default false)
EOF

GetOptions ('warning=i'  => \$warning_level,
            'critical=i' => \$critical_level,
            'inodes!'    => \$check_inodes,
            'help'       => \$help)
or die("Error in command line arguments\n");

if (!@ARGV) {
    print $usage;
    exit 3;
} elsif ($help) {
    print $usage;
    exit 3;
} elsif ($^O ne 'linux') {
    print "Depends on /proc/mounts, only designed to run on Linux.\n";
    exit 3;
}

my $unchecked_mountpath = shift @ARGV;
   $unchecked_mountpath =~ m#^(/[-/_a-zA-Z0-9]+)#;  #Could be overrestrictive, but, avoiding dangerous input
my $mountpath = $1;
if (!$mountpath) {
    print "Didn't safely regex-match a mount path.  Funky character in the name?\n";
    exit 3;
} elsif (!(-d $mountpath)) {
    print "$mountpath is not a directory.\n";
    exit 3;
}

my $overall_exit_code = 0;
sub set_exit_code_warning () {
    $overall_exit_code = 1 if ($overall_exit_code < 1);
}
sub set_exit_code_critical () {
    $overall_exit_code = 2 if ($overall_exit_code < 2);
}

my $insane_percentage = 1001+int(rand(100));
my @mounts = ();
open  PROCMOUNTS, '</proc/mounts' or die "Can't open /proc/mounts: $!\n";
foreach my $line (<PROCMOUNTS>) {
    next unless ($line =~ m#^\S+\s+($mountpath\S*)\s#);
    push @mounts, $1;
}
close PROCMOUNTS or die "Can't close /proc/mounts: $!\n";


# Sample:
# Filesystem         1024-blocks      Used Available Capacity Mounted on
# server:/some/dir 689944080 387792528 246956016      62% /mnt/point
sub df_mount($$) {
    my ($fs, $space_or_inodes, ) = @_;
    my %df_commands = (
        'space'  => ['/bin/df', '-kP',],
        'inodes' => ['/bin/df', '-iP',],
    );
    die "Unexpected argument passed to df_mount.\n" if (!exists $df_commands{$space_or_inodes});
    my $df_ref = $df_commands{$space_or_inodes};
    my $percent = $insane_percentage;

    # If something inside this block will die(), then we will
    # count the test attempt as failed.

    eval {

      sub pipe_from_fork ($) {
          my $parent = shift;
          no strict 'refs';
              pipe $parent, my $child or die;
          use strict 'refs';
          my $pid = fork();
          die "fork() failed: $!" unless defined $pid;
          if ($pid) {
              close $child;
          } else {
              close $parent;
              open(STDOUT, '>&=' . fileno($child)) or die;
          }
          $pid;
      }

      if (my $pid = pipe_from_fork('BAR')) {
          # parent
          local $SIG{ALRM} = sub { kill 'TERM', $pid; die "df timed out.\n" };
          alarm(15);
          my $header_for_throwaway = <BAR>;
          my $line = <BAR>;
          close(BAR);
          alarm 0;
          my @data = split m#\s+#, $line;
          my ($export, $blocks, $bused, $bavail, $percent_in, $mount, ) = @data;
          $percent_in =~ s#%$##;
          $percent = $percent_in;
      } else {
          # child
          exec(@$df_ref, $fs);
          exit(0);
      }

    };

  return $percent;
}


# main
my @things_to_check = ('space');
push(@things_to_check, 'inodes') if ($check_inodes);

my %data = ();
SPACETYPE: foreach my $space_type (@things_to_check) {
    MOUNTS: foreach my $mount (sort @mounts) {
        my $percentage = df_mount($mount, $space_type);
        if ($percentage == $insane_percentage) {
            set_exit_code_critical();
            $data{$space_type}{2}{$mount} = 'HUNG';
            # as soon as something hangs, bail out, because otherwise we're
            # just piling on the problems and heading for a timeout on nagios
            # which could end up masking the actual problem.
            # We're going to underreport the problem, but at least we'll get attention.
            last SPACETYPE; # EJECT EJECT EJECT
        } elsif ($percentage > $critical_level) {
            set_exit_code_critical();
            $data{$space_type}{2}{$mount} = $percentage.'%';
        } elsif ($percentage > $warning_level) {
            set_exit_code_warning();
            $data{$space_type}{1}{$mount} = $percentage.'%';
        }
    }
}

my $out_message = "Junctions under $mountpath OK.\n";
if ($overall_exit_code != 0) {
    $out_message = $mountpath.' junctions';
    foreach my $space_type (@things_to_check) {
        if ($data{$space_type}) {
            # subtle design issue here: if you have one critcal and 50 warnings, you only see the one critical item.
            $out_message .= ' ('.$space_type.'): '.join(' ', map {$_.':'.$data{$space_type}{$overall_exit_code}{$_}} sort keys %{$data{$space_type}{$overall_exit_code}});
        }
    }
    $out_message .= "\n";
}

print $out_message;
exit $overall_exit_code;

