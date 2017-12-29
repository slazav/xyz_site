package common;
use site;
use CGI ":standard";
use MongoDB;

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw($LEVEL_ANON $LEVEL_NORM $LEVEL_MODER
                   $LEVEL_ADMIN $LEVEL_SUPER
                   $usr_log $obj_log
                   write_log get_session open_db next_id
                   get_my_info set_user_level user_list
                   write_object delete_object show_object list_objects
                  );
}

## $LEVEL_ANON, $LEVEL_NORM, $LEVEL_MODER, $LEVEL_ADMIN, $LEVEL_SUPER
##    - user levels
##
## write_log <file> <msg>
##    - write to log file
##
## $sess = get_session
##    - get session (used in get_my_info and in logout script)
##
## $db = open_db
##    - open the database
##
## $id = next_id($db, $collection)
##    - increment and return last numerical id for a collection
##      (started from 1, increased by 1)
##
## $ret = get_my_info([$db])
##    - find session, return user information or undef
##
## $ret = set_user_level([$db], $id, $new_level)
##
## $ret = user_list([$db])
##

# user levels
our $LEVEL_ANON  = -1;
our $LEVEL_NORM  =  0;
our $LEVEL_MODER =  1;
our $LEVEL_ADMIN =  2;
our $LEVEL_SUPER =  100;

# log files
our $usr_log = "$site_wwwdir/logs/login.txt";
our $obj_log = "$site_wwwdir/logs/objects.txt";

############################################################
# write log
sub write_log {
  my $file = shift;
  my $msg  = shift;
  my ($S,$M,$H,$d,$m,$Y) = localtime;
  my $tstamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
                        $Y+1900, $m+1,$d,$H,$M,$S);
  open LOG, ">> $file";
  printf LOG "%s %s\n", $tstamp, $msg;
  close LOG;
}

############################################################
# get session from cookie or command line
sub get_session {
  return cookie('SESSION') || '' if $usecgi;
  return $ARGV[0] || '';
}

############################################################
# open database connection, get user information
sub open_db {
  my $db = MongoDB->connect()->get_database( $database );
  die "Can't open database: $database" unless $db;
  return $db;
}

############################################################
# counters for autoincremented id
# see https://docs.mongodb.com/v3.0/tutorial/create-an-auto-incrementing-field/
sub next_id{
   my $db = shift;   # database handler
   my $coll = shift; # collection name

   my $cnt = $db->get_collection( 'counters' );

   my $c = $cnt->find_one_and_update(
          { '_id' => $coll }, {'$inc' => { 'seq' => 1 }});
   return $c->{seq}+1 if $c;

   # counter does not exist yet
   my $res = $cnt->insert_one({'_id' => $coll, 'seq' => 1});
   die "can't create a counter for $coll" unless $res->acknowledged;
   return 1;
}

############################################################
# get user information
sub get_my_info {
  my $db = shift || open_db();
  my $sess = get_session();
  return undef unless $sess;

  my $users = $db->get_collection( 'users' );
  my $ret = $users->find_one({'sess'=>$sess}, { 'sess' => 0, 'info' => 0 });
  return $ret;
}

############################################################
sub set_user_level {
  my $db = shift || open_db();
  my $id = shift;
  my $new_level = shift;
  my $users = $db->get_collection( 'users' );

  # check permissions
  my $u1 = get_my_info($db);
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
  return {"ret" => 0};
}

############################################################
sub user_list {
  my $db = shift || open_db();

  # open user database
  my $users = $db->get_collection( 'users' );
  my $u = get_my_info($db);

  # check permissions
  die "permission denied" unless defined $u->{level} && $u->{level} > $LEVEL_NORM;

  # collect information into array
  my $query_result = $users->find({}, {'projection' => {'sess'=>0, 'info'=>0}})->result;
  my $ret=[];
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
    push @{$ret}, $next;
  }
  return $ret;
}

############################################################
sub write_object{
  my $db   = shift || open_db(); # database
  my $coll = shift; # object collection
  my $obj  = shift; # object to write (including _id)

  my $u = get_my_info($db);
  die "Unknown user" unless $u;
  my $user_id = $u->{_id};
  my $level   = $u->{level};

  my $obj_id  = $obj->{_id};
  # set muser/mtime fields
  $obj->{muser} = $user_id;
  $obj->{mtime} = time;
  # user can't set these fields:
  delete $obj->{del};
  delete $obj->{arc};
  delete $obj->{prev};

  # open object collection, get old object information (if change of existing id is needed)
  my $objects = $db->get_collection( $coll );

  if ( $obj_id ){
    # modification of existing object is needed

    # check if object exists
    my $o = $objects->find_one({'_id'=>$obj_id});
    die "can't find object: $obj_id" unless $o;

    # check user permissions
    die "you can not modify objects, created by another users"
      if ($o->{cuser} ne $user_id && $level<$LEVEL_MODER);

    # save old information:
    $o->{_id}   = next_id($db, "$coll");
    $o->{arc}   = 1;
    my $res = $objects->insert_one($o);
    die "can't put an object into archive"
      unless $res->acknowledged;

    write_log($obj_log, "ARC $coll: " . JSON->new->canonical()->encode($o) );

    # transfer some fields from old object to the new one:
    $obj->{ctime} = $o->{ctime};
    $obj->{cuser} = $o->{cuser};
    $obj->{prev}  = $res->inserted_id;

    $res = $objects->replace_one({'_id' => $obj_id}, $obj);
    die "Can't write an object"
      unless $res->acknowledged;

    write_log($obj_log, "MOD $coll: " . JSON->new->canonical()->encode($obj) );
  }
  else {
    $obj->{_id}   = next_id($db, $coll);
    $obj->{ctime} = $obj->{mtime};
    $obj->{cuser} = $obj->{muser};

    # create new object
    my $res = $objects->insert_one($obj);
    die "Can't put object into the database"
      unless $res->acknowledged;

    write_log($obj_log, "NEW $coll: " . JSON->new->canonical()->encode($obj) );
  }
  return {"ret" => 0};
}

############################################################
sub delete_object{
  my $db   = shift || open_db(); # database
  my $coll = shift; # object collection
  my $id   = shift; # object to delete (_id)
  my $del  = shift; # delete/undelete (1 or 0)

  my $u = get_my_info($db);
  die "Unknown user" unless $u;
  die "id is empty" unless ($id);
  die "del parameter should be 0 or 1" unless ($del==1 || $del==0);

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
  write_log($obj_log, "DEL $coll: " . JSON->new->canonical()->encode($o) );
  return {"ret" => 0};
}

############################################################
# add additional fields
sub object_expand {
  my $db   = shift || open_db(); # database
  my $o    = shift;
  my $users = $db->get_collection('users');

  # build human-readable user information
  my $pr = {'sess'=>0, 'info'=>0, 'ctime'=>0, 'mtime'=>0, 'level'=>0};
  $o->{cuser_info} = $users->find_one({'_id'=>$o->{cuser}}, $pr);

  if ($o->{muser} != $o->{cuser}){
    $o->{muser_info} = $users->find_one({'_id'=>$o->{muser}}, $pr);
  }
  else {
    $o->{muser_info} = $o->{cuser_info};
  }
}

############################################################
sub show_object{
  my $db   = shift || open_db(); # database
  my $coll = shift; # object collection
  my $id   = shift; # object id

  die "id is empty" unless ($id);

  # open object collection, get object information
  my $objects = $db->get_collection( $coll );
  my $ret = $objects->find_one({'_id' => $id + 0});

  object_expand($db, $ret);

  die "can't find object $id in the database $coll" unless $ret;
  return $ret;
}

############################################################
sub list_objects{
  my $db   = shift || open_db(); # database
  my $coll = shift; # object collection
  my $skip   = shift || 0;
  my $limit  = shift || 25;

  # open object collection, get object information
  my $objects = $db->get_collection( $coll );
  my $query_result = $objects->find({},
    {'limit'=>$limit, 'skip'=>$skip, 'sort'=>{'_id', -1}})->result;

  my $ret=[];
  while ( my $next = $query_result->next ) {
    object_expand($db, $next);
    push @{$ret}, $next;
  }
  return $ret;
}

1;
