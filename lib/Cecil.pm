package Cecil;

use Template;  # Template::Toolkit
use URI;
use HTTP::Response;
use HTTP::Date qw/ str2time /;
use POSIX qw/ strftime /;
use open ':encoding(utf8)';
use open ':std';
use warnings;
use strict;


our %DEFAULT_CONFIG =
(
  summary_fields => [ qw(Id Status Owner Progress DueDate Updated Summary) ],
  issue_fields => [ qw(Id Summary Status AssignedTo CreatedBy Inserted Updated) ],
  theme => 'steelblue',
);


sub new
{
  my $this = shift;
  my $class = ref $this || $this;
  my $config = shift;
  return bless { config => $config } => __PACKAGE__;
}


sub handle
{
  my $self = shift;
  my $request = shift;
  my $uri = URI->new($request->uri);
  my $config = $self->{config};
  my $issues_dir = $config->{issues_dir};
  my $data;

  my $path = $uri->path;

  if ($path eq '/' || $path eq '/summary.html') {
    $data = summary_page_data( $config, $issues_dir );
  }
  elsif ($path =~ m{^/i_([A-Fa-f0-9]+)\.html$}) {
    $data = issue_page_data( $config, $issues_dir, $1 );
  }
  else {
    die "unrecognized uri: $uri";
  }

  my $html = render_html( $config, $data );
  my $response = HTTP::Response->new( 200, 'OK' );
  $response->header( 'Content-Type', 'text/html' );
  $response->content( $html );
  return $response;
}


sub render_html
{
  my $config = shift;
  my $data = shift;

  my @tt_inc = (
    "$config->{prefix}/templates",
    "$config->{prefix}/templates/include"
  );

  my $tt = Template->new( {
    ABSOLUTE => 1,
    INCLUDE_PATH => join(":", @tt_inc),
  } ) or die "$Template::ERROR".$/;

  my $tt_vars = {
    %$config,
    %$data,
  };

  my $html = "";

  $tt->process( "$tt_inc[0]/$data->{page}->{template}", $tt_vars, \$html ) or
    die $tt->error.$/;

  return $html;
}


sub summary_page_data
{
  my $config = shift;
  my $issues_dir = shift;
  my @issues = map load_issue( $_, headers => 1 )
    => glob( "$issues_dir/i_*.cil" );


  for my $issue (@issues)
  {
    $issue->{Owner} = $issue->{AssignedTo};
    $issue->{Owner} ||= "Nobody";
    $issue->{Owner} =~ s/\s*<\S+\@\S+>\s*$//;

    if (exists $issue->{Worked})
    {
      my $sum = 0;

      for (@{ $issue->{Worked} }) {
        my ($email, $time0, $time1) = split( /\s+/, $_, 3 );
        $time0 = parse_timezstamp($time0);
        $time1 = $time1 ? parse_timezstamp($time1) : time;
        $sum += ($time1 - $time0);
      }

      $sum /= 3600;
      $sum = sprintf "%.1f", $sum;
      $issue->{Worked} = $sum;
    }

    $issue->{Worked} ||= 0.0;
    $issue->{Estimated} ||= 0.0;
    $issue->{Progress} = "$issue->{Worked} / $issue->{Estimated}";
    $issue->{Updated} = strftime( '%D %R' =>
      localtime parse_timezstamp( $issue->{Updated} ) );

    if (my $date = $issue->{DueDate}) {
      $issue->{DueDate} = strftime( '%D %R' =>
        localtime parse_timezstamp( $date ) );
    }

    my $Id = $issue->{Id};

    while (my ($key, $value) = each %$issue)
    {
      if ($key eq 'Id' || $key eq 'Summary')
      {
        $issue->{$key} = {
          type => 'Link',
          url => "i_${Id}.html",
          text => $value,
        };
      }
      else
      {
        $issue->{$key} = {
          type => 'String',
          text => $value,
          value => $value,
        };
      }
    }

    for my $key (@{ $config->{summary_fields} }) {
      $issue->{$key} ||= {
        type => 'String',
        text => "",
        value => "",
      };
    }

  }


  return {
    page => {
      name => 'summary',
      template => 'summary.tt.html',
      title => 'Summary of Issues',
      css => [
        'styles/reset.css',
        'styles/tablesorter.css',
        "styles/themes/$config->{theme}/main.css"
      ],
      js => [
        'js/jquery.min.js',
        'js/jquery.tablesorter.min.js',
        'js/jquery.main.js',
      ],
    },
    issues => \@issues,
  };
}


sub issue_page_data
{
  my $config = shift;
  my $issues_dir = shift;
  my $id = shift;
  my $issue = load_issue( "$issues_dir/i_${id}.cil" );

  return {
    page => {
      name => 'issue',
      template => 'issue.tt.html',
      title => "Issue #$issue->{Id}: $issue->{Summary}",
      css => [
        'styles/reset.css',
        "styles/themes/$config->{theme}/main.css",
      ],
      js => [ ],
    },
    issue => $issue,
  };
}


sub load_issue
{
  my $file = shift;
  my %opts = @_;

  open my $fh, '<', $file or
    die "open error for $file: $!";

  my %fields = (
    Id => ($file =~ m{i_([A-Fa-f0-9]+)\.cil$})[0],
  );

  my $body;
  my $in_headers = 1;
  my %array_fields = map {$_,1} qw/ Comment Worked /;

  while (<$fh>)
  {
    chomp;

    if ($in_headers)
    {
      if (/^(\w+):\s*(.*)$/) {
        my ($key, $value) = ($1, $2);

        if ($array_fields{$key}) {
          push @{ $fields{$key} }, $value;
        } else {
          $fields{$key} = $value;
        }
      }
      else {
        $in_headers = 0;
      }
    }
    else
    {
      last if $opts{headers} && $in_headers;
      $body = "" unless defined $body;
      $body .= $_."\n";
    }
  }

  $fields{Description} = $body if defined $body;

  close $fh or
    die "close error for $file: $!";

  ### TODO read comments

  return \%fields;
}


sub parse_timezstamp
{
  my $timestamp = shift;
  my $zone = ($timestamp =~ s/Z(.+)$// and $1 or undef);
  return str2time( $timestamp, $zone );
}


1;

