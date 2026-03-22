/**
 * Based on:
 * [ANY] Explosive Oildrum Spawner! by KTM
 * https://forums.alliedmods.net/showthread.php?t=194301
 */

#include <sourcemod>
#include <sdktools>
#include <dod_zm>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.4.1"
#define PLUGIN_NAME "DoD:S ZM - Human Skill - Oil Drum Spawner"

// ── Models ──────────────────────────────────────────────────
#define DRUM_MODEL      "models/props_c17/oildrum001_explosive.mdl"
#define BEAM_SPRITE     "materials/sprites/laser.vmt"
#define HALO_SPRITE     "materials/sprites/halo01.vmt"
#define DRUM_SPAWNFLAGS "8192"
#define DRUM_Z_OFFSET   15.0

// ── Plugin Info ─────────────────────────────────────────────
public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "KTM, Converted for ZM by ChatGPT & claude.ai guided by DNA.styx",
    description = "Human skill: Pistol right-click to deploy explosive oil drums",
    version = PLUGIN_VERSION,
    url = "https://github.com/DNA-styx/DoD_ZombieMod_Plugins"
};

// ── Globals ─────────────────────────────────────────────────
ZMSkillID g_SkillID = ZM_SKILL_INVALID;

ConVar gC_Cooldown;
ConVar gC_Health;
ConVar gC_Damage;
ConVar gC_Radius;

int   g_BeamSprite;
int   g_HaloSprite;

float  g_LastSpawn[MAXPLAYERS + 1];
int    g_LastButtons[MAXPLAYERS + 1];
Handle g_ReadyTimer[MAXPLAYERS + 1];   // Fires when cooldown expires
float  g_LastCooldownMsg[MAXPLAYERS + 1]; // Throttle cooldown chat messages

int redColor[4] = {200, 25, 25, 255};

// ── Plugin Start ────────────────────────────────────────────
public void OnPluginStart()
{
    gC_Cooldown = CreateConVar(
        "zm_drum_cooldown",
        "15.0",
        "Cooldown between drum spawns (seconds)",
        FCVAR_NOTIFY,
        true, 1.0);

    gC_Health = CreateConVar(
        "zm_drum_health",
        "20",
        "Drum health");

    gC_Damage = CreateConVar(
        "zm_drum_damage",
        "120",
        "Explosion damage");

    gC_Radius = CreateConVar(
        "zm_drum_radius",
        "256",
        "Explosion radius");

    AutoExecConfig(true, "dod_zm_oildrum", "zombiemod");
}

// ── Library Handling ────────────────────────────────────────

// Register if ZM already loaded
public void OnAllPluginsLoaded()
{
    if (g_SkillID == ZM_SKILL_INVALID && ZM_IsLoaded())
    {
        g_SkillID = ZM_RegisterHumanSkill(
            "Spawn Explosive Drums",
            "Pistol right-click"
        );
    }
}

// Register if ZM loads after us
public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY) && g_SkillID == ZM_SKILL_INVALID)
    {
        g_SkillID = ZM_RegisterHumanSkill(
            "Spawn Explosive Drums",
            "Pistol right-click"
        );
    }
}

// Handle ZM unload
public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY))
        g_SkillID = ZM_SKILL_INVALID;
}

// ── Map Start ───────────────────────────────────────────────
public void OnMapStart()
{
    PrecacheModel(DRUM_MODEL, true);
    g_BeamSprite = PrecacheModel(BEAM_SPRITE);
    g_HaloSprite = PrecacheModel(HALO_SPRITE);
}

// ── Client State Management ─────────────────────────────────
void ResetClientState(int client)
{
    g_LastSpawn[client]      = 0.0;
    g_LastButtons[client]    = 0;
    g_LastCooldownMsg[client] = 0.0;
    KillReadyTimer(client);
}

void KillReadyTimer(int client)
{
    if (g_ReadyTimer[client] != null)
    {
        KillTimer(g_ReadyTimer[client]);
        g_ReadyTimer[client] = null;
    }
}

public void OnClientConnected(int client)
{
    ResetClientState(client);
}

public void OnClientDisconnect(int client)
{
    ResetClientState(client);
}

public void ZM_OnClientSpawn(int client, ZMTeam team)
{
    ResetClientState(client);
}

public void ZM_OnClientDeath(int client)
{
    g_LastButtons[client] = 0;
    KillReadyTimer(client);
}

// ── Skill Assignment ────────────────────────────────────────
public void ZM_OnSkillAssigned(int client, ZMSkillID skillID)
{
    if (skillID == g_SkillID)
    {
        PrintCenterText(client, "Pistol right-click spawns oil drum!");
    }
}

// ── Ability Activation ──────────────────────────────────────
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
    if (g_SkillID == ZM_SKILL_INVALID)
        return Plugin_Continue;

    if (!ZM_IsModActive())
        return Plugin_Continue;

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Continue;

    if (ZM_GetClientSkill(client) != g_SkillID)
        return Plugin_Continue;

    if (!ZM_IsClientHuman(client))
        return Plugin_Continue;

    // Must have pistol equipped
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon <= 0)
        return Plugin_Continue;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (!StrEqual(classname, "weapon_colt") &&
        !StrEqual(classname, "weapon_p38"))
        return Plugin_Continue;

    // Detect right-click press (rising edge only)
    if ((buttons & IN_ATTACK2) && !(g_LastButtons[client] & IN_ATTACK2))
        TrySpawnDrum(client);

    g_LastButtons[client] = buttons;
    return Plugin_Continue;
}

// ── Drum Spawn Logic ────────────────────────────────────────
void TrySpawnDrum(int client)
{
    float now      = GetGameTime();
    float cooldown = gC_Cooldown.FloatValue;

    if (now < g_LastSpawn[client] + cooldown)
    {
        if (now - g_LastCooldownMsg[client] >= 1.0)
        {
            int remaining = RoundToCeil((g_LastSpawn[client] + cooldown) - now);
            ZM_Chat(client, "Drum ready in %d seconds.", remaining);
            g_LastCooldownMsg[client] = now;
        }
        return;
    }

    float absAngles[3], spawnAngles[3], spawnPos[3];

    GetClientAbsAngles(client, absAngles);
    GetCollisionPoint(client, spawnPos);

    spawnAngles[0] = 0.0;
    spawnAngles[1] = absAngles[1];
    spawnAngles[2] = 0.0;

    spawnPos[2] += DRUM_Z_OFFSET;

    // Consume cooldown before entity work — prevents spam on failure
    g_LastSpawn[client] = now;
    KillReadyTimer(client);

    int drum = CreateEntityByName("prop_physics_override");
    if (drum == -1)
    {
        ZM_Chat(client, "Failed to place drum.");
        ScheduleReadyNotification(client, cooldown);
        return;
    }

    TeleportEntity(drum, spawnPos, spawnAngles, NULL_VECTOR);

    char buffer[16];

    DispatchKeyValue(drum, "model", DRUM_MODEL);

    IntToString(gC_Health.IntValue, buffer, sizeof(buffer));
    DispatchKeyValue(drum, "health", buffer);

    IntToString(gC_Damage.IntValue, buffer, sizeof(buffer));
    DispatchKeyValue(drum, "ExplodeDamage", buffer);

    IntToString(gC_Radius.IntValue, buffer, sizeof(buffer));
    DispatchKeyValue(drum, "ExplodeRadius", buffer);

    DispatchKeyValue(drum, "spawnflags", DRUM_SPAWNFLAGS);

    DispatchSpawn(drum);
    ActivateEntity(drum);

    ScheduleReadyNotification(client, cooldown);

    float radius = float(gC_Radius.IntValue);
    TE_SetupBeamRingPoint(spawnPos, 10.0, radius,
        g_BeamSprite, g_HaloSprite,
        0, 10, 0.6, 10.0, 0.5,
        redColor, 20, 0);
    TE_SendToAll();
}

// Schedule a single "drum ready" message after cooldown elapses
void ScheduleReadyNotification(int client, float delay)
{
    KillReadyTimer(client);
    int userId = GetClientUserId(client);
    g_ReadyTimer[client] = CreateTimer(delay, Timer_DrumReady, userId);
}

public Action Timer_DrumReady(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);

    if (client > 0 && IsClientInGame(client))
    {
        // Only notify if they still have this skill and are alive
        if (IsPlayerAlive(client)
            && ZM_IsClientHuman(client)
            && ZM_GetClientSkill(client) == g_SkillID)
        {
            ZM_Chat(client, "New drum is ready!");
        }
    }

    // Clear the handle on whichever slot owns this timer
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_ReadyTimer[i] == timer)
        {
            g_ReadyTimer[i] = null;
            break;
        }
    }

    return Plugin_Stop;
}

// ── Trace Helper ────────────────────────────────────────────
stock void GetCollisionPoint(int client, float pos[3])
{
    float vOrigin[3], vAngles[3];

    GetClientEyePosition(client, vOrigin);
    GetClientEyeAngles(client, vAngles);

    Handle trace = TR_TraceRayFilterEx(
        vOrigin, vAngles,
        MASK_SOLID, RayType_Infinite,
        TraceEntityFilterPlayer);

    if (TR_DidHit(trace))
        TR_GetEndPosition(pos, trace);
    else
        GetClientAbsOrigin(client, pos);

    delete trace;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients;
}
