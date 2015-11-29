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

new g_hMenu;

new g_iC4;
new g_iWire;
new g_iBarTime;

new g_szWire[4][] = { "Czerwony", "Zielony", "Zolty", "Niebieski" };

new g_szPrefix[] = { "^1[^3CTW^1] " };

public plugin_init()
{
	register_plugin("Cut the wire", "0.0.4-dev", "Ni3znajomy")
	
	create_cvar("ctw_version", "0.0.4-dev", FCVAR_SERVER, "CTW version");
	
	g_iBarTime = get_user_msgid("BarTime");
	register_logevent("New_Round", 2, "1=Round_Start");
	RegisterHamPlayer(Ham_Killed, "PlayerKilledPost", 1);
	
	register_event("BarTime", "BarTime_event", "be", "1=0");
}

public plugin_cfg()
{
	MakeMenu();
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
	g_hMenu = menu_create("Wybierz kabel", "chose_wire");
	menu_additem(g_hMenu, "Czerwony");
	menu_additem(g_hMenu, "Zielony");
	menu_additem(g_hMenu, "Zolty");
	menu_additem(g_hMenu, "Niebieski");
}

public bomb_planting(planter)
{
	g_iWire = -1;
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
		g_iWire = random(4);
}

public bomb_defusing(defuser)
{
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
		client_print_color(id, id, "%sWybrales ^4%s^1.", g_szPrefix, g_szWire[key]);
		return PLUGIN_HANDLED;
	}
	if(g_iWire == key)
	{
		client_print_color(id, id, "%sWybrales poprawny kabel (^4%s^1).", g_szPrefix, g_szWire[key]);
		set_ent_data_float(g_iC4, "CGrenade", "m_flDefuseCountDown", get_gametime());
	}
	else
	{
		client_print_color(id, id, "%sWybrales ^4%s^1. Poprawnym kablem byl ^4%s^1.", g_szPrefix, g_szWire[key], g_szWire[g_iWire]);
		set_ent_data_float(g_iC4, "CGrenade", "m_flC4Blow", get_gametime());
	}

	message_begin(MSG_ONE, g_iBarTime, _, id)
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
	menu_destroy(g_hMenu);
