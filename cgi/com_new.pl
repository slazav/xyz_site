#!/usr/bin/perl

################################################

use FindBin;
use lib $FindBin::Bin;

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
  my $com = {
    parent_id => param('parent_id') || 0,
    object_id => param('object_id') || 0,
    title     => decode(utf8=>param('title') || ''),
    text      => decode(utf8=>param('text')  || ''),
  };

  new_comment(undef, $com, param('coll') || 'news');

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->encode({"ret" => 0}), "\n";
}
catch {
  chomp;
  write_log($obj_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
