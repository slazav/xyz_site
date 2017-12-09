divert(-1)

define(LOGINZA_PROVIDERS, `livejournal,facebook,vkontakte,yandex,google')

define(FACEBOOK_LOGIN_URL, `https://www.facebook.com/dialog/oauth?client_id=FACEBOOK_ID&redirect_uri=SITE_URL/cgi/login_fb.pl&response_type=code')
define(GOOGLE_LOGIN_URL,   `https://accounts.google.com/o/oauth2/auth?redirect_uri=SITE_URL/cgi/login_google.pl&response_type=code&client_id=GOOGLE_ID&scope=https://www.googleapis.com/auth/userinfo.profile')
define(LOGINZA_LOGIN_URL,  `https://loginza.ru/api/widget?token_url=SITE_URL/cgi/login_loginza.pl&providers_set=LOGINZA_PROVIDERS')

divert