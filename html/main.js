/*
on_load
 -> update_my_info
    -> logout
 -> update_user_list
    -> on_set_level

*/

/////////////////////////////////////////////////////////////////
// do request to a cgi script, call callback() or process_err()
function do_request(action, args, callback){
  var xhttp = new XMLHttpRequest();

  // convert args object to a GET string
  var str = [];
  for(var p in args)
    if (args.hasOwnProperty(p)) {
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(args[p]));
    }
  args = str.join("&");

  xhttp.onreadystatechange = function() {
    if (xhttp.readyState == 4 && xhttp.status == 200) {
      if (xhttp.responseText == ""){ return; }
      try {
        var data = JSON.parse(xhttp.responseText);
      }
      catch(e){
        var data = {error_type: "xhttp",
                    error_message: xhttp.responseText};
      }
      if (data.error_message){ process_err(data); }
      else { callback(data);}
    }
  };
  xhttp.open("GET", 'cgi/' + action + '.pl'
                  + '?t=' + Math.random() + "&" + args, true);
  xhttp.send();
}

/////////////////////////////////////////////////////////////////
// process error
function process_err(data){
  alert(data.error_type + " error: " + data.error_message);
}

/////////////////////////////////////////////////////////////////
// get URL parameters
// See: https://stackoverflow.com/questions/979975/how-to-get-the-value-from-the-get-parameters
function get_params() {
  var qs = document.location.search;
  qs = qs.split('+').join(' ');
  var params = {}, tokens, re = /[?&]?([^=]+)=([^&]*)/g;
  while (tokens = re.exec(qs)) {
    params[decodeURIComponent(tokens[1])] = decodeURIComponent(tokens[2]);
  }
  return params;
}

/////////////////////////////////////////////////////////////////
// This function is run once after loading any html page
// It runs following functions:
//  - update_my_info (user information)
//  - update_user_list (user list if any)
function on_load(){

  // we always want to check user information and fill the login form
  document.cookie = "RETPAGE=" + document.URL;
  do_request('my_info', {}, update_my_info);
}

document.addEventListener("DOMContentLoaded", on_load);

/////////////////////////////////////////////////////////////////
// make user face (external account information)
function mk_face(id, name, site){
  if (id == undefined) return '';
  var mk_icon = function(site){
      if (site == 'vk') return 'img/vk.png';
      if (site == 'lj') return 'img/lj.gif';
      if (site == 'fb') return 'img/fb.png';
      if (site == 'yandex') return 'img/ya.png';
      if (site == 'google') return 'img/go.png';
      if (site == 'gplus')  return 'img/gp.png';
      if (site == 'mailru') return 'img/mr.gif';
      return "";};
  return '<span class="user_face"><a href="' + id + '">'
       + '<img class="login_img" src="' + mk_icon(site) + '">'
       + '<b>' + name + '</b></a></span>'
}

/////////////////////////////////////////////////////////////////
// make login/logout button
function mk_loginbtn(id, name, site){
  if (id == undefined) {
    return 'войти: '
     + '<a class="login_btn" href="' + facebook_login_url + '"><img class="login_img" alt="Facebook" src="img/fb.png"></a> '
     + '<a class="login_btn" href="' + google_login_url   + '"><img class="login_img" alt="Google"   src="img/go.png"></a> '
     + '<a class="login_btn" href="' + loginza_login_url  + '"><img class="login_img" alt="Loginza"  src="img/loginza.png"></a> ';
  }
  else {
    return mk_face(id, name, site)
      + ' <a class="login_btn" href="javascript:do_request(\'logout\', {}, update_my_info)">выйти</a>';
  }
}

/////////////////////////////////////////////////////////////////
// Russion level names
var mk_rlevel = function(l) {
  if (l == -1) return 'ограниченный';
  if (l == 0) return 'обычный';
  if (l == 1) return 'модератор';
  if (l == 2) return 'администратор';
  if (l == 100) return 'самый главный';
  return null;};

/////////////////////////////////////////////////////////////////
// Convert unix timestamp to date YYYY-MM-DD
function tstamp2date(tstamp){
  var a = new Date(tstamp * 1000);
  var y = a.getFullYear();
  var m = ("0" + a.getMonth()).substr(-2);
  var d = ("0" + a.getDate()).substr(-2);
//  var H = a.getHours();
//  var M = a.getMinutes();
//  var S = a.getSeconds();
  return y + '-' + m + '-' + d;
}


/////////////////////////////////////////////////////////////////
// update user information
function update_my_info(data){
  var ll = document.getElementsByClassName("login_panel");
  for (i=0; i<ll.length; i++){
    ll[i].innerHTML = mk_loginbtn(data._id, data.name, data.site); }

  var ll = document.getElementsByClassName("user_rlevel");
  for (i=0; i<ll.length; i++){
    ll[i].innerHTML = mk_rlevel(data.level); }

  var ll = document.getElementsByClassName("user_level");
  for (i=0; i<ll.length; i++){
    ll[i].innerHTML = data.level; }

  // open objects with is_normal class
  if (data.level >= 0) {
    var ll = document.getElementsByClassName("is_normal");
    for (i=0; i<ll.length; i++){ ll[i].style.visibility = "visible";}
  }
  // open objects with is_moder class
  if (data.level >= 1) {
    var ll = document.getElementsByClassName("is_moder");
    for (i=0; i<ll.length; i++){ ll[i].style.visibility = "visible"; }
  }
  // open objects with is_admin class
  if (data.level >= 2) {
    var ll = document.getElementsByClassName("is_admin");
    for (i=0; i<ll.length; i++){ ll[i].style.visibility = "visible"; }
  }

}

/////////////////////////////////////////////////////////////////
// for use with do_request; ignore data and reload page
function do_reload(data){ location.reload(); }

function on_logout(){
  do_request('logout', {}, do_reload);
}
function on_set_level(id,level){
  do_request('set_level', {id: id, level: level}, do_reload);
}
function on_news_write(){
  var f = document.getElementById("news_form");
  args = {};
  args.id    = f.id.value;
  args.title = f.title.value;
  args.text  = f.text.value;
  args.type  = f.type.value;
  do_request('news_write', args, after_news_write);
}
function after_news_write(data) {
  hide('news_popup');
  document.getElementById("news_form").reset();
  location.reload();
}

function on_news_delete(id){
  do_request('news_delete', {id: id, del: 1}, do_reload);
  hide("news_del_popup");
}
function on_news_undel(id){
  do_request('news_delete', {id: id, del: 0}, do_reload);
}

function on_com_add(id){
}
function on_com_edit(id){
}
function on_com_delete(id){
  do_request('com_delete', {id: id}, do_reload);
}

/////////////////////////////////////////////////////////////////
// working with news

function show(id) { document.getElementById(id).style.display = "block"; }
function hide(id) { document.getElementById(id).style.display = "none"; }


