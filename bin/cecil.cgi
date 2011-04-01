#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::RealBin/../lib";
use Cecil;
use HTTP::Request;
use warnings;
use strict;

my %config =
(
  %Cecil::DEFAULT_CONFIG,
  prefix => "$FindBin::RealBin/..",
  issues_dir => $ENV{CIL_ISSUES} || "$FindBin::RealBin/../issues",
  theme => 'forest',
);

my $cecil = Cecil->new( \%config );
my $request = cgienv_to_http( \%ENV );
my $response = $cecil->handle( $request );
print $response->headers_as_string."\r\n";
print $response->content;
exit 0;


sub cgienv_to_http
{
  my $env = shift;

  my ($method, $uri, $query) =
    @{$env}{qw/ REQUEST_METHOD REQUEST_URI QUERY_STRING /};

  if ($method eq 'GET' && defined $query && length $query) {
    $uri .= "?$query";
  }

  my @cgi_headers = qw(
    Http-Connection
    Http-Referer
    Http-Host
    Http-UserAgent
    Content-Length
    Content-Type
  );

  my @headers;

  for my $name (@cgi_headers) {
    my $env_name = uc $name; $env_name =~ s/-/_/g;
    my $env_value = $env->{$env_name};
    push @headers, $name, $env_value if defined $env_value;
  }

  my $request = HTTP::Request->new( $request, $uri, \@headers );

  return $request;
}

