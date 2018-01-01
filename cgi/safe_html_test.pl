#!/usr/bin/perl
use warnings;
use strict;
use safe_html;

sub assert{
  my $t = shift;
  my $i = shift;
  my $o = shift;

  die "ERROR: $t\nIN> $i\nOUT> $o\n"
    if $i ne $o;
  print "OK: $t\n";
}

###### cleanup_txt ######

# simple txt
assert "txt: simple text",
cleanup_txt('
test1 test2
test3', 100), '
test1 test2
test3';

# too long simple txt
assert "txt: too long simple text",
cleanup_txt('
test1 test2
test3', 10), '
test1 tes';

# html
assert "txt: html",
cleanup_txt('
<a href="http://localhost"
>text</a>', 100),'
&lt;a href="http://localhost"
&gt;text&lt;/a&gt;';

assert "int 1",
cleanup_int('123<a href="http://localhost"'), 123;

assert "int 2",
cleanup_int('123456789012<a href="http://localhost"'), 1234567890;

assert "int 3",
cleanup_int('a123456789012<a href="http://localhost"'), 0;

assert "int 4",
cleanup_int('',5), 5;

###### cleanup_htm ######

assert "htm: simple text",
cleanup_htm('
test1 test2
test3', 100), '
<br>test1 test2
<br>test3';

assert "htm: too long simple txt",
cleanup_htm('
test1 test2
test3', 10), '
<br>test1 tes';

assert "htm: basic html",
cleanup_htm('
  <b something>b</b><i>i</i something> <p something>p</p>
  <b>B</b>
  <ul>ul</ul> <ol>ol</ol><li>li</li> <br > <hr/> <script>script</script>', 300),
'
<br>  <b>b</b><i>i</i> <p>p</p>
<br>  <b>B</b>
<br>  <ul>ul</ul> <ol>ol</ol><li>li</li> <br> <hr> script';

assert "htm: too long/close tag",
cleanup_htm('
  <b something>b</b><i>i</i something> <p something>p</p>
  <ul>ul</ul> <ol>ol</ol><li>li</li> <br > <hr/> <script>script</script>', 30),
'
<br>  <b>b</b><i>i</i>';

assert "htm: close tags",
cleanup_htm('
  <a>a<b><br><a><b></a>', 100),
'
<br>  <a>a<b><br><a><b></b></a></b></a>';


assert "htm: img tag",
cleanup_htm('
  <img width="10" height="20" src="aaa">
  <imga src="1">
  <img onclick="bbb" src="a" width=12 height=\'<>\'>', 300),
'
<br>  <img src="aaa" height="20" width="10">
<br>  
<br>  <img src="a" height="<>" width="12">';

assert "htm: a tag",
cleanup_htm('
  <a href="aaa"></a> <a>
  <aa src="1">
  <a href="javascript:alert(1);" name="a">text</a>', 300),
'
<br>  <a href="aaa"></a> <a>
<br>  
<br>  <a name="a">text</a></a>';

assert "htm: javascript",
cleanup_htm('
  <a href="javascript: a"></a>
  <a href=" javascript: a"></a>
  <a href=" JavaScript: a"></a>', 300),
'
<br>  <a></a>
<br>  <a></a>
<br>  <a></a>';

assert "htm: wrap refs",
cleanup_htm('
 <a
 href="http://abc">http://abc</a>
 http://def', 300),
'
<br> <a href="http://abc">http://abc</a>
<br> <a href="http://def">http://def</a>';




