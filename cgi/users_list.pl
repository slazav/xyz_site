#!/usr/bin/perl

# Get user list in JSON.
#
# Input  -- session
#  user level should be >=LEVEL_MODER
#
# Output -- all users from "users" database
#   - fields "sess", "info" are removed
#   - field "me"=1 added for the caller
#   - if the caller can set user level then field "level_hints"
#     is added with with possible level values

################################################

use FindBin;
use lib $FindBin::Bin;

use strict;
use warnings;
use MongoDB;
use Try::Tiny;
use CGI         ':standard';
use JSON;
use site; # $secret $widget_id %test_users $myhost
use common;

################################################

try {
  my $ret = user_list();
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->pretty()->encode($ret), "\n";
}
catch {
  chomp;
  write_log($usr_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
