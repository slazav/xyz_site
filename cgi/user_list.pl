#!/usr/bin/perl

# Get user list.
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
  my $sess;
  if ($usecgi){ $sess = cookie('SESSION') || ''; }
  else { $sess = $ARGV[0] || ''; }
  die "session is missing" unless $sess;

  # open user database
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $users = $db->get_collection( 'users' );

  # check permissions
  my $u = $users->find_one({'sess'=>$sess});
  die "can't find user level" unless defined $u->{level};
  die "user level is too low" if $u->{level} <= $LEVEL_NORM;

  # collect information into array
  my $query_result = $users->find({}, {'projection' => {'sess'=>0, 'info'=>0}})->result;
  my $res=[];
  while ( my $next = $query_result->next ) {

    # add "me" field
    $next->{me}=1 if $next->{_id} eq $u->{_id};

    # add level_hints: how can I change the level
    if ($u->{level}>$LEVEL_NORM && $next->{level} < $u->{level}){
      $next->{level_hints} = [];
      for (my $j=$LEVEL_ANON; $j < $u->{level}; $j++){
        last if $j > $LEVEL_ADMIN;
        push @{$next->{level_hints}}, $j;
      }
    }
    push @{$res}, $next;
  }

  my $ret = JSON->new->encode($res);
  print header (-type=>'application/json', -charset=>'utf-8');
  print $ret, "\n";
}
catch {
  chomp;
  print header (-type=>'application/json', -charset=>'utf-8');
  print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
}
