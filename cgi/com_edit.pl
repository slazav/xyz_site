#!/usr/bin/perl

################################################

use strict;
use warnings;
use Try::Tiny;
use CGI ':standard';
use JSON;
use site;
use common;
use open ':std', ':encoding(UTF-8)';
use Encode;

################################################

try {
  my $com = {};
  $com->{_id}       = param('id') || 0;
  $com->{title}     = decode utf8=>param('title') || '';
  $com->{text}      = decode utf8=>param('text')  || '';

  edit_comment(undef, $com);

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->encode({"ret" => 0}), "\n";
}
catch {
  chomp;
  write_log($obj_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}