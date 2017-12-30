#!/usr/bin/perl

# Get user information.
# Input  -- session
# Output 
#  -- user information in json (without fields sess, info)
#  -- empty json if no session is provided
#  -- json with ret:1 and error_message in case of an error
# Log errors into $site_wwwdir/logs/login.txt.

################################################

use strict;
use warnings;
use MongoDB;
use Try::Tiny;
use CGI ':standard';
use JSON;
use site;
use common;
use open ':std', ':encoding(UTF-8)';

################################################

try {
  my $ret = get_my_info() || {};

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->pretty()->encode($ret), "\n";
}
catch {
  chomp;
  write_log($usr_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
