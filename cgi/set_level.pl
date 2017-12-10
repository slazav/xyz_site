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
  # get session from cookie or command line
  my ($sess, $id, $new_level);
  if ($usecgi){ 
    $sess = cookie('SESSION')   || '';
    $id        = param('id')    || '';
    $new_level = param('level') || '';
  }
  else {
    $sess      = $ARGV[0] || '';
    $id        = $ARGV[1] || '';
    $new_level = $ARGV[2] || '';
  }
  die "session is missing" unless $sess;

  # open user database
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $users = $db->get_collection( 'users' );

  # check permissions
  my $u1 = $users->find_one({'sess'=>$sess});
  die "can't find user1" unless defined $u1;
  die "user1 level is too low" if $u1->{level} <= $LEVEL_NORM;

  my $u2 = $users->find_one({'_id'=>$id}, {'sess'=>0});
  die "can't find user2" unless defined $u2;

  die "can't change level" if $u1->{level} <= $u2->{level} ||
                              $new_level < $LEVEL_ANON  ||
                              $new_level > $LEVEL_ADMIN ||
                              $u1->{level} <= $new_level;

  my $u = $users->find_one_and_update(
         {'_id' => $id}, {'$set' => {'level' => $new_level}});
  die "Can't update user in the database" unless $u;

  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->encode({"ret" => 0}), "\n";
}
catch {
  chomp;
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
