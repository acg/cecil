#!/usr/bin/env perl

package TopoSort;

use warnings;
use strict;

use base qw/ Exporter /;
our @EXPORT_OK = qw/ tsort /;

# From http://everything2.com/title/topological+sort+in+Perl

sub tsort
{
  my @out = @_;
  my @ret;

  # Compute initial in degrees
  my @ind;
  for my $l (@out) {
    ++$ind[$_] for (@$l)
  }

  # Work queue
  my @q;
  @q = grep { ! $ind[$_] } 0..$#out;

  # Loop
  while (@q) {
    my $el = pop @q;
    $ret[@ret] = $el;
    for (@{$out[$el]}) {
      push @q, $_ if (! --$ind[$_]);
    }
  }

  return @ret == @out ? @ret : undef;
}

1;

