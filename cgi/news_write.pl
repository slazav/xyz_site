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
use open ':std', ':encoding(UTF-8)';
use Encode;

################################################

try {
  my $obj;
  $obj->{_id}   = param('id')||'';
  $obj->{title} = decode utf8=>(param('title')||'');
  $obj->{text}  = decode utf8=>(param('text')||'');
  $obj->{type}  = decode utf8=>(param('type')||'');

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
