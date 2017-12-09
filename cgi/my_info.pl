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

my $logf = "$site_wwwdir/logs/login.txt";

################################################

try {
  # get session from cookie or command line
  my $sess;
  if ($usecgi){ $sess = cookie('SESSION') || ''; }
  else { $sess = $ARGV[0] || ''; }
  unless ($sess){
    print header (-type=>'application/json', -charset=>'utf-8');
    print "{}\n";
    exit 1;
  }

  # open user database
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $users = $db->get_collection( 'users' );

  my $u = $users->find_one({'sess'=>$sess}, { 'sess' => 0, 'info' => 0 });
  die "Can't find user in the database" unless $u;

  #unset cookie
  my $ret= JSON->new->encode($u);
  print header (-type=>'application/json', -charset=>'utf-8');
  print $ret, "\n";
}
catch {
  chomp;
  write_log($logf, "Myinfo error: $_");
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
