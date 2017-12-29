#!/usr/bin/perl

################################################

use strict;
use warnings;
use Try::Tiny;
use CGI ':standard';
use JSON;
use site;
use common;


################################################

try {
  my $res = list_objects(undef, 'news', param('skip') || 0, param('limit') || 0);
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->pretty()->encode($res), "\n";
}
catch {
  chomp;
  write_log($obj_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
