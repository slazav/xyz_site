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
  my $pars = { id=>param('id') || '' };
  my $o = show_object(undef, 'news', $pars);
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->pretty()->encode($o), "\n";
}
catch {
  chomp;
  write_log($obj_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
