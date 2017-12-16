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

###### cleanup_htm ######

assert "htm: simple text",
cleanup_htm('
test1 test2
test3', 100), '
test1 test2
test3';

assert "htm: too long simple txt",
cleanup_htm('
test1 test2
test3', 10), '
test1 tes';

assert "htm: basic html",
cleanup_htm('
  <b something>b</b><i>i</i something> <p something>p</p>
  <B>B</B>
  <ul>ul</ul> <ol>ol</ol><li>li</li> <br > <hr/> <script>script</script>', 300),
'
  <b>b</b><i>i</i> <p>p</p>
  <B>B</B>
  <ul>ul</ul> <ol>ol</ol><li>li</li> <br> <hr> script';

assert "htm: too long",
cleanup_htm('
  <b something>b</b><i>i</i something> <p something>p</p>
  <ul>ul</ul> <ol>ol</ol><li>li</li> <br > <hr/> <script>script</script>', 30),
'
  <b>b</b><i>i';


assert "safe_html::get_arg 1",
safe_html::get_arg('src="a" width="10" heigh="20"', 'width'), ' width="10"';

assert "safe_html::get_arg 2",
safe_html::get_arg('src="a" width=\'10\' heigh="20"', 'width'), ' width=\'10\'';

assert "safe_html::get_arg 3",
safe_html::get_arg('src="a" width=10 heigh="20"', 'width'), '';

assert "safe_html::get_arg 4",
safe_html::get_arg('src="a" width=\'10" heigh="20\'', 'width'), ' width=\'10" heigh="20\'';

assert "safe_html::get_arg 5",
safe_html::get_arg('src="a" width=\'10" heigh="20"', 'width'), '';

assert "safe_html::get_arg 6",
safe_html::get_arg('src="a" width="<>" heigh="20"', 'width'), '';


assert "htm: img tag",
cleanup_htm('
  <img width="10" height="20" src="aaa">
  <imga src="1">
  <img onclick="bbb" src="a" width=12 height=\'<>\'>', 300),
'
  <img src="aaa" height="20" width="10">
  
  <img src="a">\'&gt;';

assert "htm: a tag",
cleanup_htm('
  <a href="aaa"></a> <a>
  <aa src="1">
  <a href="javascript:alert(1);" name="a">text</a>', 300),
'
  <a href="aaa"></a> <a>
  
  <a name="a">text</a>';

assert "htm: javascript",
cleanup_htm('
  <a href="javascript: a"></a>
  <a href=" javascript: a"></a>
  <a href=" JavaScript: a"></a>', 300),
'
  <a></a>
  <a></a>
  <a></a>';





