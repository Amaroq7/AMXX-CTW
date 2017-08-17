/*
 * AMX Mod X plugin
 *
 * Cut the wire, v0.0.4-dev
 *
 * (c) Copyright 2014-2017 - Amaroq
 * This file is provided as is (no warranties).
 *
 */

/*
 * Description:
 * As CT allows to cut a wire that has been chosen by planter (TT). If CT choose right the C4 won't explode in other case C4 will explode.
 *
 * Requirement(s):
 * AMX Mod X 1.8.3
 * (optional) ReAPI module
 *
 * Setup:
 * Put .sma file into the amxmodx/scripting folder
 * Compile .sma file.
 * Put .amxx file into amxmodx/plugins folder
 * Type ctw.amxx into plugins.ini
 *
 * Credit(s):
 * Steven
 * VEN - CS Bomb Script Tutorial
 *
 * Changelog:
 * 0.0.3 - fixed some bugs
 * 0.0.2 - merged with amxx 1.8.3
 * 0.0.1 - initial release
 *
 */

//Enables ReAPI support
//#define REAPI_SUPPORT

#include <amxmodx>
#include <amxmisc>
#if defined REAPI_SUPPORT
	#include <reapi>
#else
	#include <engine>
	#include <cstrike>
	#include <hamsandwich>
#endif
#include <fakemeta>

#define INVALID_WIRE			-1

#define BARTIME_NONE 			0
#define BARTIME_PLANTING		3
#define BARTIME_DEFUSE_WITH_KIT		5
#define BARTIME_DEFUSE_WITHOUT_KIT	10

new g_hMenu;

new g_eC4;
new g_iWire;

#if !defined REAPI_SUPPORT
new g_iBarTimeMsg;
#endif

new Array:g_arrayWires;
new g_iWires;

new const g_szPrefix[] = { "[^3CTW^1]" };

//Player index for who reset menu
new g_ePlayerResetMenu;

public plugin_init()
{
	register_plugin("Cut the wire", "0.0.4-dev", "Amaroq");

	create_cvar("ctw_version", "0.0.4-dev", FCVAR_SERVER, "CTW version");

	#if !defined REAPI_SUPPORT
	g_iBarTimeMsg = get_user_msgid("BarTime");
	#endif

	register_event("BarTime", "OnBarTimeEvent", "bef", "1=0", "1=3", "1=5", "1=10");
	register_logevent("OnNewRoundStart", 2, "1=Round_Start");
	register_logevent("OnBombPlanted", 3, "2=Planted_The_Bomb");
	register_logevent("OnBombDefused", 3, "2=Defused_The_Bomb");

	#if defined REAPI_SUPPORT
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayerSpawnPost", 1);
	#else
	RegisterHamPlayer(Ham_Killed, "CBasePlayerKilledPost", 1);
	#endif

	g_arrayWires = ArrayCreate(32);

	register_dictionary("ctw.txt");

	AutoExecConfig(true, "ctw", "ctw");
}

public plugin_cfg()
{
	ReadWiresFromFile();
	MakeMenu();
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (g_ePlayerResetMenu == id)
		g_ePlayerResetMenu = 0;
}

public OnBarTimeEvent(id)
{
	new iTime = read_data(1);

	switch (iTime)
	{
		case BARTIME_NONE:
		{
			HideMenu(id);
			return;
		}
		case BARTIME_PLANTING:
		{
			g_iWire = -1;
			g_ePlayerResetMenu = id;
		}
		case BARTIME_DEFUSE_WITH_KIT, BARTIME_DEFUSE_WITHOUT_KIT:
		{
			g_ePlayerResetMenu = id;
		}
	}
	SetupTitle(id);
	menu_display(id, g_hMenu, 0, iTime);
}

public OnNewRoundStart()
{
	g_ePlayerResetMenu = g_eC4 = 0;
	g_iWire = INVALID_WIRE;
}

public CBasePlayerKilledPost(this, killer, gib)
{
	if (g_ePlayerResetMenu == this)
	{
		HideMenu(this);
	}
}

public MenuWiresHandler(id, menu, key)
{
	if (key == MENU_TIMEOUT || key == MENU_EXIT)
		return PLUGIN_HANDLED;

	#if defined REAPI_SUPPORT
	if (get_member(id, m_iTeam) == TEAM_TERRORIST)
	#else
	if (cs_get_user_team(id) == CS_TEAM_T)
	#endif
	{
		g_iWire = key;
		client_print_color(id, id, "%s %l", g_szPrefix, "CHOSE_WIRE", ArrayGetStringHandle(g_arrayWires, key));
		return PLUGIN_HANDLED;
	}

	//Sometimes g_eC4 is not valid ent, idk why this is happening
	#if defined REAPI_SUPPORT
	if (!is_entity(g_eC4))
	#else
	if (!is_valid_ent(g_eC4))
	#endif
		return PLUGIN_HANDLED;

	if (g_iWire == key)
	{
		client_print_color(id, id, "%s %l", g_szPrefix, "CORRECT_WIRE", ArrayGetStringHandle(g_arrayWires, key));
		set_ent_data_float(g_eC4, "CGrenade", "m_flDefuseCountDown", get_gametime());
	}
	else
	{
		client_print_color(id, id, "%s %l", g_szPrefix, "WRONG_WIRE", ArrayGetStringHandle(g_arrayWires, key), ArrayGetStringHandle(g_arrayWires, g_iWire));
		set_ent_data_float(g_eC4, "CGrenade", "m_flC4Blow", get_gametime());
	}

	#if defined REAPI_SUPPORT
	rg_send_bartime(id, 0);
	#else
	message_begin(MSG_ONE, g_iBarTimeMsg, _, id);
	write_short(0);
	message_end();
	#endif

	return PLUGIN_HANDLED;
}

public OnBombPlanted()
{
	//g_ePlayerResetMenu bartime event
	HideMenu(g_ePlayerResetMenu);

	#if defined REAPI_SUPPORT
	new iIndex = -1, szModel[32];
	while ((iIndex = rg_find_ent_by_class(iIndex, "grenade", true)))
	{
		get_entvar(iIndex, var_model, szModel, charsmax(szModel));
		if (!equal(szModel, "models/w_c4.mdl"))
		{
			g_eC4 = iIndex;
			break;
		}
	}
	#else
	g_eC4 = find_ent_by_model(-1, "grenade", "models/w_c4.mdl");
	#endif

	if (g_iWire == INVALID_WIRE)
		g_iWire = random(g_iWires);
}

public OnBombDefused()
{
	//g_ePlayerResetMenu bartime event
	HideMenu(g_ePlayerResetMenu);
}

public plugin_end()
{
	menu_destroy(g_hMenu);
	ArrayDestroy(g_arrayWires);
}

ReadWiresFromFile()
{
	new szFileDir[PLATFORM_MAX_PATH], szLine[32];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	add(szFileDir, charsmax(szFileDir), "/plugins/ctw/wires.ini");

	new hFile = fopen(szFileDir, "rt", false);

	if (!hFile)
	{
		set_fail_state("%l", "CANNOT_READ_FILE", szFileDir);
		return;
	}

	while (!feof(hFile))
	{
		fgets(hFile, szLine, charsmax(szLine));

		trim(szLine);

		if(!szLine[0] || szLine[0] == ';' || (szLine[0] == '/' && szLine[1] == '/'))
			continue;

		ArrayPushString(g_arrayWires, szLine);
		g_iWires++;
	}
	fclose(hFile);
}

MakeMenu()
{
	new szItem[32];
	g_hMenu = menu_create("Choose a wire", "MenuWiresHandler");
	for (new i = 0; i < g_iWires; i++)
	{
		ArrayGetString(g_arrayWires, i, szItem, charsmax(szItem));
		menu_additem(g_hMenu, szItem);
	}
}

HideMenu(id)
{
	if (!is_user_connected(id))
		return;

	static iMenu, iNewMenu;
	player_menu_info(id, iMenu, iNewMenu);

	if ((iMenu > 0 && iNewMenu < 0) || iNewMenu != g_hMenu)
		return;

	reset_menu(id);
}

SetupTitle(id)
{
	static szTitle[32];
	LookupLangKey(szTitle, charsmax(szTitle), "CHOOSE_WIRE", id);
	menu_setprop(g_hMenu, MPROP_TITLE, szTitle);
}
