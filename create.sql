create table results(
	id int auto_increment,
	result_date DATETIME NOT NULL,
	team_1_score int NOT NULL,
	team_2_score int NOT NULL,
	team_1_name varchar(256) NOT NULL,
	team_2_name varchar(256) NOT NULL,
	season_tag varchar(512) NOT NULL,
	map_name varchar(256) NOT NULL,
	enable_flag boolean default true,
	primary key(ID)
);
