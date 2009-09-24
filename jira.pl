#!/usr/bin/perl

use strict;
use warnings;

use JIRA::Client;
use Text::CSV;
use Config::Auto;
use Getopt::Long;
use Pod::Usage;
use POSIX qw(strftime);

#
# We have a config file: jira.conf and a password file .jira
# Config::Auto will look for these anywhere in your path.
#

my $cfg = Config::Auto::parse("jira.conf");
my $credentials = eval { Config::Auto::parse(".jira") };    #optional

if ( defined $credentials )
{
    $cfg->{$_} = $credentials->{$_} for keys %$credentials;
}

my $show_headers = 1;
my $help         = 0;
my $man          = 0;

my $parse_success = GetOptions(
    "u|username=s"        => \$cfg->{username},
    "p|password=s"    => \$cfg->{password},
    "f|filter=s@" => \$cfg->{filter},
    "header!"         => \$show_headers,
    "h|help"          => \$help,
    "man"             => \$man,
);


my $user          = $cfg->{username};
my $password      = $cfg->{password};
my $jira_base_url = $cfg->{base_url}
    || 'http://jira.rubiconproject.com/jira';

pod2usage(2) if !$parse_success;
pod2usage(2) if !defined $password;
pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

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
    foreach my $filter_name ( @{ $cfg->{filter} } )
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

    if ($show_headers)
    {
        $csv->combine(@headers);
        print $csv->string(), "\n";
    }

    foreach my $filter ( @{ $cfg->{filter} } )
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

__END__

=head1 NAME

jira.pl - Simple script to demonstrate JIRA::Client.  Grabs bug counts from named Filters.

=head1 SYNOPSIS

jira.pl [options]
 
 Options:
  -username         jira username
  -password         jira password
  -filter           name of saved filter.  May be used multiple times

  -header           enables printing of CSV header
  --no-header       disables printing of CSV header

  -help             brief help message
  -man              full documentation


=head1 OPTIONS

=over

=item B<-username>

Jira username.

=item B<-password>

Jira password.  

=item B<-filter|-f>

These are the names of the saved filters to be queried for bug counts.  Can be used multiple times to include multiple filters.

=item B<-header> B<--no-header>

Enable/Disable printing of the csv header line. 

=item B<-help>

Print a brief help message and exits

=item B<-man>

Prints the full documentation

=back

=head1 DESCRIPTION

A script to demonstrate JIRA::Client perl module, accessing the JIRA SOAP api.  Given a list of saved filters, it retrieves the bug count for each filter and prints CSV to STDOUT.

=head1 FILES

Reads two configuration files jira.conf and .jira .   The files are generally in YAML, but can be in any format that Config::Auto can interpret.

By convention .jira contains just a key 'password' with value of the password of the jira user.  This file should be chmod 0600.

Entries in .jira override those in jira.conf.

Allowed configuration keys are:

=over

=item password

Jira password.  By default this is stored only in the .jira file.

=item username

Jira username.

=item filter

These are the names of the saved filters to be queried for bug counts.

=item base_url

This is the base_url of your jira server.  Generally like http://jira.example.com/jira
