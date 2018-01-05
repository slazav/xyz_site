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
  # read collection name
  my $coll  = param('coll')||'news';

  # start building an object, get _id
  my $obj;
  $obj->{_id} = param('id')||'';

  # collection-specific parameters:
  if ($coll eq 'news') {
    $obj->{title} = decode utf8=>(param('title')||'');
    $obj->{text}  = decode utf8=>(param('text')||'');
    $obj->{type}  = decode utf8=>(param('type')||'');
  }
  else {
    die "uncnown collection: $coll";
  }

  # write the object
  write_object undef, $coll, $obj;

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->encode({"ret" => 0}), "\n";
}
catch {
  chomp;
  write_log($obj_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
