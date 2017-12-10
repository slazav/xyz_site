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
                   write_log get_session next_id);
}

# user levels
our $LEVEL_ANON  = -1;
our $LEVEL_NORM  =  0;
our $LEVEL_MODER =  1;
our $LEVEL_ADMIN =  2;
our $LEVEL_SUPER =  100;

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

# get session from cookie or command line
sub get_session {
  my $sess;
  if ($usecgi){
    $sess = cookie('SESSION') || '';
  }
  else {
    $sess = $ARGV[0] || '';
  }
  die "Session is missing" unless $sess;
  return $sess;
}

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

1;
