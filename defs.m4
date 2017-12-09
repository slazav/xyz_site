divert(-1)

Здесь не должно быть секретных данных.
Все ключи - в cgi/...

define(SITE_URL,
ifelse(SITE_NAME, test,  `http://test.slazav.xyz',
       SITE_NAME, main,  `http://slazav.xyz',
       SITE_NAME, mccme, `http://slazav.mccme.ru'))

define(LOGINZA_ID,
ifelse(SITE_URL, `http://slazav.mccme.ru', 11907,
       SITE_URL, `http://slazav.xyz',      75945,
       SITE_URL, `http://test.slazav.xyz', 75947))

define(FACEBOOK_ID, 724695174390511)

define(GOOGLE_ID,  846272225759-3uti46s777n9kggqag6g305cm0h395dl.apps.googleusercontent.com)

divert