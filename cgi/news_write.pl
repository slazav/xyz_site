#!/usr/bin/perl

################################################

use strict;
use warnings;
use Try::Tiny;
use CGI ':standard';
use JSON;
use site;
use common;
use safe_html;


################################################

try {
  my $obj;
  $obj->{title} = cleanup_txt(param('title')||'');
  $obj->{text}  = cleanup_htm(param('text')||'');
  $obj->{type}  = cleanup_txt(param('type')||'');

  my $db = open_db;
  my $u  = get_my_info($db);

  write_object undef, 'news', $obj;

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->encode({"ret" => 0}), "\n";
}
catch {
  chomp;
  write_log($obj_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
