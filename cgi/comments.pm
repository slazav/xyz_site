package comments;

# Comment operations

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(write_comment delete_comment show_comment);
}


################################################

use strict;
use warnings;
use MongoDB;
use site;
use common;

my $logf = "$site_wwwdir/logs/comments.txt";

################################################

sub write_comment{
  my $sess = shift; # user session
  my $coll = shift; # comment collection
  my $obj  = shift; # comment to write (including _id, ref_coll, ref_id)

  die "session is empty" unless ($sess);

  # open user collection, get user information
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $users = $db->get_collection( 'users' );
  my $u = $users->find_one({'sess'=>$sess}, { 'sess' => 0, 'info' => 0 });
  die "Can't find user in the database" unless $u;
  my $user_id = $u->{_id};
  my $level   = $u->{level};

  my $obj_id  = $obj->{_id};
  # set muser/mtime fields
  $obj->{muser} = $user_id;
  $obj->{mtime} = time;
  delete $obj->{del};

  # open comment collection, get old comment information (if it exists)
  my $comments = $db->get_collection( $coll );

  if ( $obj_id ){
    # modification of existing comment is needed

    # check if comment exists
    my $o = $comments->find_one({'_id'=>$obj_id});
    die "can't find comment: $obj_id" unless $o;

    # check user permissions
    die "you can not modify comments, created by another users"
      if ($o->{cuser} ne $user_id && $level<$LEVEL_MODER);

    # open archive collection, save old information there:
    my $archive = $db->get_collection( "$coll.arc" );
    $o->{_id}   = next_id($db, "$coll.arc");
    my $res = $archive->insert_one($o);
    die "can't put an comment into archive"
      unless $res->acknowledged;

    write_log($logf, "ARC < " . JSON->new->canonical()->encode($o) );

    # transfer some fields from old comment to the new one:
    $obj->{ctime} = $o->{ctime};
    $obj->{cuser} = $o->{cuser};
    $obj->{prev}  = $res->inserted_id;

    $res = $comments->replace_one({'_id' => $obj_id}, $obj);
    die "Can't write an comment"
      unless $res->acknowledged;

    write_log($logf, "MOD $coll: " . JSON->new->canonical()->encode($obj) );
  }
  else {
    $obj->{_id}   = next_id($db, $coll);
    $obj->{ctime} = $obj->{mtime};
    $obj->{cuser} = $obj->{muser};
    delete $obj->{prev};

    # create new comment
    my $res = $comments->insert_one($obj);
    die "Can't put comment into the database"
      unless $res->acknowledged;

    write_log($logf, "NEW $coll: " . JSON->new->canonical()->encode($obj) );
  }

}

sub delete_comment{
  my $sess = shift; # user session
  my $coll = shift; # comment collection
  my $id   = shift; # comment to delete (_id)
  my $del  = shift; # delete/undelete (1 or 0)

  die "session is empty" unless ($sess);
  die "id is empty" unless ($id);
  die "del parameter should be 0 or 1" unless ($del==1 || $del==0);

  # open user collection, get user information
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $users = $db->get_collection( 'users' );
  my $u = $users->find_one({'sess'=>$sess}, { 'sess' => 0, 'info' => 0 });
  die "Can't find user in the database" unless $u;

  # open comment collection, get old comment information
  my $comments = $db->get_collection( $coll );

  my $upd = {'$set' => {
    'dtime' => time,
    'duser' => $u->{_id},
    'del'   => $del }};

  my $o;
  if ($u->{level} < $LEVEL_MODER){
    $u = $comments->find_one_and_update(
               {'_id' => $id, 'cuser' => $u->{_id}}, $upd);
  } else {
    $u = $comments->find_one_and_update({'_id' => $id}, $upd);
  }

  write_log($logf, "DEL $coll: " . JSON->new->canonical()->encode($o) );

}

sub show_comment{
  my $coll = shift; # comment collection
  my $id   = shift; # comment id

  die "id is empty" unless ($id);

  # open comment collection, get comment information
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $comments = $db->get_collection( $coll );

  my $o = $comments->find_one({'_id'=>$id});
  die "can't find comment in the database" unless $o;
  return $o;
}

1;
