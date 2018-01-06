package common;
use site;
use CGI ":standard";
use MongoDB;
use utf8;

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw($LEVEL_ANON $LEVEL_NORM $LEVEL_MODER
                   $LEVEL_ADMIN $LEVEL_SUPER
                   $usr_log $obj_log
                   write_log get_session open_db next_id
                   get_my_info set_user_level user_list
                   check_perm
                   write_object delete_object show_object list_objects
                   list_comments show_comment delete_comment screen_comment new_comment edit_comment
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
  my $action = shift; # create, edit, delete, undel
  my $user   = shift;
  my $object = shift;
  my $comment = shift;

  my $mylvl = $user->{level} || $LEVEL_ANON;
  if ($coll eq 'news') {
    return 1 if $action eq 'create' && ($mylvl >= $LEVEL_NORM);
    my $myobject = $object->{cuser} eq $user->{_id};
    my $del = $object->{del};
    my $arc = $object->{next};
    return 1 if $action eq 'edit'   && ($myobject || $mylvl >= $LEVEL_ADMIN) && !$del && !$arc;
    return 1 if $action eq 'delete' && ($myobject || $mylvl >= $LEVEL_MODER) && !$del && !$arc;
    return 1 if $action eq 'undel'  && ($myobject || $mylvl >= $LEVEL_MODER) && $del;
  }
  if ($coll eq 'pcat' || $coll eq 'geo') {
    my $del = $object->{del};
    my $arc = $object->{next};
    return 1 if $action eq 'create' && ($mylvl >= $LEVEL_NORM);
    my $myobject = $object->{cuser} eq $user->{_id};
    return 1 if $action eq 'edit'   && ($myobject || $mylvl >= $LEVEL_NORM)  && !$del && !$arc;
    return 1 if $action eq 'delete' && ($myobject || $mylvl >= $LEVEL_MODER) && !$del && !$arc;
    return 1 if $action eq 'undel'  && ($myobject || $mylvl >= $LEVEL_MODER) && $del;
  }
  if ($coll eq 'comm') {
    return 1 if $action eq 'create' && ($mylvl >= $LEVEL_ANON);
    my $mycomment = $comment->{cuser} eq $user->{_id};
    my $st = $comment->{state} || '';
    return 1 if $action eq 'answer'   && ($mylvl >= $LEVEL_ANON) && !$st;
    return 1 if $action eq 'edit'   && ($mycomment) && !$st;
    my $myobject = $object->{cuser} eq $user->{_id};
    return 1 if $action eq 'screen'   && ($mycomment || $myobject || $mylvl >= $LEVEL_MODER) && !$st;
    return 1 if $action eq 'unscreen' && ($mycomment || $myobject || $mylvl >= $LEVEL_MODER) && ($st eq 'S');
    return 1 if $action eq 'delete'   && ($mycomment || $myobject || $mylvl >= $LEVEL_MODER) && !$st;
  }
  return 0;
}

############################################################
sub write_object{
  my $db   = shift || open_db(); # database
  my $coll = shift; # object collection
  my $obj  = shift; # object to write (including _id)

  my $u = get_my_info($db);
  die "Unknown user" unless $u;

  my $id  = $obj->{_id} + 0;
  # set muser/mtime fields
  $obj->{muser} = $u->{_id};
  $obj->{mtime} = time;
  # user can't set these fields directly:
  delete $obj->{del};
  delete $obj->{prev};
  delete $obj->{ncomm};
  delete $obj->{next};

  # open object collection, get old object information (if change of existing id is needed)
  my $objects = $db->get_collection( $coll );

  if ( $id ){
    # modification of existing object is needed

    # check if object exists
    my $o = $objects->find_one({'_id'=>$id});
    die "can't find object: $id" unless $o;

    # check user permissions
    die "permission denied"
      unless check_perm($coll, 'edit', $u, $o);

    # save old information:
    $o->{_id}   = next_id($db, "$coll");
    $o->{next}  = $id;
    # save archive object
    my $res = $objects->insert_one($o);
    die "can't put an object into archive"
      unless $res->acknowledged;

    write_log($obj_log, "ARC $coll: " . JSON->new->canonical()->encode($o) );

    # transfer some fields from old object to the new one:
    $obj->{ctime} = $o->{ctime};
    $obj->{cuser} = $o->{cuser};
    $obj->{ncomm} = $o->{ncomm};
    $obj->{prev}  = $res->inserted_id;

    # update object
    $res = $objects->replace_one({'_id' => $id}, $obj);
    die "Can't write an object"
      unless $res->acknowledged;

    write_log($obj_log, "MOD $coll: " . JSON->new->canonical()->encode($obj) );
  }
  else {
    $obj->{_id}   = next_id($db, $coll);
    $obj->{ctime} = $obj->{mtime};
    $obj->{cuser} = $obj->{muser};

    # check user permissions
    die "permission denied"
      unless check_perm($coll, 'create', $u, {});

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
  $id+=0; # convert to int!
  die "del parameter should be 0 or 1" unless ($del==1 || $del==0);

  # open object collection, get old object information
  my $objects = $db->get_collection( $coll );

  my $obj = $objects->find_one({'_id'=>$id});
  die "can't find object: $id" unless $obj;

  # check user permissions
  die "permission denied"
    unless check_perm($coll, $del?'delete':'undel', $u, $obj);

  my $upd = {'$set' => {'dtime' => time, 'duser' => $u->{_id}}};
  if ($del) {$upd->{'$set'}->{del} = 1;}
  else {$upd->{'$unset'}->{del} = 1;}

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
    if ($o->{muser} eq $o->{cuser}){ $o->{muser_info} = $o->{cuser_info}; }
    else { $o->{muser_info} = $users->find_one({'_id'=>$o->{muser}}, $pr); }
  }

  if ($o->{duser}) {
    if    ($o->{duser} eq $o->{cuser}){ $o->{duser_info} = $o->{cuser_info}; }
    elsif ($o->{duser} eq $o->{muser}){ $o->{duser_info} = $o->{muser_info}; }
    else { $o->{duser_info} = $users->find_one({'_id'=>$o->{duser}}, $pr); }
  }
  $o->{can_edit}   = 1 if check_perm($coll, 'edit',   $me, $o);
  $o->{can_delete} = 1 if check_perm($coll, 'delete', $me, $o);
  $o->{can_undel}  = 1 if check_perm($coll, 'undel',  $me, $o);
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

  my $q = { 'del' => { '$exists' => 0 }, 'next' => { '$exists' => 0 } };
  $q->{'$text'} = {'$search' => $pars->{search}} if $pars->{search};

  # open object collection, get object information
  my $objects = $db->get_collection( $coll );
  my $query_result = $objects->find($q, {
      'limit'=>$pars->{num}||25,
      'skip'=>$pars->{skip}||0,
      'sort'=>{'_id', -1}
    })->result;
  my $count = $objects->count($q);

  my $ret=[];
  while ( my $next = $query_result->next ) {
    object_expand($db, $coll, $me, $next);
    push @{$ret}, $next;
  }
  return $ret, $count;
}

############################################################
# add additional fields for list_comments
sub comment_expand {
  my $db   = shift; # database
  my $me   = shift; # user
  my $o    = shift;
  my $c    = shift;
  my $users = $db->get_collection('users');

  # build human-readable user information
  my $pr = {'sess'=>0, 'info'=>0, 'ctime'=>0, 'mtime'=>0, 'level'=>0};
  $c->{cuser_info} = $users->find_one({'_id'=>$c->{cuser}}, $pr);

  $c->{can_edit}   = 1 if check_perm('comm', 'edit',   $me, $o, $c);
  $c->{can_delete} = 1 if check_perm('comm', 'delete', $me, $o, $c);
  $c->{can_screen} = 1 if check_perm('comm', 'screen', $me, $o, $c);
  $c->{can_unscreen} = 1 if check_perm('comm', 'unscreen', $me, $o, $c);
  $c->{can_answer}   = 1 if check_perm('comm', 'answer',   $me, $o, $c);

  # screen comment which user can not see
  if (($c->{state}||'') eq 'S' && !$c->{can_unscreen}){
    delete $c->{title};
    delete $c->{text};
  }
}

############################################################
# List comments.
sub list_comments {
  my $db   = shift || open_db(); # database
  my $pars  = shift; # (id, coll)

  # get user information
  my $me = get_my_info($db);

  # get object information
  my $objects = $db->get_collection( $pars->{coll} );
  my $obj  = $objects->find_one({'_id' => $pars->{id}+0}, {'text'=>0, 'title'=>0});
  die "can't find object in $pars->{coll}: $pars->{id}" unless ($obj);

  # get all comments
  my $comm = $db->get_collection( 'comm' );
  my $q = { 'coll' => $pars->{coll}, 'object_id' => $pars->{id}+0 };
  my $query_result = $comm->find($q, { 'sort'=>{'_id', 1} })->result;

  # sort comments to have the tree
  my $children;
  while ( my $next = $query_result->next ) {
    comment_expand($db, $me, $obj, $next);
    push @{$children->{$next->{parent_id} || 0}}, $next;
  }

  my $ret=[];
  sub add_comm{
    my $ret = shift;
    my $id = shift || 0;
    my $depth = shift || 0;
    foreach (@{$children->{$id}}){
      $_->{depth} = $depth if $depth;
      $_->{children} = $#{$children->{$_->{_id}}}+1
        if $#{$children->{$_->{_id}}}>=0;
      push @{$ret}, $_;
      add_comm($ret,$_->{_id}, $depth+1);
    }
  }
  add_comm($ret);

  # We want to mark deleted/screened comments with non-deleted
  # children
  my $d = 0;
  my $f = 0;
  foreach my $c (reverse @{$ret}){
    $f=0 if ($c->{depth}||0) >= $d; # step up
    $c->{has_children}=1 if $f && exists $c->{state};
    $f=1 if !exists $c->{state};
    $d = $c->{depth}||0;
  }

  return $ret;
}

############################################################
# Show comment.
sub show_comment {
  my $db = shift || open_db(); # database
  my $id = shift;


  # get user information
  my $me = get_my_info($db);

  # get comment information
  my $comments = $db->get_collection( 'comm' );
  my $com = $comments->find_one({'_id' => $id+0});
  die "can't find comment: $id" unless $com;

  my $oid   = $com->{object_id};
  my $coll  = $com->{coll};
  my $state = $com->{state} || '';

  # get object information
  my $objects = $db->get_collection( $coll );
  my $obj  = $objects->find_one({'_id' => $oid+0}, {'text'=>0, 'title'=>0});
  die "can't find object in $coll: $oid" unless $obj;

  comment_expand($db, $me, $obj, $com);

  return $com;
}

############################################################
# Update ncomm field in an object
sub update_ncomm {
  my $db   = shift;
  my $coll = shift;
  my $id   = shift;
  my $objects  = $db->get_collection( $coll );
  my $comments = $db->get_collection( 'comm' );
  die "Can't connect to a database" unless $objects || $comments;

  my $count = $comments->count({'coll' => $coll, 'object_id' => $id+0, 'state' => {'$exists'=>0}});
  my $u = $objects->find_one_and_update({'_id' => $id+0}, {'$set'=>{'ncomm'=>$count}});
  die "Can't update ncomm" unless $u;
}

############################################################
# Delete a comment
sub delete_comment {
  my $db = shift || open_db(); # database
  my $id = shift;

  # get user information
  my $me = get_my_info($db);

  # get comment information
  my $comments = $db->get_collection( 'comm' );
  my $com = $comments->find_one({'_id' => $id+0}, {'text'=>0, 'title'=>0});
  die "can't find comment: $id" unless ($com);

  my $oid  = $com->{object_id};
  my $coll = $com->{coll};

  # get object information
  my $objects = $db->get_collection( $coll );
  my $obj  = $objects->find_one({'_id' => $oid+0}, {'text'=>0, 'title'=>0});
  die "can't find object in $coll: $oid" unless ($obj);

  # check user permissions
  die "permission denied"
    unless check_perm('comm', 'delete', $me, $obj, $com);

  # delete comment
  my $upd = {'$unset' => {'title' => '', 'text' => ''}, '$set' => {'state', 'D'}};
  my $u = $comments->find_one_and_update({'_id' => $id+0}, $upd);
  die "Can't write a comment" unless $u;

  update_ncomm $db, $coll, $oid;

  write_log($obj_log, "DEL COMM: " . JSON->new->canonical()->encode($com) );
  return {"ret" => 0};
}

############################################################
# Screen/unscreen a comment
sub screen_comment {
  my $db = shift || open_db(); # database
  my $id = shift;

  # get user information
  my $me = get_my_info($db);

  # get comment information
  my $comments = $db->get_collection( 'comm' );
  my $com = $comments->find_one({'_id' => $id+0}, {'text'=>0, 'title'=>0});
  die "can't find comment: $id" unless ($com);

  my $oid   = $com->{object_id};
  my $coll  = $com->{coll};
  my $state = $com->{state} || '';

  # get object information
  my $objects = $db->get_collection( $coll );
  my $obj  = $objects->find_one({'_id' => $oid+0}, {'text'=>0, 'title'=>0});
  die "can't find object in $coll: $oid" unless ($obj);

  # check user permissions
  # screen/unscreen the comment
  my $upd;
  if ($state eq 'S') {
    die "permission denied"
      unless check_perm('comm', 'unscreen', $me, $obj, $com);
    $upd = {'$unset' => {'state'=>''}};
  }
  elsif ($state eq '') {
    die "permission denied"
      unless check_perm('comm', 'screen', $me, $obj, $com);
    $upd = {'$set' => {'state'=>'S'}};
  }
  else {die "Wrong comment state: $state";}

  my $u = $comments->find_one_and_update({'_id' => $id+0}, $upd);
  die "Can't write a comment" unless $u;

  update_ncomm $db, $coll, $oid;

  write_log($obj_log, "DEL COMM: " . JSON->new->canonical()->encode($com) );
  return {"ret" => 0};
}


############################################################
# New comment
sub new_comment {
  my $db = shift || open_db(); # database
  my $com = shift;

  # get user information
  my $me = get_my_info($db);

  # get object information
  my $objects = $db->get_collection( $com->{coll} );
  my $obj  = $objects->find_one({'_id' => $com->{object_id}+0}, {'text'=>0, 'title'=>0});
  die "can't find object in $com->{coll}: $com->{object_id}" unless $obj;

  # check parent comment
  my $comments = $db->get_collection( 'comm' );
  if ($com->{parent_id}) {
    my $pcom = $comments->find_one({'_id' => $com->{parent_id}+0}, {'text'=>0, 'title'=>0});
    die "can't find parent comment: $com->{parent_id}" unless $pcom;
  }

  # check user permissions
  die "permission denied"
    unless check_perm('comm', 'create', $me, $obj);

  $com->{_id}       = next_id($db, 'comm')+0;
  $com->{cuser}     = $me->{_id} || 'anonymous';
  $com->{ctime}     = time;
  delete $com->{state};

  my $res = $comments->insert_one($com);
  die "Can't put comment into the database"
    unless $res->acknowledged;

  update_ncomm $db, $com->{coll}, $com->{object_id};

  write_log($obj_log, "NEW COMM: " . JSON->new->canonical()->encode($com) );
  return {"ret" => 0};
}

############################################################
# Edit comment
sub edit_comment {
  my $db = shift || open_db(); # database
  my $com = shift;

  # get user information
  my $me = get_my_info($db);

  # get the comment
  my $comments = $db->get_collection( 'comm' );
  my $ocom = $comments->find_one({'_id' => $com->{_id}+0}, {'text'=>0, 'title'=>0});
    die "can't find parent comment: $com->{_id}" unless $ocom;

  # get object information (based on old comment!)
  my $objects = $db->get_collection( $ocom->{coll} );
  my $obj  = $objects->find_one({'_id' => $ocom->{object_id}+0}, {'text'=>0, 'title'=>0});
  die "can't find object in $ocom->{coll}: $ocom->{object_id}" unless $obj;

  # check user permissions
  die "permission denied"
    unless check_perm('comm', 'edit', $me, $obj, $ocom);

  my $u = $comments->find_one_and_update({'_id' => $com->{_id}+0},
        {'$set'=>{ 'title'=>$com->{title},
                   'text'=>$com->{text},
                   'mtime'=>time }});

  die "Can't put comment into the database" unless $u;

  write_log($obj_log, "EDIT COMM: " . JSON->new->canonical()->encode($com) );
  return {"ret" => 0};
}

############################################################
1;
