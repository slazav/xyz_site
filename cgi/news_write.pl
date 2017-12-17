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
use safe_html;


################################################

try {

  my $sess = get_session();
  my $text;
  $text->{title} = cleanup_txt(param('title')||'', 1000);
  $text->{text}  = cleanup_htm(param('text')||'', 10000);
  $text->{type}  = cleanup_txt(param('type')||'',   100);

  write_object $sess, 'news', $text;

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->encode({"ret" => 0}), "\n";
}
catch {
  chomp;
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
