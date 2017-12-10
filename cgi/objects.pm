package objects;

# Object operations

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(write_object delete_object show_object list_objects);
}


################################################

use strict;
use warnings;
use MongoDB;
use site;
use common;

my $logf = "$site_wwwdir/logs/objects.txt";

################################################

sub write_object{
  my $sess = shift; # user session
  my $coll = shift; # object collection
  my $obj  = shift; # object to write (including _id)

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

  # open object collection, get old object information (if it exists)
  my $objects = $db->get_collection( $coll );

  if ( $obj_id ){
    # modification of existing object is needed

    # check if object exists
    my $o = $objects->find_one({'_id'=>$obj_id});
    die "can't find object: $obj_id" unless $o;

    # check user permissions
    die "you can not modify objects, created by another users"
      if ($o->{cuser} ne $user_id && $level<$LEVEL_MODER);

    # open archive collection, save old information there:
    my $archive = $db->get_collection( "$coll.arc" );
    $o->{_id}   = next_id($db, "$coll.arc");
    my $res = $archive->insert_one($o);
    die "can't put an object into archive"
      unless $res->acknowledged;

    write_log($logf, "ARC < " . JSON->new->canonical()->encode($o) );

    # transfer some fields from old object to the new one:
    $obj->{ctime} = $o->{ctime};
    $obj->{cuser} = $o->{cuser};
    $obj->{prev}  = $res->inserted_id;

    $res = $objects->replace_one({'_id' => $obj_id}, $obj);
    die "Can't write an object"
      unless $res->acknowledged;

    write_log($logf, "MOD $coll: " . JSON->new->canonical()->encode($obj) );
  }
  else {
    $obj->{_id}   = next_id($db, $coll);
    $obj->{ctime} = $obj->{mtime};
    $obj->{cuser} = $obj->{muser};
    delete $obj->{prev};

    # create new object
    my $res = $objects->insert_one($obj);
    die "Can't put object into the database"
      unless $res->acknowledged;

    write_log($logf, "NEW $coll: " . JSON->new->canonical()->encode($obj) );
  }

}

sub delete_object{
  my $sess = shift; # user session
  my $coll = shift; # object collection
  my $id   = shift; # object to delete (_id)
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

  # open object collection, get old object information
  my $objects = $db->get_collection( $coll );

  my $upd = {'$set' => {
    'dtime' => time,
    'duser' => $u->{_id},
    'del'   => $del }};

  my $o;
  if ($u->{level} < $LEVEL_MODER){
    $u = $objects->find_one_and_update(
               {'_id' => $id, 'cuser' => $u->{_id}}, $upd);
  } else {
    $u = $objects->find_one_and_update({'_id' => $id}, $upd);
  }

  write_log($logf, "DEL $coll: " . JSON->new->canonical()->encode($o) );

}

sub show_object{
  my $coll = shift; # object collection
  my $id   = shift; # object id

  die "id is empty" unless ($id);

  # open object collection, get object information
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $objects = $db->get_collection( $coll );

  my $o = $objects->find_one({'_id'=>$id});
  die "can't find object in the database" unless $o;
  return $o;
}

sub list_objects{
  my $coll = shift; # object collection
  my $skip   = shift; 
  my $limit  = shift;

  # open object collection, get object information
  my $client = MongoDB->connect();
  my $db = $client->get_database( $database );
  my $objects = $db->get_collection( $coll );

  my $query_result = $objects->find({'_id'=>$id}, {'limit'=>$limit, 'skip'=>$skip})->result;

  my $res=[];
  while ( my $next = $query_result->next ) {
    push @{$res}, $next;
  }
  return JSON->new->encode($res);
}

1;
