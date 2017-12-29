#!/usr/bin/perl
use strict;
use site;
use CGI   ':standard';

my $dfile="$site_wwwdir/data/stat.txt";

my ($S, $M, $H, $d, $m, $Y) = localtime;
my $t = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $Y+1900,$m+1,$d,$H,$M,$S;

my $msg  = param('msg') || '';
my $ip   = $ENV{REMOTE_ADDR} || '-';

open LOG, ">> $dfile";
print LOG "$t\t$ip\t$msg\n";
close LOG;

print <<EOF
Content-Type: text/html; charset=koi8-r

<html>
</html>
EOF
