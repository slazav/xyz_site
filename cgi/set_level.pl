#!/usr/bin/perl

# Change user level
#
# Input  -- cookie:session
#           param:id    -- user2 id
#           param:level -- user2 new level
#  - user1 level should be > LEVEL_NORM
#  - user1 level should be > user2 level
#  - user1 level should be > user2 new level
#
# Output -- all users from "users" database
#   - fields "sess", "info" are removed
#   - field "me"=1 added for the caller

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
  my $id        = param('id')    || '';
  my $new_level = param('level') || '';
  my $ret = set_user_level(undef, $id, $new_level);

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->encode($ret), "\n";
}
catch {
  chomp;
  write_log($usr_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
