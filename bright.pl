#!/usr/bin/perl

use strict;
use warnings;

my $fileName = "darker.bmp";
#$fileName = "lighter.bmp";

open BMPFILE, "<:raw", $fileName or die "Couldn't open $fileName!";

my $sum = 0;

my $i;

for($i = 0; read(BMPFILE, my $byte, 1); $i++) {
    $sum += ord $byte;
}

print $sum / $i / 256  . "\n";
