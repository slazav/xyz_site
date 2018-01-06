#!/usr/bin/perl
use strict;
use warnings;
use XML::Simple qw(:strict);
use POSIX qw(mktime);
use HTTP::Tiny;
use HTTP::Cookies;
use MongoDB;
use common;
use safe_html;

# import news from ljmigrate.py dump

my $database='test';
my $coll='news';
my $postsdir='./lj';

my $db = MongoDB->connect()->get_database( $database );
die "can't open db" unless $db;

#######################################
sub add_user{
  my $db = shift;
  my $uid  = shift;
  my $name = shift;
  my $site = shift;
  my $time = shift || 0;

  # try to find user, add one if it does not exists
  my $users = $db->get_collection( 'users' );
  my $u = $users->find_one({'_id'=>$uid});
  unless ($u) {
    print ">>>> Add user $uid: $name \@ $site\n";
    my $res = $users->insert_one({
      '_id'   => $uid,
      'level'=> $LEVEL_NORM+0,
      'mtime'=> $time+0,
      'ctime'=> $time+0,
      'name' => $name,
      'site' => $site,
      'info' => '',
    });
    die "Can't put user into the database"
      unless $res->acknowledged;
  }
  else {
    my $u = $users->find_one_and_update({'_id' => $uid}, {'$set' => {
       'mtime'=> $time }});
    die "Can't update user" unless $u;
  }
}

#######################################

# collect all post folders
my @names;
opendir D, "$postsdir" or die "can't open posts dir: $!";
foreach (readdir D) {
  next unless /^entry/;
  push @names, $_;
}
closedir D;

#######################################


# sort posts
foreach (sort @names) {

  my $entry = XMLin("$postsdir/$_/entry.xml", KeyAttr => {}, ForceArray => []);

  ## build object
  my $obj;
  my $name = $entry->{poster};
  my $site = 'lj';
  $obj->{title}  = $entry->{subject};
  $obj->{text}   = $entry->{event};
  $obj->{cuser}  = 'https://' . $name . '.livejournal.com';
  $obj->{ctime}  = $entry->{event_timestamp} + 0; # convert string to num
  $obj->{origin} = $entry->{url};
  $obj->{ncomm}  = $entry->{reply_count}+0;

  # external users
  $obj->{cuser} = $entry->{identity_url} if $entry->{identity_url};
  $name = $entry->{identity_display} if $entry->{identity_display};
  $site = 'google' if ($entry->{identity_type} || '') eq'Google';
  $site = 'fb'     if ($entry->{identity_type} || '') eq 'Facebook';
  $site = 'mailru' if ($entry->{identity_type} || '') eq 'Mail.ru';

  add_user $db, $obj->{cuser}, $name, $site, $obj->{ctime};

  # put the object
  my $objects = $db->get_collection( $coll );
  $obj->{_id}   = next_id($db, $coll);
  $obj->{muser} = 'http://slazav.livejournal.com';
  $obj->{mtime} = time;

  # create new object
  my $res = $objects->insert_one($obj);
  die "Can't put object into the database"
    unless $res->acknowledged;

  `touch $postsdir/$_/import_entry.txt`;


  ### comments
  my $fname = "$postsdir/$_/comments.xml";
  next unless -f $fname;
  my $data = XMLin($fname, KeyAttr => [], ForceArray => ['comment'], SuppressEmpty => 1)->{comment};

  # new ID's
  my %ids;

  my $comments = $db->get_collection( 'comm' );

  # sort by id!
  foreach my $c (sort {$a->{id}<=>$b->{id}} @{$data}){
    #next if $c->{state} && $c->{state} eq 'S';
    #next if $c->{state} && $c->{state} eq 'D';

    if ($c->{'date'}){
      if ($c->{'date'}=~/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$/) {
        $c->{ctime}=mktime($6,$5,$4,$3,$2-1,$1-1900)+0;
      }
      else {print STDERR "Strange date: ", Dumper($c), "\n"};
    }

    ## build object
    my $com;
    my $name = $c->{user} || '';
    my $site = $c->{user}? 'lj':'';

    $com->{_id}    = next_id($db, 'comm')+0;
    $ids{$c->{id}} = $com->{_id};
    $com->{title}  = $c->{subject} if exists $c->{subject};
    $com->{text}   = $c->{body}    if exists $c->{body};
    $com->{cuser}  = $name? 'https://' . $name . '.livejournal.com': 'anonymous';
    $com->{ctime}  = $c->{ctime}   if exists $c->{ctime};
    $com->{coll}   = 'news';
    $com->{scr}    = 1 if ($c->{state} || '') eq 'S';
    $com->{del}    = 1 if ($c->{state} || '') eq 'D';
    $com->{object_id} = $obj->{_id};
    $com->{parent_id} = $ids{$c->{parentid}} if $c->{parentid};

    add_user $db, $com->{cuser}, $name, 'lj', $com->{ctime};

    # create new comment
    my $res = $comments->insert_one($com);
    die "Can't put comment into the database"
      unless $res->acknowledged;
  }

}

