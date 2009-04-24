#include <sourcemod>
#include <sdktools>
#include <dbi>

#define PLUGIN_VERSION "1.0.0"

public Plugin:myinfo = 
{
	name = "Tournament Score Recorder",
	author = "withgod",
	description = "tournament mode score recorder",
	version = PLUGIN_VERSION,
	url = "http://fps.withgod.jp/"
}

new String:_err[255];
new Handle:cvar_TrecorderSeasonTag;
new String:TrecorderSeasonTag[512];
new Handle:db;

public OnPluginStart()
{
	CreateConVar("sm_trecorder_version", PLUGIN_VERSION, "sm tournamend recoder Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	HookEvent("tf_game_over", _game_end);
	HookEvent("teamplay_game_over", _game_end);

	//db connect
	db = SQL_DefConnect(_err, sizeof(_err));
	if (db == INVALID_HANDLE)
	{
		PrintToServer("[SM] can't connect db %s [code=00]", _err);
	}

	cvar_TrecorderSeasonTag = CreateConVar("sm_trecorder_season_tag", "default", "season tag for tournament recoder");
}

public OnPluginEnd()
{
	CloseHandle(db);
}

public _game_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:TeamName[2][128];
	new String:CurrentMap[128];

	new Handle:cvar_TeamName[2];
	new Handle:hInsertQuery = INVALID_HANDLE;

	new Score[2];

	// red
	cvar_TeamName[0] = FindConVar("mp_tournament_redteamname");
	GetConVarString(cvar_TeamName[0], TeamName[0], 128);
	Score[0] = GetTeamScore(2);
	// blue
	cvar_TeamName[1] = FindConVar("mp_tournament_blueteamname");
	GetConVarString(cvar_TeamName[1], TeamName[1], 128);
	Score[1] = GetTeamScore(3);

	GetCurrentMap(CurrentMap, sizeof(CurrentMap));

	if (strlen(TrecorderSeasonTag) == 0)
	{
		GetConVarString(cvar_TrecorderSeasonTag, TrecorderSeasonTag, 512);
	}

	PrintToServer("[SM]%s:%s - red[%s:%d]/blue[%s:%d]", TrecorderSeasonTag, CurrentMap, TeamName[0], Score[0], TeamName[1], Score[1]);

	if (hInsertQuery == INVALID_HANDLE) 
	{
		hInsertQuery = 
		SQL_PrepareQuery(db,
			"insert into results(result_date, team_1_score, team_2_score, team_1_name, team_2_name, season_tag, map_name) values (sysdate(), ?, ?, ?, ?, ?, ?)",
			_err, sizeof(_err));
		if (hInsertQuery == INVALID_HANDLE) 
		{
			PrintToServer("[SM] can't create prepare statent[code=01]");
			return;
		}
	}
	SQL_BindParamInt(hInsertQuery, 0, Score[0]);
	SQL_BindParamInt(hInsertQuery, 1, Score[1]);
	SQL_BindParamString(hInsertQuery, 2, TeamName[0], false);
	SQL_BindParamString(hInsertQuery, 3, TeamName[1], false);
	SQL_BindParamString(hInsertQuery, 4, TrecorderSeasonTag, false);
	SQL_BindParamString(hInsertQuery, 5, CurrentMap, false);

	if (!SQL_Execute(hInsertQuery))
	{
		PrintToServer("[SM] can't execute prepare statent[code=02]");
	}
}


