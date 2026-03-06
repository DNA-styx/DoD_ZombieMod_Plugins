/**
 * =============================================================================
 * DoD:S Zombie Mod - Example Skill Plugin Template
 * 
 * This is a comprehensive example showing how to create custom human skills
 * for the DoD:S Zombie Mod using the modular skill system.
 * 
 * Copy this file, rename it to dod_zm_yourskill.sp, and modify it to create
 * your own custom skill!
 * 
 * Version: 1.0.0
 * =============================================================================
 */

#include <sourcemod>
#include <sdktools>
#include <dod_zm>  // REQUIRED: Include the ZM API

#pragma semicolon 1
#pragma newdecls required

// ============================================================================
// PLUGIN INFO
// ============================================================================

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_NAME "DoD:S ZM - Example Skill Template"
#define PLUGIN_AUTHOR "Your Name Here"
#define PLUGIN_DESCRIPTION "Template for creating custom ZM human skills"

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = "https://github.com/DNA-styx/DoD_ZombieMod"
};

// ============================================================================
// GLOBALS
// ============================================================================

// Store our skill ID (returned when we register)
ZMSkillID g_SkillID = ZM_SKILL_INVALID;

// Example: Store per-client data
bool g_IsAbilityActive[MAXPLAYERS+1];
float g_AbilityEndTime[MAXPLAYERS+1];

// Example: Store timers
Handle g_ClientTimer[MAXPLAYERS+1];

// ============================================================================
// PLUGIN LIFECYCLE
// ============================================================================

public void OnPluginStart()
{
    // Hook any events you need
    HookEvent("player_hurt", Event_PlayerHurt);
    
    // Create any ConVars your skill needs
    CreateConVar("zm_example_duration", "10.0", "Duration of example ability in seconds");
    
    PrintToServer("[ZM Example Skill] Plugin loaded");
}

/**
 * REQUIRED: Register your skill when all plugins are loaded
 * This is where you tell the main ZM plugin about your skill
 */
public void OnAllPluginsLoaded()
{
    if (ZM_IsLoaded())
    {
        // Register your skill with a name and description
        // The name appears in the menu, description helps players understand it
        g_SkillID = ZM_RegisterHumanSkill(
            "Example Skill",                    // Skill name (max 64 chars)
            "Does something cool (example)"     // Description (max 128 chars)
        );
        
        if (g_SkillID != ZM_SKILL_INVALID)
        {
            PrintToServer("[ZM Example Skill] Registered as skill ID %d", g_SkillID);
        }
        else
        {
            SetFailState("[ZM Example Skill] Failed to register skill!");
        }
    }
}

/**
 * REQUIRED: Handle main plugin loading after this plugin
 * If the main ZM plugin loads or reloads after your plugin, register again
 */
public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY))
    {
        g_SkillID = ZM_RegisterHumanSkill("Example Skill", "Does something cool (example)");
        
        if (g_SkillID != ZM_SKILL_INVALID)
        {
            PrintToServer("[ZM Example Skill] Re-registered as skill ID %d", g_SkillID);
        }
    }
}

/**
 * REQUIRED: Handle main plugin unloading
 * Clean up if the main ZM plugin unloads
 */
public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY))
    {
        PrintToServer("[ZM Example Skill] Main plugin unloaded, cleaning up");
        
        // Clean up all clients
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                CleanupClient(i);
            }
        }
        
        g_SkillID = ZM_SKILL_INVALID;
    }
}

// ============================================================================
// CLIENT LIFECYCLE
// ============================================================================

public void OnClientConnected(int client)
{
    // Initialize client data when they connect
    g_IsAbilityActive[client] = false;
    g_AbilityEndTime[client] = 0.0;
    g_ClientTimer[client] = null;
}

public void OnClientDisconnect(int client)
{
    // Clean up client data when they disconnect
    CleanupClient(client);
}

void CleanupClient(int client)
{
    g_IsAbilityActive[client] = false;
    g_AbilityEndTime[client] = 0.0;
    
    if (g_ClientTimer[client] != null)
    {
        KillTimer(g_ClientTimer[client]);
        g_ClientTimer[client] = null;
    }
}

// ============================================================================
// ZM API FORWARDS - Receive notifications from the main plugin
// ============================================================================

/**
 * Called when a player selects a skill (including yours!)
 * 
 * @param client    Client who selected a skill
 * @param skillID   The skill ID they selected
 */
public void ZM_OnSkillAssigned(int client, ZMSkillID skillID)
{
    // Check if they selected YOUR skill
    if (skillID == g_SkillID)
    {
        PrintToChat(client, "[ZM] You selected Example Skill!");
        // Initialize any skill-specific data here
    }
}

/**
 * Called when a round starts
 * Use this to reset round-based state
 */
public void ZM_OnRoundStart()
{
    PrintToServer("[ZM Example Skill] Round started, resetting state");
    
    // Reset all clients
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            CleanupClient(i);
        }
    }
}

/**
 * Called when a round ends
 */
public void ZM_OnRoundEnd()
{
    // Clean up round state if needed
}

/**
 * Called when a client dies
 * 
 * @param client    Client who died
 */
public void ZM_OnClientDeath(int client)
{
    // Clean up client-specific state on death
    CleanupClient(client);
}

/**
 * Called when a client spawns
 * 
 * @param client    Client who spawned
 * @param team      Team they spawned on (ZM_TEAM_ALLIES or ZM_TEAM_AXIS)
 */
public void ZM_OnClientSpawn(int client, ZMTeam team)
{
    // Reset client state on spawn
    CleanupClient(client);
}

// ============================================================================
// EXAMPLE 1: PASSIVE ABILITY (Always Active)
// ============================================================================

/**
 * Example: Give extra health when skill is active
 * This runs passively without player input
 */
public void ZM_OnSkillAssigned_PassiveExample(int client, ZMSkillID skillID)
{
    if (skillID == g_SkillID && ZM_IsClientHuman(client))
    {
        // Give bonus health
        int health = GetClientHealth(client);
        SetEntityHealth(client, health + 25);
        
        PrintToChat(client, "[ZM] Passive bonus: +25 HP!");
    }
}

// ============================================================================
// EXAMPLE 2: BUTTON-ACTIVATED ABILITY (Active)
// ============================================================================

/**
 * Example: Detect button press to activate ability
 * This uses OnPlayerRunCmd which runs every frame
 */
int g_LastButtons[MAXPLAYERS+1];  // Track button state

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
    // IMPORTANT: Always check if your skill is active!
    if (g_SkillID == ZM_SKILL_INVALID)
        return Plugin_Continue;
    
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Continue;
    
    // Check if player has YOUR skill
    if (ZM_GetClientSkill(client) != g_SkillID)
        return Plugin_Continue;
    
    // Check if player is human
    if (!ZM_IsClientHuman(client))
        return Plugin_Continue;
    
    // Detect RIGHT CLICK press (not hold!)
    // This prevents spam - only triggers once per button press
    if ((buttons & IN_ATTACK2) && !(g_LastButtons[client] & IN_ATTACK2))
    {
        // Button was just pressed!
        ActivateAbility(client);
    }
    
    // Store button state for next frame
    g_LastButtons[client] = buttons;
    
    return Plugin_Continue;
}

void ActivateAbility(int client)
{
    // Check if ability is already active
    if (g_IsAbilityActive[client])
    {
        PrintToChat(client, "[ZM] Ability already active!");
        return;
    }
    
    // Activate the ability
    g_IsAbilityActive[client] = true;
    g_AbilityEndTime[client] = GetGameTime() + 10.0;  // 10 second duration
    
    // Visual/audio feedback
    PrintToChat(client, "[ZM] Example ability activated!");
    EmitSoundToClient(client, "buttons/button14.wav");
    
    // Start a timer to deactivate
    g_ClientTimer[client] = CreateTimer(10.0, Timer_DeactivateAbility, GetClientUserId(client));
}

public Action Timer_DeactivateAbility(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    
    if (client && IsClientInGame(client))
    {
        g_IsAbilityActive[client] = false;
        g_ClientTimer[client] = null;
        
        PrintToChat(client, "[ZM] Example ability ended!");
    }
    
    return Plugin_Stop;
}

// ============================================================================
// EXAMPLE 3: EVENT-BASED ABILITY
// ============================================================================

/**
 * Example: React to game events
 * This modifies behavior when certain events occur
 */
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    // Example: Reduce damage taken if victim has this skill
    if (victim && ZM_GetClientSkill(victim) == g_SkillID)
    {
        // Could modify damage here or give resistance
        // (This is just an example, actual damage modification requires SDKHooks)
    }
    
    // Example: Bonus damage if attacker has this skill
    if (attacker && ZM_GetClientSkill(attacker) == g_SkillID)
    {
        // Could amplify damage or add special effects
    }
}

// ============================================================================
// EXAMPLE 4: TIMER-BASED ABILITY
// ============================================================================

/**
 * Example: Periodic effect while skill is active
 * This runs a repeating timer
 */
public void StartPeriodicEffect(int client)
{
    // Start a repeating timer
    g_ClientTimer[client] = CreateTimer(1.0, Timer_PeriodicEffect, GetClientUserId(client), 
        TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PeriodicEffect(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    
    // Stop if client invalid or doesn't have skill
    if (!client || !IsClientInGame(client) || ZM_GetClientSkill(client) != g_SkillID)
    {
        return Plugin_Stop;
    }
    
    // Do something every second
    PrintHintText(client, "Periodic effect active!");
    
    return Plugin_Continue;
}

// ============================================================================
// EXAMPLE 5: WEAPON-SPECIFIC ABILITY
// ============================================================================

/**
 * Example: Only work when specific weapon is equipped
 */
bool HasSpecificWeapon(int client, const char[] weaponName)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    if (!IsValidEntity(weapon))
        return false;
    
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));
    
    return StrEqual(classname, weaponName, false);
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Check if skill system is ready
 */
bool IsSkillSystemReady()
{
    return ZM_IsLoaded() && g_SkillID != ZM_SKILL_INVALID && ZM_IsModActive();
}

/**
 * Check if client has this skill
 */
bool ClientHasThisSkill(int client)
{
    return IsClientInGame(client) && 
           IsPlayerAlive(client) && 
           ZM_GetClientSkill(client) == g_SkillID &&
           ZM_IsClientHuman(client);
}

// ============================================================================
// DEVELOPMENT TIPS & BEST PRACTICES
// ============================================================================

/*
 * TIP 1: Always check if your skill is active
 * ─────────────────────────────────────────────
 * Before doing anything skill-specific, check:
 *   if (ZM_GetClientSkill(client) != g_SkillID) return;
 * 
 * 
 * TIP 2: Use button state tracking to prevent spam
 * ─────────────────────────────────────────────────────
 * OnPlayerRunCmd runs every frame (~66 times per second!)
 * Always track previous button state:
 *   if ((buttons & IN_ATTACK2) && !(g_LastButtons[client] & IN_ATTACK2))
 * 
 * 
 * TIP 3: Clean up properly
 * ────────────────────────────
 * Always kill timers and reset state in:
 *   - OnClientDisconnect
 *   - ZM_OnClientDeath
 *   - OnLibraryRemoved
 * 
 * 
 * TIP 4: Handle the main plugin reloading
 * ───────────────────────────────────────────
 * Always re-register in OnLibraryAdded:
 *   if (StrEqual(name, ZM_LIBRARY))
 *       g_SkillID = ZM_RegisterHumanSkill(...);
 * 
 * 
 * TIP 5: Test with and without the main plugin
 * ─────────────────────────────────────────────────
 * Your plugin should:
 *   - Load successfully even if ZM isn't loaded
 *   - Register skill when ZM loads
 *   - Handle ZM unloading gracefully
 * 
 * 
 * TIP 6: Use the API helpers
 * ──────────────────────────────
 * Don't reinvent the wheel:
 *   - ZM_IsClientHuman(client)  // Check if human
 *   - ZM_IsClientZombie(client) // Check if zombie
 *   - ZM_IsModActive()          // Check if mod active
 *   - ZM_IsLoaded()             // Check if main plugin loaded
 * 
 * 
 * TIP 7: Provide good feedback
 * ────────────────────────────────
 * Players should know:
 *   - When ability activates (sound + chat)
 *   - When it's on cooldown
 *   - When it ends
 *   - What it does (in description)
 * 
 * 
 * TIP 8: Balance your skill
 * ─────────────────────────────
 * Consider:
 *   - Is it too powerful? Add cooldown
 *   - Is it too weak? Buff the effect
 *   - Does it overshadow other skills? Adjust
 *   - Does it break the game? Rethink it
 * 
 * 
 * COMMON MISTAKES TO AVOID:
 * ═════════════════════════
 * ✗ Forgetting to check if player has the skill
 * ✗ Not tracking button state (causing spam)
 * ✗ Not cleaning up timers (memory leak!)
 * ✗ Hardcoding skill ID instead of using g_SkillID
 * ✗ Not handling main plugin reload
 * ✗ Making skill work for zombies (should be humans only)
 * ✗ Not providing player feedback
 * 
 * 
 * FILE NAMING CONVENTION:
 * ══════════════════════
 * Name your plugin: dod_zm_skillname.sp
 * Examples:
 *   - dod_zm_barricade.sp
 *   - dod_zm_medic.sp
 *   - dod_zm_engineer.sp
 *   - dod_zm_scout.sp
 * 
 * 
 * COMPILING:
 * ═════════
 * 1. Place this file in addons/sourcemod/scripting/
 * 2. Place dod_zm.inc in addons/sourcemod/scripting/include/
 * 3. Compile: ./compile.sh dod_zm_example.sp
 * 4. Place .smx in addons/sourcemod/plugins/
 * 5. Restart server or use: sm plugins load dod_zm_example
 * 
 * 
 * TESTING CHECKLIST:
 * ══════════════════
 * □ Plugin loads without main ZM plugin
 * □ Plugin registers skill when ZM loads
 * □ Skill appears in skill selection menu
 * □ Skill activates correctly
 * □ Skill only works for humans (not zombies)
 * □ Skill resets on death
 * □ Skill resets on round start
 * □ Timers are cleaned up properly
 * □ No errors in server console
 * □ Player feedback is clear
 * 
 */
