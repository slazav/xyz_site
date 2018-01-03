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
#       In href argument word 'javascript:' is removed.
#     Tag 'font' with arguments 'size', 'color'
#     Tag 'lj-cut' with argument 'text'
#  Replace newline characters by <br>.
#  Close all tags properly.
#  Http(s) links are wrapped with <a>

BEGIN {
  require Exporter;
  our $VERSION = 1.00;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(cleanup_txt cleanup_int cleanup_htm);
}

################################################

use strict;
use warnings;
use HTML::Parser;

## get plain text parameter: convert <>& to &lt;, &gt;, &amp;
## cut too long input
sub cleanup_txt {
  my $inp    = shift || '';
  my $maxlen = shift || 10000;
  $inp = substr($inp, 0, $maxlen) if $maxlen && length($inp)>$maxlen;
  $inp =~ s/</&lt;/g;
  $inp =~ s/>/&gt;/g;
  return $inp;
}

## get integer parameter:
sub cleanup_int {
  return (shift=~/^([0-9]{1,10})/)? $1:(shift||0);
}


# get html parameter: remove all tags except safe ones
sub cleanup_htm {
  my $inp    = shift;
  my $maxlen = shift || 10000;
  $inp = substr($inp, 0, $maxlen) if $maxlen && length($inp)>$maxlen;

  our $out='';
  our @tags;

  # text handler: wrap http/https refs (if we are not in <a>), print raw text
  sub text_h {
    my $text = shift;
    $text =~ s|\b(https?://\S*)|<a href="$1">$1</a>|ig
      if $#tags<0 || $tags[$#tags] ne 'a';
    $text =~ s/\n/\n<br>/g;
    $out.=$text;
  }

  # start tags
  sub start_h {
    my $t = shift;
    my $a = shift;

    # simple open tags: all argumens are skipped
    foreach my $tt ('b', 'em', 'h1', 'h2', 'h3', 'h4', 'i', 'li', 'ol', 'p', 'pre',
                    's', 'sup', 'sub', 'tt', 'ul'){
      next if $tt ne $t;
      $out.="<$t>";
      push @tags, $t;
      return;
    }
    # simple only-open tags
    foreach my $tt ('br', 'hr'){
      next if $tt ne $t;
      $out.="<$t>";
      return;
    }

    # img tag: src, height, width, alt attributes
    if ($t eq "img"){
      my $attrs='';
      foreach my $an ('src', 'height', 'width', 'alt'){
        $attrs .= " $an=\"$a->{$an}\"" if exists $a->{$an};
      }
      $out.="<$t$attrs>"; return;
    }
    # a tag: name, href attributes, javascript filter
    if ($t eq "a"){
      my $attrs='';
      $attrs .= " name=\"$a->{name}\"" if exists $a->{name};
      $attrs .= " href=\"$a->{href}\"" if exists $a->{href} && $a->{href} !~ /^\s*javascript:/i;
      $out.="<$t$attrs>"; push @tags, $t; return;
    }
    # font tag: size, color attributes
    if ($t eq "font"){
      my $attrs='';
      foreach my $an ('size', 'color'){
        $attrs .= " $an=\"$a->{$an}\"" if exists $a->{$an};
      }
      $out.="<$t$attrs>"; push @tags, $t; return;
    }
    # lj-cut tag: text attribute
    if ($t eq "lj-cut"){
      my $attrs='';
      foreach my $an ('text'){
        $attrs .= " $an=\"$a->{$an}\"" if exists $a->{$an};
      }
      $out.="<$t$attrs>"; push @tags, $t; return;
    }

  }
  sub end_h {
    my $t = shift;
    foreach my $tt ('b', 'em', 'h1', 'h2', 'h3', 'h4', 'i', 'li', 'ol', 'p', 'pre',
                    's', 'sup', 'sub', 'tt', 'ul', 'a', 'font'){
      next if $tt ne $t;
      # close all unclosed tags:
      while ($#tags>-1) {
        my $tn=$tags[$#tags];
        $out.="</$tn>";
        $#tags--;
        return if $tn eq $t;
      }
      return;
    }
  }

  sub endd_h {
    # close all unclosed tags:
    while ($#tags>-1) {
      $out.="</$tags[$#tags]>";
      $#tags--;
    }
  }

  my $P = HTML::Parser->new(text_h  => [\&text_h,  'text'],
                            start_h => [\&start_h, 'tagname, attr'],
                            end_h   => [\&end_h,   'tagname'],
                            end_document_h   => [\&endd_h] );
  $P->empty_element_tags(1);

  $P->parse($inp) || die $!;
  $P->eof;

  return $out;
}

################################################

1;
