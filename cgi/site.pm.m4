package site;

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(
    $usecgi
    $site_url $site_wwwdir $database
    $google_id $google_secret
    $facebook_id $facebook_secret
    $loginza_id  $loginza_secret
  );
}

our $usecgi = 1;
our $site_url        = 'SITE_URL';
our $site_wwwdir     = 'SITE_WWWDIR';
our $database        = 'DATABASE';

our $facebook_id     = 'FACEBOOK_ID';
our $facebook_secret = 'FACEBOOK_SECRET';

our $loginza_id      = 'LOGINZA_ID';
our $loginza_secret  = 'LOGINZA_SECRET';

our $google_id       = 'GOOGLE_ID';
our $google_secret   = 'GOOGLE_SECRET';


1;
