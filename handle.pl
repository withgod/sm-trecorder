#!/usr/bin/perl --

use CGI::Carp(fatalsToBrowser);
use strict;
use warnings;
use DBI;
use CGI qw(param);
use Data::Dumper;
use POSIX;
use JSON;
use XML::RSS;

my $param_team_name = param('team_name');
my $param_season_tag = param('season_tag');
my $param_map_name = param('map_name');
my $param_mode = param('mode') || "json";
my $param_type = param('type') || "summary";
my $param_hasKey = param('hasKey') || "true";
my $param_callback = param('callback');

my $dbh = DBI->connect('DBI:mysql:sourcemod;host=localhost;port=3306', 'sourcemod', 'sourcemodpassword') or die "can't connect db";

#print "Content-type: text/plain\r\n\r\n";
#print Dumper $param_hasKey;
sub gen_result {
	my $sth = shift;
	my $_result = [];
	if ($param_mode eq 'rss' || $param_hasKey eq 'true') {
		my $sort_key = 'id';
		if ($param_type eq "maplist") {
			$sort_key = "map_name";
		}
		my $retref = $sth->fetchall_hashref($sort_key);
		for (sort { $a <=> $b } keys %{$retref}) {
			push @{$_result}, $retref->{$_};
		}
	} else {
		$_result = $sth->fetchall_arrayref;
	}
	return $_result;
}

my $result;
if ($param_type eq 'maplist') {
	my $sth = $dbh->prepare("select distinct map_name from results order by map_name");
	my $ret = $sth->execute;
	$result = gen_result($sth);
} elsif ($param_type eq 'teamnames') {
	my $sth = $dbh->prepare("select distinct map_name from results order by map_name");
	my $ret = $sth->execute;
	$result = gen_result($sth);
} else {
	my $sql = "select * from results where enable_flag = true and ".
			  "(team_1_name like ? or team_2_name like ?) and map_name " .
			  "like ? and season_tag like ? order by id";

	my $sth = $dbh->prepare($sql);
	$sth->bind_param(1, $param_team_name ? $param_team_name : '%');
	$sth->bind_param(2, $param_team_name ? $param_team_name : '%');
	$sth->bind_param(3, $param_map_name ? $param_map_name : '%');
	$sth->bind_param(4, $param_season_tag ? "%$param_season_tag%" : '%');

	my $ret = $sth->execute;

	$result = gen_result($sth);
}

if ($param_mode eq 'rss') {
	print "Content-type: application/xml; charset=UTF-8\r\n\r\n";
	my $rss = new XML::RSS(version => '1.0');
	$rss->channel(
		title => 'tournament result recorder',
		link  => 'http://withgod.dyndns.org/trecorder/',
		description => 'tf2 tournament result',
		dc => {
			date => POSIX::strftime('%Y-%m-%dT%H:%M:%S+09:00', localtime),
			publisher => 'withgod',
			language => 'ja',
		},
		syn => {
			updatePeriod     => "hourly",
			updateFrequency  => "1",
		}
	);
	for my $item (reverse @{$result}) {
		my $date = "$1T$2+09:00" if ($item->{'result_date'} =~ /^([\d\-]+) ([\d:]+)/);
		$rss->add_item(
			title => $item->{'team_1_name'} .' - '. $item->{'team_2_name'},
			link  => "http://withgod.dyndns.org/trecorder/",
			description => $item->{'team_1_score'} .' - '. $item->{'team_2_score'} . "\n" . $item->{'map_name'} . "\n" . $item->{'season_tag'},
			dc => {
				date => $date
			}
		);
	}
	print $rss->as_string;
} else {
	print "Content-type: text/javascript+json; charset=UTF-8\r\n\r\n";

	my $response = to_json($result);
	if ($param_callback && $param_callback =~ /^[\w\d\-\_]+$/) {
		print "$param_callback($response);";
	} else {
		print $response;
	}
}

