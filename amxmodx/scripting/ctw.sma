/*
 * AMX Mod X plugin
 *
 * Cut the wire, v0.0.4-dev
 *
 * (c) Copyright 2014-2015 - Ni3znajomy
 * This file is provided as is (no warranties).
 *
 */

/*
 * Description:
 * As CT allows to cut a wire that has been chosen by planter (TT). If CT chose right the C4 won't explode in other case C4 will explode.
 *
 * Requirement(s):
 * AMX Mod X 1.8.3
 *
 * Setup:
 * Put .sma file into the amxmodx/scripting folder
 * Compile .sma file.
 * Put .amxx file into amxmodx/plugins folder
 * Type ctw.amxx into plugins.ini
 *
 * Credit(s):
 * Steven
 *
 * Changelog:
 * 0.0.3 - fixed some bugs
 * 0.0.2 - merged with amxx 1.8.3
 * 0.0.1 - initial release
 *
 */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <hamsandwich>
#include <fakemeta>

#define MAX_WIRES 10

new g_hMenu;

new g_iC4;
new g_iWire;
new g_iBarTime;

new Array:g_arrayWires;
new g_iWires;

new g_szPrefix[] = { "^1[^3CTW^1] " };

public plugin_init()
{
	register_plugin("Cut the wire", "0.0.4-dev", "Ni3znajomy");
	
	create_cvar("ctw_version", "0.0.4-dev", FCVAR_SERVER, "CTW version");
	
	g_iBarTime = get_user_msgid("BarTime");
	register_logevent("New_Round", 2, "1=Round_Start");
	RegisterHamPlayer(Ham_Killed, "PlayerKilledPost", 1);
	
	register_event("BarTime", "BarTime_event", "be", "1=0");

	g_arrayWires = ArrayCreate(32, MAX_WIRES);

	if(g_arrayWires == Invalid_Array)
	{
		set_fail_state("Cannot create CellArray!");
		return;
	}

	register_dictionary("ctw.txt");
	AutoExecConfig(true, "ctw", "ctw");
}

public OnConfigsExecuted()
{
	ReadWiresFromFile();
	MakeMenu();
}

public ReadWiresFromFile()
{
	new szFileDir[PLATFORM_MAX_PATH], szLine[32];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	format(szFileDir, charsmax(szFileDir), "%s/plugins/ctw/wires.ini", szFileDir);

	new hFile = fopen(szFileDir, "rt", false);

	if(!hFile)
	{
		set_fail_state("%l", "CANNOT_READ_FILE", szFileDir);
		return;
	}

	while(!feof(hFile))
	{
		fgets(hFile, szLine, charsmax(szLine));

		if(!szLine[0] || szLine[0] == ';' || (szLine[0] == '/' && szLine[1] == '/'))
			continue;

		if(g_iWires >= MAX_WIRES)
		{
			log_amx("%l", "MORE_WIRES");
			break;
		}

		ArrayPushString(g_arrayWires, szLine);
		g_iWires++;
	}
	fclose(hFile);
}
		

public BarTime_event(id)
{
	HideMenu(id);
}

public New_Round()
{
	g_iC4 = 0;
	g_iWire = -1;
}

public PlayerKilledPost(victim, killer, gib)
{
	if(!g_iC4)
		return;
	
	HideMenu(victim);
}

MakeMenu()
{
	new szItem[32];
	g_hMenu = menu_create("Choose a wire", "chose_wire");
	for(new i=0; i<g_iWires; i++)
	{
		ArrayGetString(g_arrayWires, i, szItem, charsmax(szItem));
		menu_additem(g_hMenu, szItem);
	}
}

public bomb_planting(planter)
{
	g_iWire = -1;
	SetupTitle(planter);
	menu_display(planter, g_hMenu, 0, 3);
}

public bomb_planted(planter)
{
	HideMenu(planter);

	g_iC4 = find_ent_by_model(-1, "grenade", "models/w_c4.mdl");
	set_task(0.5, "CheckWire");
}

public CheckWire()
{
	if(g_iWire == -1)
		g_iWire = random(g_iWires);
}

public bomb_defusing(defuser)
{
	SetupTitle(defuser);
	menu_display(defuser, g_hMenu, 0, (cs_get_user_defuse(defuser)) ? 5 : 10);
}

public bomb_defused(defuser)
{
	HideMenu(defuser);
}

public chose_wire(id, menu, key)
{
	if(key == MENU_TIMEOUT || key < 0)
		return PLUGIN_HANDLED;

	if(!is_user_alive(id))
		return PLUGIN_HANDLED;
		
	if(cs_get_user_team(id) == CS_TEAM_T)
	{
		g_iWire = key;
		client_print_color(id, id, "%l", "CHOSE_WIRE", g_szPrefix, ArrayGetStringHandle(g_arrayWires, key));
		return PLUGIN_HANDLED;
	}
	if(g_iWire == key)
	{
		client_print_color(id, id, "%l", "CORRECT_WIRE", g_szPrefix, ArrayGetStringHandle(g_arrayWires, key));
		set_ent_data_float(g_iC4, "CGrenade", "m_flDefuseCountDown", get_gametime());
	}
	else
	{
		client_print_color(id, id, "%l", "WRONG_WIRE", g_szPrefix, ArrayGetStringHandle(g_arrayWires, key), ArrayGetStringHandle(g_arrayWires, g_iWire));
		set_ent_data_float(g_iC4, "CGrenade", "m_flC4Blow", get_gametime());
	}

	message_begin(MSG_ONE, g_iBarTime, _, id);
	write_short(0);
	message_end();

	return PLUGIN_HANDLED;
}

HideMenu(id)
{
	if(!is_user_connected(id))
		return;

	static iMenu, iNewMenu;
	player_menu_info(id, iMenu, iNewMenu);

	if(iNewMenu != g_hMenu)
		return;

	reset_menu(id);
}

public plugin_end()
{
	menu_destroy(g_hMenu);
	ArrayDestroy(g_arrayWires);
}

SetupTitle(id)
{
	static szTitle[32];
	LookupLangKey(szTitle, charsmax(szTitle), "CHOOSE_WIRE", id);
	menu_setprop(g_hMenu, MPROP_TITLE, szTitle);
}
