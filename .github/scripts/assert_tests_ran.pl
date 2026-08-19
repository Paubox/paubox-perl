#!/usr/bin/env perl
# Fail CI when a passing prove run does not mean the suite ran.
#
# prove reports PASS for a file whose tests were all skipped. t/Paubox_Email_SDK.t
# skips its entire class without config.cfg, so "Result: PASS" can mean zero
# assertions were executed. This counts assertions that actually ran.
use strict;
use warnings;

# Floor, not a target. Only trips if coverage regresses; adding tests is free.
my $MIN_RUN = 80;

my $file = shift or die "usage: $0 <tap-output-file>\n";
open my $fh, '<', $file or die "cannot read $file: $!\n";

my ($total, $skipped, $failed) = (0, 0, 0);
while (my $line = <$fh>) {
    if ($line =~ /^not ok \d+/)          { $total++; $failed++ }
    elsif ($line =~ /^ok \d+.*#\s*skip/i){ $total++; $skipped++ }
    elsif ($line =~ /^ok \d+/)           { $total++ }
}
close $fh;

my $run = $total - $skipped;
printf "assertions=%d run=%d skipped=%d failed=%d\n", $total, $run, $skipped, $failed;

my @problems;
push @problems, "$failed failing assertion(s)" if $failed;
push @problems, "only $run assertion(s) actually ran, expected at least $MIN_RUN"
    if $run < $MIN_RUN;

if (@problems) {
    print STDERR "FAIL: " . join('; ', @problems) . "\n";
    exit 1;
}

print "OK: $run assertions ran ($skipped skipped)\n";
