#!/usr/bin/perl
use strict;
use warnings;
use XML::Simple qw(:strict);
use HTTP::Tiny;
use HTTP::Cookies;
use JSON;
use MongoDB;
use common;
use safe_html;

# import pcat

my $database='test';
my $coll='pcat';
my $infile = 'pcat.json';

open IN, $infile or die "Can't open $infile: $!";
my $data = JSON->new->decode(<IN>);
close IN;


# sort posts
foreach my $e (@{$data}) {

  print $e->{title}

  # skip a post if it was added
#  next if [ -f "$postsdir/$_/import_entry.txt" ];

  my $entry = XMLin("$postsdir/$_/entry.xml", KeyAttr => {}, ForceArray => []);

  ## process the text
  my $text = $entry->{event};
  my $title = $entry->{subject};

  $text =~ s/&lt;/</g;
  $text =~ s/&gt;/>/g;
  $text =~ s/&amp;/&/g;
  $text =  cleanup_htm($text, 100000);

  ## build object
  my $name = $entry->{poster};
  my $site = 'lj';

#  print ">> $_ $name\n";

  my $obj;
  $obj->{title}  = $title;
  $obj->{text}   = $text;
  $obj->{cuser}  = 'https://' . $name . '.livejournal.com';
  $obj->{ctime}  = $entry->{event_timestamp} + 0; # convert string to num
  $obj->{origin} = $entry->{url};
  $obj->{ncomm}  = $entry->{reply_count};

  # external users
  $obj->{cuser} = $entry->{identity_url} if $entry->{identity_url};
  $name = $entry->{identity_display} if $entry->{identity_display};
  $site = 'google' if ($entry->{identity_type} || '') eq'Google';
  $site = 'fb'     if ($entry->{identity_type} || '') eq 'Facebook';
  $site = 'mailru' if ($entry->{identity_type} || '') eq 'Mail.ru';

  # try to find user, add one if it does not exists
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );

  my $users = $db->get_collection( 'users' );
  my $u = $users->find_one({'_id'=>$obj->{cuser}});
  unless ($u) {
    print ">>>> Add user $obj->{cuser}: $name \@ $site\n";
    my $res = $users->insert_one({
      '_id'   => $obj->{cuser},
      'level'=> $LEVEL_NORM,
      'mtime'=> $obj->{ctime},
      'ctime'=> $obj->{ctime},
      'name' => $name,
      'site' => $site,
      'info' => '',
    });
    die "Can't put user into the database"
      unless $res->acknowledged;
  }
  else {
    my $u = $users->find_one_and_update({'_id' => $obj->{cuser}}, {'$set' => {
       'mtime'=> $obj->{ctime} }});
    die "Can't update user" unless $u;
  }


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

}

