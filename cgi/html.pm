package html;
use site;
use CGI ':standard';
use safe_html;
use utf8;

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(
    %level_names %site_icons
    mk_face print_head print_tail print_error
  );
}

## HTML output
## no die commands allowed here!

################################################
# level names
our %level_names = (
  -1 => 'ограниченный',
   0 => 'обычный',
   1 => 'модератор',
   2 => 'администратор',
 100 => 'самый главный',
);

# site icons
our %site_icons = (
  lj     => 'img/lj.gif',
  fb     => 'img/fb.png',
  yandex => 'img/ya.png',
  google => 'img/go.png',
  gplus  => 'img/gp.png',
  vk     => 'img/vk.png',
  mailru => 'img/mr.gif',
);

################################################
sub mk_face {
  my $u = shift;
  return "" unless $u;
  return "<b>anonymous</b>" if ($u->{_id} eq 'anonymous');
  return "<b>anonymous</b>" if ($u->{_id} eq 'livejournal');
  return "<span class='user_face'><a href='$u->{_id}'>" .
         "<img class='login_img' alt='($u->{site})' src='$site_icons{$u->{site}}'>" .
         "$u->{name}</a></span>";
}

################################################
my $loginza_providers  = 'livejournal,facebook,vkontakte,yandex,google';

my $facebook_login_url = 'https://www.facebook.com/dialog/oauth?'
                       . "client_id=$facebook_id&redirect_uri=$site_url/cgi/login_fb.pl&response_type=code";
my $google_login_url   = 'https://accounts.google.com/o/oauth2/auth?'
                       . "redirect_uri=$site_url/cgi/login_google.pl&response_type=code&client_id=$google_id&"
                       . "scope=https://www.googleapis.com/auth/userinfo.profile";
my $loginza_login_url  = 'https://loginza.ru/api/widget?'
                       . "token_url=$site_url/cgi/login_loginza.pl&providers_set=$loginza_providers";

################################################
sub print_head {
  my $u = shift;
  my $l = ($u || exists($u->{level}))? $u->{level}: $LEVEL_ANON;

  # main menu buttons
  my $pages = [
    {url => 'news',      title => 'Новости'},
    {url => 'pcat',      title => 'Походы'},
    {url => 'texts',     title => 'Тексты'},
    {url => 'map.htm',   title => 'Карта'},
    {url => 'help',      title => 'Справка'},
    {url => 'users',     title => 'Люди', level => $LEVEL_MODER},
  ];
  # build main menu
  my $main_menu='';
  foreach my $p (@{$pages}) {
    my $a = ($0 =~ /$p->{url}$/)?' active':'';
    $main_menu.="\n      <td><a href='$p->{url}' class='button$a'>$p->{title}</a></td>"
      if !exists $p->{level} || $p->{level} <= $l;
  }

  # build login panel
  my $login_panel='';
  if (exists $u->{_id}) {
    $login_panel = mk_face($u) . ' <a class="login_btn" href="javascript:on_logout();">выйти</a>';
  }
  else {
    $login_panel = 'Войти: '
     . "<a class='login_btn' href='$facebook_login_url'><img class='login_img' alt='Facebook' src='img/fb.png'></a>\n"
     . "<a class='login_btn' href='$google_login_url'  ><img class='login_img' alt='Google'   src='img/go.png'></a>\n"
     . "<a class='login_btn' href='$loginza_login_url' ><img class='login_img' alt='Loginza'  src='img/loginza.png'></a>\n";
  }

  # print header
  print header(-type=>'text/html', -charset=>'utf-8');
  print qq*
<html>
<head>
  <LINK href="main.css" rel="stylesheet" type="text/css">
  <script type="text/JavaScript" src="site.js"></script>
  <script type="text/JavaScript" src="main.js"></script>
</head>
<body>
  <!-- Main table -->
  <table valign=top width=100% height=100% cellspacing=0 cellpadding=5>
    <!--Top menu, login/logout buttons -->
    <tr height=1%><td>
    <table><tr>$main_menu
      <td width = 100% align=right>$login_panel</td>
    </tr></table>
    </td></tr>
    <!-- Main frame -->
    <tr><td class="mainframe" heigth=100% valign=top>
*;
}

################################################
sub print_tail {
print qq*
    <!-- End of Main frame -->
    </td></tr>
  </table>
</body>
</html>
*;
}

################################################
sub print_error {
  my $msg = shift;
  my $fmt = shift || 'json';
  my $logf = shift;
  chomp $msg;

  write_log($logf, "$0 error: $_") if $logf;
  if ($fmt eq 'json') {
    print header (-type=>'application/json', -charset=>'utf-8');
    print JSON->new->canonical()->encode({"ret" => 1, "error_message" => $_}), "\n";
    return;
  }

  $msg = cleanup_txt($msg);

  print header (-type=>'text/html', -charset=>'utf-8');
  print qq*
<html>
<head>
  <LINK href="main.css" rel="stylesheet" type="text/css">
</head>
<body>
  <table valign=top width=100% height=100% cellspacing=0 cellpadding=5>
    <tr><td class="mainframe" heigth=100% valign=top>
      <h3>Error: $msg</h3>
    </td></tr>
  </table>
</body>
</html>
*;
}
################################################
