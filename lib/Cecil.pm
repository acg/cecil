package Cecil;

use Template;  # Template::Toolkit
use URI;
use URI::QueryParam;
use HTTP::Response;
use TopoSort qw/ tsort /;
use TimeUtil qw/ timeparts timetrunc friendly_time parse_timezstamp /;
use open ':encoding(utf8)';
use open ':std';
use warnings;
use strict;


our %DEFAULT_CONFIG =
(
  summary_fields => [ qw(Id Status Owner Progress DueDate Updated Summary) ],
  issue_fields => [ qw(Id Parent Summary Status AssignedTo CreatedBy Inserted Updated) ],
  theme => 'steelblue',
);

# FIXME this should be determined by reading .cil
our %OPEN_STATUSES =
(
  New => 1,
  Open => 1,
  InProgress => 1,
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
  my $param = $uri->query_form_hash;

  if ($path eq '/' || $path eq '/summary.html') {
    $data = summary_page_data( $config, $issues_dir, $param );
  }
  elsif ($path =~ m{^/i_([A-Fa-f0-9]+)\.html$}) {
    $data = issue_page_data( $config, $issues_dir, $1, $param );
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


### FIXME No methods beyond this point, just free functions. Refactor.


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
  my %param = %{ shift || {} };

  ### Set up the per-field filters.

  my %filter_configs =
  (
    Id => {
      type => 'select',
      matches => sub { $_[1]->{TreePath} =~ m#(^|/)\Q$_[0]->{value}\E($|/)# },
      options => [ { value => '', text => '- Root -' } ],
    },
    Status => {
      type => 'select',
      matches => sub { $_[1]->{$_[2]} eq $_[0]->{value} },
      options => [ { value => '', text => '-' } ],
    },
    Owner => {
      type => 'select',
      matches => sub { $_[1]->{$_[2]} eq $_[0]->{value} },
      options => [ { value => '', text => '-' } ],
    },
    Summary => {
      type => 'text',
      matches => sub { $_[1]->{$_[2]} =~ /\Q$_[0]->{value}\E/ },
      size => '40',
    },
  );

  my %filters;
 
  while (my ($field, $filter_config) = each %filter_configs)
  {
    my $filter = $filters{$field} = { %$filter_config };
    $filter->{value} = $param{"filters.value.$field"}||'';
  }    


  ### Load the timesheet files.

  my @timesheet_files = glob( "$issues_dir/t_*.cil" );
  my @timelogs = map @$_ => map load_timesheet( $_ ) => @timesheet_files;


  ### Load the issues.

  my @issue_files = glob( "$issues_dir/i_*.cil" );
  my @issues = map load_issue( $_, headers => 1 ) => @issue_files;

  ### Topologically sort the issues in the Parent relationship graph.
  ### This is done so iteration can proceed from child-to-parent
  ### or parent-to-child.

  my %issue_indices = do { my $i=0; map { ("$_->{Id}", $i++) } @issues };
  my @issue_deps = map { [ $issue_indices{$_->{Parent}||''} || () ] } @issues;
  my @issue_tsort = tsort( @issue_deps );
  die "cyclic parent dependencies" if @issues != @issue_tsort;
  @issues = map $issues[$_] => @issue_tsort;

  my %issues = map { ($_->{Id}, $_) } @issues;


  ### Assign depth and path for tree view.
  ### Iterate in child-to-parent order.

  for my $issue (reverse @issues)
  {
    my $parent = $issues{$issue->{Parent}||''};
    $issue->{Depth} = $parent ? $parent->{Depth}+1 : 0;
    $issue->{TreePath} = $parent ? $parent->{TreePath}.'/'.$issue->{Id} : $issue->{Id};
  }

  ### Sort the issues. By default, sort by path in the tree.

  @issues = sort { $a->{TreePath} cmp $b->{TreePath} } @issues;


  ### Build the list of issues to show in the ui.
  ### Go in child to parent order so Estimated and Worked can
  ### be accumulated in the parent issue.

  my @issues_ui;

  for my $issue (reverse @issues)
  {
    ### Calculate derived fields; do formatting.

    $issue->{Owner} = $issue->{AssignedTo};
    $issue->{Owner} ||= "Nobody";
    $issue->{Owner} =~ s/\s*<\S+\@\S+>\s*$//;

    if (!defined $issue->{Worked})
    {
      $issue->{Worked} = 0.0;
      $issue->{Worked} += ($_->{time1} - $_->{time0}) for
        grep $_->{issue} eq $issue->{Id} => @timelogs;
      $issue->{Worked} /= 3600;
    }

    $issue->{Worked} = sprintf "%.1f" => $issue->{Worked};
    $issue->{Estimated} ||= 0.0;
    $issue->{Progress} = "$issue->{Worked} / $issue->{Estimated}";

    ### Accrue Worked / Estimated to Parent issue, if there is one.

    my $parent = $issues{$issue->{Parent}||''};

    if ($parent) {
      $parent->{Worked} ||= 0.0;
      $parent->{Worked} += $issue->{Worked};
      $parent->{Estimated} ||= 0.0;
      $parent->{Estimated} += $OPEN_STATUSES{$issue->{Status}} ?
        $issue->{Estimated} : $issue->{Worked};
    }


    ### Apply any filters. See if this issue should be skipped.

    my $skip_issue = 0;

    while (my ($key, $filter) = each %filters)
    {
      $filter->{value} or next;
      $skip_issue ||= !$filter->{matches}( $filter, $issue, $key );
    }


    ### Build typed data fields for presentation layer.

    my $issue_ui = {};

    while (my ($key, $value) = each %$issue)
    {
      if ($key eq 'Id' || $key eq 'Summary')
      {
        $issue_ui->{$key} = {
          type => 'Link',
          url => "i_$issue->{Id}.html",
          text => $value,
          title => ($key eq 'Id' ? $issue->{Summary} : ''),
        };
      }
      elsif ($key eq 'Parent')
      {
        $issue_ui->{$key} = {
          type => 'Link',
          url => $parent ? "i_$issue->{Parent}.html" : "#",
          text => $value,
          title => $parent ? $parent->{Summary} : "",
        };
      }
      elsif (($key eq 'DueDate' || $key eq 'Updated') && $value ne '')
      {
        my $utc = parse_timezstamp( $value );
        my $friendly = friendly_time( $utc );

        $issue_ui->{$key} = {
          type => 'Date',
          text => $friendly,
          value => $utc,
        };
      }
      else
      {
        $issue_ui->{$key} = {
          type => 'String',
          text => $value,
          value => $value,
        };
      }

      ### Accumulate dropdown options for the select filters.

      if (my $filter = $filters{$key})
      {
        if ($filter->{type} eq 'select')
        {
          ### The Id filter actually filters by Parent (ancestor).

          my $filter_value = $value;
          $filter_value = ($issue->{Parent}||'') if $key eq 'Id';

          push @{$filter->{options}}, {
            value => $filter_value,
            text => $filter_value,
            active => 0+$filter->{matches}( $filter, $issue, $key ),
            title => $issue_ui->{$key}->{title} || "",
          };
        }
      }
    }


    ### Default any missing fields.

    for my $key (@{ $config->{summary_fields} }) {
      $issue_ui->{$key} ||= {
        type => 'String',
        text => "",
        value => "",
      };
    }

    unshift @issues_ui, $issue_ui unless $skip_issue;
  }


  ### Sort the filter dropdown values, remove duplicates.

  for my $filter (values %filters)
  {
    if ($filter->{type} eq 'select')
    {
      my %seen;

      @{ $filter->{options} } =
        sort { $a->{value} cmp $b->{value} }
          grep !$seen{$_->{value}}++ => @{ $filter->{options} };
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
    issues => \@issues_ui,
    filters => \%filters,
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


sub load_timesheet
{
  my $file = shift;

  open my $fh, '<', $file or
    die "open error for $file: $!";

  my @cols = qw( issue status time0 time1 comment );
  my @records;

  while (<$fh>)
  {
      chomp;
      my @fields = split /\t/, $_, 0+@cols;
      my %record = map { $cols[$_] => $fields[$_] } (0 .. @cols-1);
      $record{$_} = $record{$_} ? parse_timezstamp( $record{$_} ) : +time for qw/ time0 time1 /;
      push @records, \%record;
  }

  close $fh or
    die "close error for $file: $!";

  return \@records;
}


1;

