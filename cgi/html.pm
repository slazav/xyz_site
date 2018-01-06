package html;
use site;
use CGI ':standard';
use POSIX qw(strftime);
use safe_html;
use utf8;

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(
    %level_names %site_icons
    mk_face print_head print_tail print_error
    mk_count_nav
    print_info_panel
    print_comments
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
# navigation panel "<< 1..25/123 >>"
sub mk_count_nav {
  my $pref  = shift; # url prefix (ends with ? or &)
  my $skip  = shift;
  my $num   = shift;
  my $count = shift;

  my $n1 = $skip+1; # first value
  my $n2 = $skip+1 + $num; # last value
  $n2 = $count if $n2 > $count;
  my $np = $n1 - $num - 1;
  $np = 0 if $np < 0;
  $np = $count-$num if $np > $count-$num;
  my $nn = $n1 + $num - 1;
  $nn = 0 if $nn < 0;
  $nn = $count-$num if $nn > $count-$num;

  return "<div class='nav center'>\n" .
         "<a href='${pref}skip=$np'>&lt&lt</a>\n" .
         "$n1 .. $n2 / $count\n".
         "<a href='${pref}skip=$nn'>&gt&gt</a>\n" .
         "</div>\n";
}

################################################
# object bottom panel "Created/Modified/Deleted"
sub print_info_panel {
  my $o = shift;
  my $url = shift;

  my $cu = mk_face($o->{cuser_info});
  my $ct = strftime "%Y-%m-%d %H:%M:%S", localtime($o->{ctime});

  my $panel = "$cu, $ct<br>";
  if ($o->{prev}){
    my $mt = strftime "%Y-%m-%d %H:%M:%S", localtime($o->{mtime});
    if ($o->{muser} ne $o->{cuser}){
      my $mu = mk_face($o->{muser_info});
      $panel .= "Отредактировано: $mu, $mt";
    } else {
      $panel .= "Отредактировано автором: $mt";
    }
    $panel .= " - <a href='${url}id=$o->{prev}'>старая версия</a>" if $o->{prev};
    $panel .= "<br>\n";
  }
  if ($o->{next}){
    $panel .= " Архив - <a href='${url}id=$o->{next}'>исправленная версия</a>\n";
  }
  if ($o->{del}){
    my $dt = strftime "%Y-%m-%d %H:%M:%S", localtime($o->{dtime});
    if ($o->{duser} ne $o->{cuser}) {
      my $du = mk_face($o->{duser_info});
      $panel .= " Удалено: $du, $dt<br>\n";
    } else {
      $panel .= "Удалено автором: $dt\n";
    }
  }
  $panel .= " <a href='javascript:show(\"obj_del_popup\")'>[удалить]</a>" if $o->{can_delete};
  $panel .= " <a href='javascript:on_obj_undel(\"$coll\",$o->{_id})'>[восстановить]</a>" if $o->{can_undel};
  $panel .= " <a href='javascript:show(\"obj_popup\")'>[редактировать]</a>" if $o->{can_edit};
  $panel .= " <a href='$o->{origin}'>(источник)</a>" if exists $o->{origin};

  print "<div class='obj_info right'>$panel</div>\n";
}

################################################
# print comments to any object
# urls:
#  javascript:com_new_form(coll, oid, pid)
#  javascript:com_edit_form(id)
#  javascript:com_del_form(id)
#
sub print_comments {
  my $coll = shift;
  my $o    = shift;
  my $comm = shift;

  print "<div class='nav center'>\n",
        "<a href='javascript:com_new_form(\"$coll\",$o->{_id},0)'>[новый комментарий]</a></div>\n",
        "<div class='com_form' id='com0'></div>\n\n";
  foreach my $c (@{$comm}){
    my $m = ($c->{depth} || 0)*20;
    my $div = "<div class='comment' style='margin-left: $m;'>\n";

    my $st = $c->{state} || '';
    if ($st eq 'D' && exists $c->{has_children}){
      print "$div<div class='com_empty'>(deleted comment)</div>\n";
      print "</div>\n";
    }
    if ($st eq 'S' && exists $c->{has_children}){
      print "$div<div class='com_empty'>(screened comment)</div>\n";
      print "</div>\n";
    }
    next if $st eq 'D' || $st eq 'S';

    my $cu = mk_face($c->{cuser_info});
    my $ct = strftime "%Y-%m-%d %H:%M:%S", localtime($c->{ctime});
    my $title = cleanup_txt($c->{title});
    my $text  = cleanup_htm($c->{text});
    print "$div$cu: <b>$title</b><br>\n";
    print "$text\n";
    my $btm_panel = '';
    $btm_panel .= "$ct";
    $btm_panel .= " <a href='javascript:com_new_form(\"$coll\",$o->{_id},$c->{_id})'>[ответить]</a>";
    $btm_panel .= " <a href='javascript:com_edit_form($c->{_id})'>[редактировать]</a>" if $c->{can_edit};
    $btm_panel .= " <a href='javascript:com_del_form($c->{_id})'>[удалить]</a>" if $c->{can_delete};
    print "<div class='com_info'>$btm_panel</div><div class='com_form' id='com$c->{_id}'></div>\n";
    print "</div>\n";
  }
  print "<div class='nav center'>\n",
        "<a href='javascript:com_new_form(\"$coll\",$o->{_id},-1)'>[новый комментарий]</a></div>\n",
        "<div class='com_form' id='com-1'></div>\n\n" if $#{$comm}>=0;
}

1;
