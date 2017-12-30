#!/usr/bin/perl

# Login CGI script.
# Get code, ask for access token and then for user information.
# Create a session, set cookie, put information into DB.
# if RETPAGE cookie is set, redirect to this page, otherwise
# return json with ret:0 or with ret:1 and error_message set.
# Log information and errors into $site_wwwdir/logs/login.txt.
#
# User object in the database:
#  _id   - user identity (unique)
#  level - user level (-1..3)
#  sess  - session
#  mtime - time of last login
#  ctime - time of first login
#  name  - user name
#  site  - identity provider (fb, google, etc.)
#  info  - original info from the provider

################################################

use strict;
use warnings;
use MongoDB;
use Try::Tiny;
use Digest::MD5 'md5_hex';
use CGI         ':standard';
use HTTP::Tiny;
use JSON;
use site;
use common;
use open ':std', ':encoding(UTF-8)';

################################################

my $ret  = cookie('RETPAGE') || '';
try {

  my $hh = $ENV{'REMOTE_HOST'} || "";
  my $aa = $ENV{'REMOTE_ADDR'} || "";
  write_log($usr_log, "Login script called from: $hh ($aa)");
  my ($id, $name, $site, $info);

  ######## GOOGLE login ########
  if ($0 =~ /login_google.pl$/){

    # get token from CGI or command line
    my $code = param('code') || '';
    my $err  = param('error_message') || '';

    die $err if $err;
    die "Code is missing" unless $code;

    # get access tocken from google
    my $http = HTTP::Tiny->new();
    my $url = "https://accounts.google.com/o/oauth2/token";
    my $post_data = {
      'client_id'     => $google_id,
      'client_secret' => $google_secret,
      'redirect_uri'  => "$site_url/cgi/login_google.pl",
      'grant_type'    => 'authorization_code',
      'code'          => $code
    };
    $info = $http->post_form($url, $post_data)->{content};
    write_log($usr_log, "Get Google token: $info");
    my $data  = decode_json $info;
    my $token = $data->{access_token};
    die "Can't get access tocken from Google" unless $token;

    # get user information
    $post_data->{access_token} = $token;
    $url = "https://www.googleapis.com/oauth2/v1/userinfo?" .
           $http->www_form_urlencode($post_data);
    $info = $http->get($url)->{content};
    write_log($usr_log, "Get Google userinfo: $info");
    $data  = decode_json $info;

    die $data->{error}->{message} if $data->{error} && $data->{error}->{message};
    $name = $data->{name};
    $id   = $data->{link};
    $site = 'google';
  }

  ######## FACEBOOK login ########
  elsif ($0 =~ /login_fb.pl$/) {
    # get token from CGI or command line
    my $code = param('code') || '';
    my $err  = param('error_message') || '';

    die $err if $err;
    die "Code is missing" unless $code;

    # get access tocken from facebook
    # create an URL for facebook.ru
    my $http = HTTP::Tiny->new();
    my $test_url = "https://graph.facebook.com/oauth/access_token?".
                   "client_id=$facebook_id&client_secret=$facebook_secret&".
                   "redirect_uri=$site_url/cgi/login_fb.pl&".
                   "code=$code&scope=public_profile";
    $info = $http->get($test_url)->{content};
    write_log($usr_log, "Get Facebook token: $info");
    my $data  = decode_json $info;
    my $token = $data->{access_token};
    die "Can't get access tocken from facebook" unless $token;

    # get user information
    $test_url = "https://graph.facebook.com/me?".
                "access_token=$token";
    $info = $http->get($test_url)->{content};
    write_log($usr_log, "Get Facebook userinfo: $info");
    $data  = decode_json $info;
    $name = $data->{name};
    $id   = "https://www.facebook.com/$data->{id}";
    $site = 'fb';
  }

  ######## LOGINZA login ########
  elsif ($0 =~ /login_loginza.pl$/) {
    my $token = param('token') || '';
    die "Token is missing" unless $token;

    # create an URL for loginza.ru
    my $sig = md5_hex($token.$loginza_secret);
    my $test_url = "http://loginza.ru/api/authinfo?".
                   "token=$token&id=$loginza_id&sig=$sig";

    # ask loginza about this token
    my $http = HTTP::Tiny->new();
    $info=$http->get($test_url)->{content};
    write_log($usr_log, "Loginza: $info");
    my $data  = decode_json $info;

    # die on error
    die "$data->{error_type} error: $data->{error_message}"
      if exists($data->{error_type});

    # find site and user name, user identity:
    $id   = $data->{identity} || '';
    $name = '';
    $site = '';

    my $n1 = $data->{name}->{first_name} || '';
    my $n2 = $data->{name}->{last_name}  || '';
    my $n3 = $data->{name}->{full_name}  || '';
    if ($n3 ne '') {$name = $n3;}
    elsif ($n1 ne '' && $n2 ne '') {$name = $n1.' '.$n2;}
    elsif ($n2 ne '') {$name = $n2;}
    elsif ($n1 ne '') {$name = $n1;}

    $id =~ s|www.facebook.com/app_scoped_user_id|www.facebook.com|;
    if ($id =~ m|www.facebook.com|){ $site='fb';}
    if ($id =~ m|www.google.com|)  { $site='google';}
    if ($id =~ m|plus.google.com|) { $site='gplus';}
    if ($id =~ m|openid.yandex.ru|){ $site='yandex';}
    if ($id =~ m|vk.com|)          { $site='vk';}
    if ($id =~ m|^https?://([^\.]+).livejournal.com|){ $site = 'lj'; $name = $1;}
  }
  else {
    die "Unknown login provider";
  }

  #### now we have user information
  # die on error
  die "Not enough user information"
    if $id eq '' || $name eq '' || $site eq '';

  write_log($usr_log, "User: $name @ $site ($id)");

  # create a session
  sub rndStr{ join '', @_[ map{ rand @_ } 1 .. shift ] }
  my $sess = rndStr(25, 'A'..'Z', '0'..'9');

  # open user database
  my $db = open_db();
  my $users = $db->get_collection( 'users' );

  # put information into the database
  if ($users->count({'_id' => $id})){
    # if user exists just update session and information from loginza
    my $u = $users->find_one_and_update({'_id' => $id}, {'$set' => {
      'sess' => $sess,
      'mtime'=> time,
      'name' => $name,
      'site' => $site,
      'info' => $info,
    }});
    die "Can't find and update user in the database" unless $u;
  }
  else {
    # create new user
    # level is set to SUPER for the first user, NORM for normal user
    my $level = ($users->count())? $LEVEL_NORM:$LEVEL_SUPER;
    my $res = $users->insert_one({
      '_id'   => $id,
      'level'=> $level,
      'sess' => $sess,
      'mtime'=> time,
      'ctime'=> time,
      'name' => $name,
      'site' => $site,
      'info' => $info,
    });
    die "Can't put user into the database"
      unless $res->acknowledged;
  }
  #set cookie
  my $cookie = cookie(-name=>'SESSION', -value=>$sess,
                      -expires=>'+1y', -host=>$site_url) if $sess;

  write_log($usr_log, "Login OK");

  # redirect if needed
  if ($ret){ print redirect (-uri=>$ret, -cookie=>$cookie); }
  else {
    print header (-type=>'application/json', -charset=>'utf-8', -cookie=>$cookie);
    print JSON->new->encode({"ret" => 0}), "\n";
  }
}
catch {
  chomp;
  write_log($usr_log, "$0 error: $_");
  if ($ret){ print redirect (-uri=>$ret); }
  else {
    print header (-type=>'application/json', -charset=>'utf-8');
    print JSON->new->canonical()->encode(
       {"ret" => 1, "error_message" => "Authentication error"}), "\n";
  }
}

