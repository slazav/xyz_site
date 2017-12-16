package safe_html;

# Cleanup txt/html input to get safe html.
#
# cleanup_txt $inp, $maxlen:
#   Replace <,>,& by &lt;, &gt;, &amp;, cut to $maxlen
#
# cleanup_htm $inp, $maxlen:
#   Remove all html tags and all tag arguments except:
#     Open/close tags 'b', 'i', 'ul', 'ol', 'li', 'p', 'br', 'hr' (no arguments).
#     Tag 'img' with arguments 'src', 'width', 'height', 'alt'.
#     Tag 'a'   with arguments 'name', 'href'.
#     In href argument word 'javascript:' is removed.
#     All arguments should be quoted by ' or ".

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(cleanup_txt cleanup_htm);
}

#!/usr/bin/perl

################################################

use strict;
use warnings;

## get plain text parameter: convert <>& to &lt;, &gt;, &amp;
## cut too long input
sub cleanup_txt {
  my $inp    = shift;
  my $maxlen = shift;
  $inp = substr($inp, 0, $maxlen) if length($inp)>$maxlen;
  $inp =~ s/&/&amp;/g;
  $inp =~ s/</&lt;/g;
  $inp =~ s/>/&gt;/g;
  return $inp;
}

#  extract a given argument from argument list
sub get_arg {
  my $line = shift;
  my $a = shift;
  $line =~ m/\b$a=([\'\"]?)([^\1>]*?)\1/i;
  return $2? " $a=$1$2$1" : "";
}

# get html parameter: remove all tags except safe ones
sub cleanup_htm {
  my $inp    = shift;
  my $maxlen = shift;
  my $out = '';
  $inp = substr($inp, 0, $maxlen) if length($inp)>$maxlen;

  # cut text + one html tag from the beginning
  while ( $inp =~ s/^([^<]*)(<[^>]*?>)?//s ){
    my $txt = $1;
    my $htm = $2 || '';
    last unless $txt || $htm; # string was empty
    $txt =~ s/&/&amp;/g;
    $txt =~ s/</&lt;/g;
    $txt =~ s/>/&gt;/g;
    $htm =~ s/[^^]</&lt;/g; # if can appears inside arguments

    $out .= $txt;

    # simple open/close tags: all argumens are skipped
    foreach my $t ('b', 'i', 'ul', 'ol', 'li', 'p', 'br', 'hr'){
      if ($htm =~ m|^<(/?$t)[/\s>]|i) { $out .= "<$1>"; last;}
    }

    # close tags for a, img
    foreach my $t ('a', 'img'){
      if ($htm =~ m|^<(/$t)[\s>]|i) { $out .= "<$1>"; last;}
    }

    # img tag
    if ($htm =~ m|<img\b\s*([^>]*)>|i){
      my $iargs = $1;
      my $oargs = '';
      foreach my $a ('src', 'height', 'width', 'alt'){
        $oargs .= get_arg $iargs, $a;
      }
      $out .= "<img$oargs>";
    }

    if ($htm =~ m|<a\b\s*([^>]*)>|i){
      my $iargs = $1;
      my $oargs = '';
      foreach my $a ('href', 'name'){
        my $v = get_arg $iargs, $a;
        $v = '' if $a eq 'href' &&  $v =~ /[\"\']\s*javascript:/i;
        $oargs .= $v;
      }
      $out .= "<a$oargs>";
    }

  }
  return $out;
}


################################################

1;
