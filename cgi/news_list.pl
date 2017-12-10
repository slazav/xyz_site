#!/usr/bin/perl

################################################

use strict;
use warnings;
use Try::Tiny;
use CGI ':standard';
use JSON;
use site;
use common;
use objects;


################################################

try {
  my $o = list_objects('news', param('skip') || '', param('limit') || '');

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode($o), "\n";
}
catch {
  chomp;
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
