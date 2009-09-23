#!/usr/bin/perl

use strict;
use warnings;

use JIRA::Client;
use Text::CSV;


my $user          = 'jirauser';
my $password      = 'jirapass'; 
my $jira_base_url = 'http://jira.rubiconproject.com/jira';

my @filters = (
    'saved filter 1',
    'saved filter 2',
    );

my $issue_count_for_filter;
my $id_for_filter;

my $jira = JIRA::Client->new( $jira_base_url, $user, $password );

LOAD_SAVED_FILTERS:
{
    my $saved_filters = $jira->getSavedFilters();

    foreach my $filter (@$saved_filters)
    {
        my $id   = $filter->{id};
        my $name = $filter->{name};

        $id_for_filter->{$name} = $id;
    }
}

LOAD_FILTER_DATA:
{
FILTER:
    foreach my $filter_name ( @filters )
    {
        my $filter_id = $id_for_filter->{$filter_name};
        unless ($filter_id)
        {
            print STDERR "unknown filter: $filter_name\n";
            next FILTER;
        }
        $issue_count_for_filter->{$filter_name}
            = $jira->getIssueCountForFilter($filter_id);
    }
}
print_via_csv();

sub print_via_csv
{
    my @headers = qw( id name count date time );
    my $csv     = Text::CSV->new();

    my @lt          = localtime();
    my $date        = strftime( "%Y-%m-%d", @lt );
    my $time_of_day = strftime( "%H:%M", @lt );

    $csv->combine(@headers);
    print $csv->string(), "\n";

    foreach my $filter ( @{filters} )
    {
        $csv->combine
        (
            $id_for_filter->{$filter},
            $filter, 
            $issue_count_for_filter->{$filter},
            $date,
            $time_of_day
        );

        print $csv->string, "\n";
    }
}
