divert(-1)

������ �� ���� ����� ������ ���.����

define(LOGINZA_PROVIDERS, `livejournal,facebook,vkontakte,yandex,google')

define(FACEBOOK_LOGIN_URL, `https://www.facebook.com/dialog/oauth?client_id=FACEBOOK_ID&redirect_uri=SITE_URL/cgi/login_fb.pl&response_type=code')
define(GOOGLE_LOGIN_URL,   `https://accounts.google.com/o/oauth2/auth?redirect_uri=SITE_URL/cgi/login_google.pl&response_type=code&client_id=GOOGLE_ID&scope=https://www.googleapis.com/auth/userinfo.profile')
define(LOGINZA_LOGIN_URL,  `https://loginza.ru/api/widget?token_url=SITE_URL/cgi/login_loginza.pl&providers_set=LOGINZA_PROVIDERS')


######################################################################
# ��� � ����� ����������� ����� ������� � �������� �����/������, ����
# ������ � ������� ������.

define(MAIN_BEGIN,`<html>
<head>
  <LINK href="main.css" rel="stylesheet" type="text/css">
  <script type="text/JavaScript" src="site.js"></script>
  <script type="text/JavaScript" src="main.js"></script>

  <script>
    function publish(id) { alert("OK"); };
    // show/hide popup
    function div_show(id) { document.getElementById(id).style.display = "block"; }
    function div_hide(id) { document.getElementById(id).style.display = "none"; }
  </script>
</head>
<body onload="on_load()" class="ltblue">
')

define(MAIN_END,`</body>
</html>')


# ����� ����: ���� ��� ����� ��������� �� �������, �� � ������ ����������� ����� active:
define(MENU_BUTTON, `<a href="$1" class="button ifelse(FILE_NAME, $1, `active')">$2</a>')

define(MAIN_PANEL_BEGIN,`
  <!-- Main table -->
  <table valign=top width=100% height=100% cellspacing=0 cellpadding=5>

    <!--Top menu, login/logout buttons -->
    <tr height=1%><td>
    <table><tr>
      <td>MENU_BUTTON(main.htm,  `�������')</td>
      <td>MENU_BUTTON(pcat.htm,  `������')</td>
      <td>MENU_BUTTON(texts.htm, `������')</td>
      <td>MENU_BUTTON(map.htm,   `�����')</td>
      <td>MENU_BUTTON(help.htm,  `�������')</td>
      <td width = 100% align=right class="login_panel"> </td>
    </tr></table>
    </td></tr>
    <!-- Main frame -->
    <tr><td class="mainframe" heigth=100% valign=top>')

define(MAIN_PANEL_END,`
    <!-- End of Main frame -->
    </td></tr>
  </table>')

divert