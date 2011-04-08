#!/usr/bin/env perl

package TimeUtil;

use HTTP::Date qw/ str2time /;
use POSIX qw/ strftime mktime /;
use warnings;
use strict;

use base qw/ Exporter /;

our @EXPORT_OK = qw/
  friendly_time
  timeparts
  timetrunc
  parse_timezstamp
/;

our @TIMEPARTS = qw/ sec min hour mday mon year wday yday isdst /;


sub friendly_time
{
  my $time = shift;
  my $now = time;
  my $timex = timeparts( localtime $time );
  my $nowx = timeparts( localtime $now );
  my $sign = ($time<$now) ? -1 : (($time>$now) ? 1 : 0);
  my $oneweek = timetrunc( 'mday', localtime( $now + $sign * 7 * 24 * 3600 ) );
  my $fewdays = timetrunc( 'mday', localtime( $now + $sign * 2 * 24 * 3600 ) );
  my $today = timetrunc( 'mday', localtime $now );
  my $tomorrow = timetrunc( 'mday', localtime( $now + 24 * 3600 ) );
  my $fmt;

  if ($timex->{year} != $nowx->{year}) {
    $fmt = "%b %e, %Y %l:%M%P";
  }
  elsif (($sign < 0 && $time < $oneweek) || ($sign > 0 && $time >= $oneweek)) {
    $fmt = "%b %e %l:%M%P";
  }
  elsif ($sign < 0 && $time < $fewdays) {
    $fmt = "Last %A %l:%M%P";
  }
  elsif ($sign > 0 && $time > $fewdays) {
    $fmt = "This %A %l:%M%P";
  }
  elsif ($time < $today) {
    $fmt = "Yesterday %l:%M%P";
  }
  elsif ($time >= $tomorrow) {
    $fmt = "Tomorrow %l:%M%P";
  }
  elsif (abs($now - $time) >= 12 * 3600) {
    $fmt = "Today %l:%M%P";
  }
  elsif ($now - $time >= 3600) {
    $fmt = sprintf "%d hours ago" => int(($now - $time)/3600);
  }
  elsif ($time - $now <= 3600) {
    $fmt = sprintf "in %d hours" => int(($time - $now)/3600);
  }
  elsif ($now - $time <= 60) {
    $fmt = sprintf "%d minutes ago" => int(($now - $time)/60);
  }
  elsif ($time - $now >= 60) {
    $fmt = sprintf "%d minutes ago" => int(($time - $now)/60);
  }
  else {
    $fmt = "just now";
  }

  return strftime( $fmt, localtime $time );
}


sub timeparts
{
  my @time = @_;
  my %parts;
  @parts{@TIMEPARTS} = @time;
  return \%parts;
}


sub timetrunc
{
  my $component = shift;
  my @time = @_;
  my $parts = timeparts( @time );
  my $trunc = 0;

  for my $name (reverse @TIMEPARTS) {
    $parts->{$name} = 0 if $trunc;
    $trunc ||= $name eq $component;
  }

  return mktime( @{$parts}{@TIMEPARTS} );
}


sub parse_timezstamp
{
  my $timestamp = shift;
  my $zone = ($timestamp =~ s/\s*Z?([+-]?\d\d\d\d)$// and $1 or undef);
  return str2time( $timestamp, $zone );
}


1;

