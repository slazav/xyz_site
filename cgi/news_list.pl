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
  my $pars = { skip => param('skip') || 0,
               num  => param('num') || 0 };
  my $res = list_objects(undef, 'news', $pars);
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->pretty()->encode($res), "\n";
}
catch {
  chomp;
  write_log($obj_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
