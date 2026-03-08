#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

// ============================================================================
// Plugin Info
// ============================================================================

public Plugin myinfo =
{
    name        = "DoD:S ZM - Flame Rockets",
    author      = "donkey",
    description = "Rocket launchers ignite players on hit",
    version     = "1.0.0",
    url         = "https://basemod.net"
};

// ============================================================================
// Globals
// ============================================================================

ConVar g_CvarTime;
ConVar g_CvarMulti;
ConVar g_CvarAmmo;

float g_fBurnTime;
float g_fBurnMulti;
int   g_iAmmo;

// Weapons to check in player_hurt
static const char g_sRocketWeapons[][] =
{
    "bazooka",
    "pschreck",
    "rocket_bazooka",
    "rocket_pschreck"
};

// Weapon classnames to scan on spawn
static const char g_sRocketClasses[][] =
{
    "weapon_bazooka",
    "weapon_pschreck"
};

// ============================================================================
// Plugin Start
// ============================================================================

public void OnPluginStart()
{
    g_CvarTime = CreateConVar(
        "zm_flamerocket_time",
        "3.0",
        "Base burn duration in seconds applied on any rocket hit",
        _,
        true, 0.0,
        true, 60.0
    );

    g_CvarMulti = CreateConVar(
        "zm_flamerocket_multi",
        "0.1",
        "Extra burn seconds added per point of rocket damage (burn = time + damage * multi)",
        _,
        true, 0.0,
        true, 10.0
    );

    g_CvarAmmo = CreateConVar(
        "zm_flamerocket_ammo",
        "10",
        "Reserve rocket ammo given to players carrying a rocket launcher on spawn",
        _,
        true, 0.0,
        true, 99.0
    );

    g_CvarTime.AddChangeHook(OnCvarChanged);
    g_CvarMulti.AddChangeHook(OnCvarChanged);
    g_CvarAmmo.AddChangeHook(OnCvarChanged);

    // Load initial values
    g_fBurnTime  = g_CvarTime.FloatValue;
    g_fBurnMulti = g_CvarMulti.FloatValue;
    g_iAmmo      = g_CvarAmmo.IntValue;

    HookEvent("player_hurt",  Event_PlayerHurt);
    HookEvent("player_spawn", Event_PlayerSpawn);

    AutoExecConfig(true, "dod_zm_flamerockets", "zombiemod");
}

// ============================================================================
// CVar change handler
// ============================================================================

public void OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    g_fBurnTime  = g_CvarTime.FloatValue;
    g_fBurnMulti = g_CvarMulti.FloatValue;
    g_iAmmo      = g_CvarAmmo.IntValue;
}

// ============================================================================
// player_hurt — apply burn on rocket hit
// ============================================================================

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    // Identify the weapon that caused damage
    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));

    bool isRocket = false;
    for (int i = 0; i < sizeof(g_sRocketWeapons); i++)
    {
        if (strcmp(weapon, g_sRocketWeapons[i], false) == 0)
        {
            isRocket = true;
            break;
        }
    }

    if (!isRocket)
        return;

    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (!victim || !IsClientInGame(victim) || !IsPlayerAlive(victim))
        return;

    int damage = event.GetInt("damageamount");

    float burnDuration = g_fBurnTime + (float(damage) * g_fBurnMulti);

    if (burnDuration <= 0.0)
        return;

    IgniteEntity(victim, burnDuration);

}

// ============================================================================
// player_spawn — set rocket ammo
// ============================================================================

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!client || !IsClientInGame(client))
        return;

    // Short delay to allow weapon grants to complete
    CreateTimer(0.2, Timer_SetAmmo, GetClientUserId(client));
}

public Action Timer_SetAmmo(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);

    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    // Scan inventory for a rocket launcher
    for (int slot = 0; slot < 5; slot++)
    {
        int weapon = GetPlayerWeaponSlot(client, slot);

        if (weapon == -1)
            continue;

        char classname[64];
        GetEntityClassname(weapon, classname, sizeof(classname));

        for (int i = 0; i < sizeof(g_sRocketClasses); i++)
        {
            if (strcmp(classname, g_sRocketClasses[i], false) == 0)
            {
                // Get the ammo type index from the weapon entity
                int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");

                if (ammoType != -1)
                    SetEntProp(client, Prop_Send, "m_iAmmo", g_iAmmo, _, ammoType);

                return Plugin_Stop;
            }
        }
    }

    return Plugin_Stop;
}
