#!/usr/bin/perl --

use CGI::Carp(fatalsToBrowser);
use strict;
use warnings;
use DBI;
use CGI qw(param);
use Data::Dumper;
use POSIX;
use JSON;
use XML::Simple;
use XML::RSS;

my $DEBUG = param('_debug');
print "Content-type: text/plain\r\n\r\n" if ($DEBUG);

my $param_team_name          = param_split('team_name');
#my $param_team_name_exclude  = param_split('team_name_ex');
my $param_season_tag         = param_split('season_tag');
#my $param_season_tag_exclude = param_split('season_tag_ex');
my $param_map_name           = param_split('map_name');
#my $param_map_name_exclude   = param_split('map_name_ex');

my $param_mode       = param('mode') || "json"; # json, rss
my $param_hasKey     = param('hasKey') || "true";
my $param_nl2br      = param('nl2br') || "false"; #rss only
my $param_limit      = param('limit') || 1000;
my $param_offset     = param('offset') || 0;
my $param_desc       = param('desc') || "false";
my $param_callback   = param('callback');

my $param_type = param('type') || "summary"; # not work


my $dbh = DBI->connect('DBI:mysql:sourcemod;host=localhost;port=3306', 'sourcemod', 'sourcemodpassword') or die "can't connect db";
#$dbh->{TraceLevel} = "3|SQL";

sub param_split {
	my $val = param($_[0]) ? param($_[0]) : "";
	my @tmp = split /,/, $val;
	return \@tmp;
}

sub gen_result {
	my $sth = shift;
	my $_result = [];
	if ($param_mode eq 'rss' || $param_hasKey eq 'true') {
		my $sort_key = 'id';
		if ($param_type eq "maplist") {
			$sort_key = "map_name";
		} elsif ($param_type eq 'teamnames') {
			$sort_key = "team_names";
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

sub sql_and {
}

sub sql_build {
	my $sql = "select * from results where enable_flag = true ";
	print Dumper $sql if $DEBUG;
	if ($param_team_name) {
		my $tmp;
		$tmp .= sql_or('team_1_name', 'like', $param_team_name);
		$tmp .= sql_or('team_2_name', 'like', $param_team_name);
		$tmp =~ s#\) and \(# or #;
		$sql .= $tmp;
	}
#	if ($param_team_name_exclude) {
#		my $tmp;
#		$tmp .= sql_or('team_1_name', 'not like', $param_team_name_exclude);
#		$tmp .= sql_or('team_2_name', 'not like', $param_team_name_exclude);
#		$tmp =~ s#\) and \(# or #;
#		$sql .= $tmp;
#	}
	print Dumper $sql if $DEBUG;
	$sql .= sql_or('map_name', 'like', $param_map_name);
#	$sql .= sql_or('map_name', 'not like', $param_map_name_exclude);
	$sql .= sql_or('season_tag', 'like', $param_season_tag);
#	$sql .= sql_or('season_tag', 'not like', $param_season_tag_exclude);
	$sql .= " order by id asc limit ? offset ?";
	$sql =~ s/order by id asc /order by id desc / if ($param_desc eq 'true');
	print Dumper $sql if $DEBUG;

	return $sql;
}

sub sql_or {
	my ($id, $operant, $params) = @_;
	my $ret = "";
	if ($#{$params} >= 0) {
		$ret .= ' and (';

		for my $val (@{$params}) {
			$ret .= sprintf "%s %s ? or ", $id, $operant;
		}
		$ret =~ s/ or $//;

		$ret .= ')';
	}

	return $ret;
}
sub sql_bind {
	my @binds;
	@binds = (@binds, @{$param_team_name});
	@binds = (@binds, @{$param_team_name});
	#@binds = (@binds, @{$param_team_name_exclude});
	#@binds = (@binds, @{$param_team_name_exclude});
	@binds = (@binds, @{$param_map_name});
	#@binds = (@binds, @{$param_map_name_exclude});
	@binds = (@binds, @{$param_season_tag});
	#@binds = (@binds, @{$param_season_tag_exclude});
	@binds = sql_query_fix(@binds);
	@binds = (@binds, $param_limit, $param_offset);
	print Dumper @binds if $DEBUG;

	return \@binds;
}
sub sql_query_fix {
	my @ret;
	for (@_) {
		push @ret, "%$_%";
	}
	return @ret;
}

sub nl2br {
	my $tmp = shift;
	$tmp =~ s/[\r\n]+/<br>/g;
	return $tmp;
}

my $result;
if ($param_type eq 'maplist') {
	my $sth = $dbh->prepare("select distinct map_name from results order by map_name");
	my $ret = $sth->execute;
	$result = gen_result($sth);
} elsif ($param_type eq 'teamnames') {
	my $sth = $dbh->prepare("select team_1_name as team_names from (select distinct team_1_name from results union select distinct team_2_name as team_1_name from results) fuga");
	my $ret = $sth->execute;
	$result = gen_result($sth);
} else {
	my $sql = sql_build();
	my $sth = $dbh->prepare($sql);
	my $binds = sql_bind();
	print Dumper $binds if $DEBUG;

	my $ret = $sth->execute(@{$binds});
	print Dumper $ret if $DEBUG;

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
		my $description = $item->{'team_1_score'} .' - '. $item->{'team_2_score'} . "\n" . $item->{'map_name'} . "\n" . $item->{'season_tag'};
		if ($param_nl2br eq 'true') {
			$description = nl2br($description);
		}
		
		$rss->add_item(
			title => $item->{'team_1_name'} . '(' . $item->{'team_1_score'} .') - '. $item->{'team_2_name'}  . '(' . $item->{'team_2_score'} .')',
			link  => "http://withgod.dyndns.org/trecorder/",
			description => $description,
			dc => {
				date => $date
			}
		);
	}
	print $rss->as_string;
} else {
	if ($param_mode eq 'json') {
		print "Content-type: text/javascript+json; charset=UTF-8\r\n\r\n";
		my $response = to_json($result);
		if ($param_callback && $param_callback =~ /^[\w\d\-\_]+$/) {
			print "$param_callback($response);";
		} else {
			print $response;
		}
	} elsif ($param_mode eq 'xml') {
		print "Content-type: text/xml; charset=UTF-8\r\n\r\n";
		print XMLout($result,  RootName => 'recentData');
	}
}

