#!/usr/bin/perl

# Logout CGI script.
# Remove session from the database, reset cookie.
# Log information and errors into $site_wwwdir/logs/login.txt.

################################################

use strict;
use warnings;
use MongoDB;
use Try::Tiny;
use CGI         ':standard';
use JSON;
use site;
use common;
use open ':std', ':encoding(UTF-8)';

################################################

try {
  # open user database
  my $db = open_db;
  my $sess = get_session();

  my $users = $db->get_collection( 'users' );
  my $u = $users->find_one_and_update({'sess'=>$sess},
     {'$set' => {'sess' => ''} });
  die "Can't find and update user in the database" unless $u;

  write_log($usr_log, "Logout OK: $u->{name} @ $u->{site} ($u->{_id})");

  #unset cookie
  my $cookie = cookie(-name=>'SESSION', -value=>'', -expires=>'-1s', -host=>$site_url);
  print header (-type=>'application/json', -charset=>'utf-8', -cookie=>$cookie);
  print JSON->new->encode({"ret" => 0}), "\n";
}
catch {
  chomp;
  write_log($usr_log, "$0 error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
