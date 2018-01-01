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
use Data::Dumper;

# import news from ljmigrate.py dump


my $postsdir='./lj';

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
  $obj->{ncomm}  = $entry->{reply_count};

  # external users
  $obj->{cuser} = $entry->{identity_url} if $entry->{identity_url};
  $name = $entry->{identity_display} if $entry->{identity_display};
  $site = 'google' if ($entry->{identity_type} || '') eq'Google';
  $site = 'fb'     if ($entry->{identity_type} || '') eq 'Facebook';
  $site = 'mailru' if ($entry->{identity_type} || '') eq 'Mail.ru';



  ### comments
  my $fname = "$postsdir/$_/comments.xml";
  next unless -f $fname;
  my $data = XMLin($fname, KeyAttr => [], ForceArray => ['comment'], SuppressEmpty => 1)->{comment};

  # new ID's
  my %ids;

  # sort by id!
  foreach my $c (sort {$a->{id}<=>$b->{id}} @{$data}){

print STDERR Dumper $c if $c->{state} && $c->{state} eq 'S';
print STDERR Dumper $c if $c->{state} && $c->{state} eq 'D';

    next if $c->{state} && $c->{state} eq 'S';
    next if $c->{state} && $c->{state} eq 'D';

    my $d = $c->{'date'} ||'';
    if ($d=~/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$/) {
      $c->{ctime}=mktime($6,$5,$4,$3,$2-1,$1-1900)+0;
    }
    else {print STDERR "Strange date: ", Dumper($c), "\n"};

    ## build object
    my $com;
    my $name = $c->{user} || '';
    my $site = 'lj';
    $com->{title}  = $c->{subject};
    $com->{text}   = $c->{body};
    $com->{cuser}  = $name? 'https://' . $name . '.livejournal.com': 'anonimous';
    $com->{ctime}  = $c->{ctime};
    $com->{coll}   = 'news';
    $com->{parent_id} = $ids{$c->{parentid}} if $c->{parentid};


  }

}

