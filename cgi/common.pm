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
# check permissions
sub check_perm {
  my $coll = shift;
  my $action = shift; # create, edit, delete
  my $mylevel   = shift;
  my $myobject  = shift || 0;
  my $mycomment = shift || 0;

  if ($coll eq 'news') {
    return 1 if $action eq 'create' && ($mylevel >= $LEVEL_NORM);
    return 1 if $action eq 'edit'   && ($myobject || $mylevel >= $LEVEL_ADMIN);
    return 1 if $action eq 'delete' && ($myobject || $mylevel >= $LEVEL_MODER);
  }
  if ($coll eq 'pcat' || $coll eq 'geo') {
    return 1 if $action eq 'create' && ($mylevel >= $LEVEL_NORM);
    return 1 if $action eq 'edit'   && ($myobject || $mylevel >= $LEVEL_NORM);
    return 1 if $action eq 'delete' && ($myobject || $mylevel >= $LEVEL_MODER);
  }
  if ($coll eq 'comm') {
    return 1 if $action eq 'create' && ($mylevel >= $LEVEL_NORM);
    return 1 if $action eq 'edit'   && ($mycomment);
    return 1 if $action eq 'delete' && ($mycomment || $myobject || $mylevel >= $LEVEL_MODER);
  }
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
  # user can't set these fields directly:
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
    die "permission denied"
      if check_perm($coll, 'edit', $level, $o->{cuser} eq $user_id);

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

    # check user permissions
    die "permission denied" if check_perm($coll, 'create', $level);

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

  my $obj = $objects->find_one({'_id'=>$obj_id});
  die "can't find object: $obj_id" unless $obj;

  # check user permissions
  die "permission denied"
    if check_perm($coll, 'delete', $level, $obj->{cuser} eq $u->{_id});

  my $upd = {'$set' => {
    'dtime' => time,
    'duser' => $u->{_id},
    'del'   => $del }};

  $u = $objects->find_one_and_update({'_id' => $id}, $upd);
  die "Can't write an object" unless $u;

  write_log($obj_log, "DEL $coll: " . JSON->new->canonical()->encode($obj) );
  return {"ret" => 0};
}

############################################################
# add additional fields for show_object and list_objects
sub object_expand {
  my $db   = shift; # database
  my $coll = shift; # collection name
  my $me   = shift; # user
  my $o    = shift;
  my $users = $db->get_collection('users');

  # build human-readable user information
  my $pr = {'sess'=>0, 'info'=>0, 'ctime'=>0, 'mtime'=>0, 'level'=>0};
  $o->{cuser_info} = $users->find_one({'_id'=>$o->{cuser}}, $pr);

  if ($o->{muser}) {
    if ($o->{muser} == $o->{cuser}){ $o->{muser_info} = $o->{cuser_info}; }
    else { $o->{muser_info} = $users->find_one({'_id'=>$o->{muser}}, $pr); }
  }

  if ($o->{duser}) {
    if    ($o->{duser} == $o->{cuser}){ $o->{duser_info} = $o->{cuser_info}; }
    elsif ($o->{duser} == $o->{muser}){ $o->{duser_info} = $o->{muser_info}; }
    else { $o->{duser_info} = $users->find_one({'_id'=>$o->{duser}}, $pr); }
  }

  my $level = $me->{level} || $LEVEL_ANON;
  my $my_id = $me->{_id} || "";
  $o->{can_edit}   = 1 if check_perm($coll, 'edit', $level, $o->{cuser} eq $my_id);
  $o->{can_delete} = 1 if check_perm($coll, 'delete', $level, $o->{cuser} eq $my_id);

}

############################################################
# Show a single object.
# ARC/DEL objects are shown
sub show_object{
  my $db   = shift || open_db(); # database
  my $coll = shift; # object collection
  my $pars  = shift; # (id, prev, next)

  die "id is empty" unless ($pars->{id});
  my $me = get_my_info($db);

  # open object collection, get object information
  my $objects = $db->get_collection( $coll );
  my $ret = $objects->find_one({'_id' => $pars->{id} + 0});

  object_expand($db, $coll, $me, $ret);

  die "can't find object $id in the database $coll" unless $ret;
  return $ret;
}

############################################################
# List objects.
# ARC/DEL objects are skipped
sub list_objects{
  my $db   = shift || open_db(); # database
  my $coll = shift; # object collection
  my $pars = shift;

  my $me = get_my_info($db);

  # open object collection, get object information
  my $objects = $db->get_collection( $coll );
  my $query_result = $objects->find({
      'del' => { '$exists' => 0 },
      'arc' => { '$exists' => 0 }
    }, {
      'limit'=>$pars->{num}||25, 'skip'=>$pars->{skip}||0, 'sort'=>{'_id', -1}
    })->result;

  my $ret=[];
  while ( my $next = $query_result->next ) {
    object_expand($db, $coll, $me, $next);
    push @{$ret}, $next;
  }
  return $ret;
}

1;
