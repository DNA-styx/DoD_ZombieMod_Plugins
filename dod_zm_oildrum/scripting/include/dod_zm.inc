/**
 * =============================================================================
 * DoD:S Zombie Mod - Plugin API
 *
 * Include this file in human skill plugins and zombie class plugins to
 * integrate with the main Zombie Mod plugin.
 *
 * Human skill plugins:  register via ZM_RegisterHumanSkill()
 * Zombie class plugins: register via ZM_RegisterZombieClass()
 *
 * Version: 1.3.0
 * =============================================================================
 */

#if defined _dod_zm_included
  #endinput
#endif
#define _dod_zm_included

/* Library name used in OnLibraryAdded / OnLibraryRemoved */
#define ZM_LIBRARY "dod_zm_core"

// ============================================================================
// HUMAN SKILL CONSTANTS
// ============================================================================

#define ZM_MAX_SKILL_NAME 64
#define ZM_MAX_SKILL_DESC 128

// ============================================================================
// ZOMBIE CLASS CONSTANTS
// ============================================================================

#define ZM_MAX_CLASS_NAME 64
#define ZM_MAX_CLASS_DESC 128

// ============================================================================
// ENUMS
// ============================================================================

/**
 * Skill ID returned by ZM_RegisterHumanSkill().
 * Store this and compare against ZM_GetClientSkill() to check activation.
 */
enum ZMSkillID
{
	ZM_SKILL_INVALID = -1,  /* Registration failed */
	ZM_SKILL_NONE    = 0,   /* No skill selected */
	/* Skill IDs start at 1 and increment automatically */
};

/**
 * Zombie class ID returned by ZM_RegisterZombieClass().
 * Built-in IDs: 0=Normal, 1=Gas, 2=TNT, 3=Ghost.
 * External class plugins that register a built-in name (e.g. "TNT Zombie")
 * will receive the existing built-in ID rather than a new one.
 */
enum ZMClassID
{
	ZM_CLASS_INVALID = -1,  /* Registration failed */
	/* Class IDs start at 0 and increment automatically */
};

/**
 * Team constants for use with ZM_OnClientSpawn.
 */
enum ZMTeam
{
	ZM_TEAM_UNASSIGNED = 0,
	ZM_TEAM_SPECTATOR  = 1,
	ZM_TEAM_ALLIES     = 2,  /* Humans */
	ZM_TEAM_AXIS       = 3   /* Zombies */
};

// ============================================================================
// HUMAN SKILL NATIVES
// ============================================================================

/**
 * Register a human skill with the main plugin.
 * Call in OnAllPluginsLoaded() or OnLibraryAdded().
 * Re-registering the same skill name updates the existing slot in-place.
 *
 * @param name          Skill name shown in the equipment menu (max 64 chars)
 * @param description   Short description shown to players (max 128 chars)
 * @return              Skill ID, or ZM_SKILL_INVALID on failure
 */
native ZMSkillID ZM_RegisterHumanSkill(const char[] name, const char[] description);

/**
 * Get the active skill ID for a client.
 *
 * @param client    Client index
 * @return          Skill ID, or ZM_SKILL_NONE if no skill selected
 */
native ZMSkillID ZM_GetClientSkill(int client);

/**
 * Check if a client is on the human team (Allies).
 *
 * @param client    Client index
 * @return          True if human
 */
native bool ZM_IsClientHuman(int client);

/**
 * Check if a client is on the zombie team (Axis).
 *
 * @param client    Client index
 * @return          True if zombie
 */
native bool ZM_IsClientZombie(int client);

/**
 * Check if the zombie mod is currently active.
 *
 * @return          True if active
 */
native bool ZM_IsModActive();

// ============================================================================
// ZOMBIE CLASS NATIVES
// ============================================================================

/**
 * Register a zombie class with the main plugin.
 * Call in OnAllPluginsLoaded() or OnLibraryAdded().
 * If a class with the same name is already registered (e.g. a built-in),
 * the existing slot is updated and its ID is returned — the class selection
 * menu and random assignment are unaffected.
 *
 * @param name          Class name shown in the class menu (max 64 chars)
 * @param description   Short description shown to players (max 128 chars)
 * @return              Class ID, or ZM_CLASS_INVALID on failure
 */
native ZMClassID ZM_RegisterZombieClass(const char[] name, const char[] description);

/**
 * Get the active zombie class ID for a client.
 *
 * @param client    Client index
 * @return          Class ID (0=Normal, 1=Gas, 2=TNT, 3=Ghost for built-ins)
 */
native ZMClassID ZM_GetClientZombieClass(int client);

/**
 * Get the display name for a registered zombie class ID.
 *
 * @param classID       Class ID to look up
 * @param buffer        Output buffer
 * @param maxlength     Size of output buffer
 */
native void ZM_GetZombieClassName(ZMClassID classID, char[] buffer, int maxlength);

// ============================================================================
// FORWARDS — HUMAN SKILLS
// ============================================================================

/**
 * Called when a player selects a skill from the equipment menu.
 * Use this to apply passive effects or show a confirmation message.
 * Consider using PrintCenterText() so the player sees their selection.
 *
 * @param client    Client who selected the skill
 * @param skillID   The skill ID selected (ZM_SKILL_NONE if none)
 */
forward void ZM_OnSkillAssigned(int client, ZMSkillID skillID);

/**
 * Called when a round starts.
 * Use this to reset round-based state.
 */
forward void ZM_OnRoundStart();

/**
 * Called when a round ends.
 */
forward void ZM_OnRoundEnd();

/**
 * Called when a client dies.
 * Use this to clean up per-life state (timers, buffs, etc.).
 *
 * @param client    Client who died
 */
forward void ZM_OnClientDeath(int client);

/**
 * Called when a client spawns.
 *
 * @param client    Client who spawned
 * @param team      ZM_TEAM_ALLIES or ZM_TEAM_AXIS
 */
forward void ZM_OnClientSpawn(int client, ZMTeam team);

// ============================================================================
// FORWARDS — ZOMBIE CLASSES
// ============================================================================

/**
 * Called when a zombie dies.
 * Implement this to attach a death effect to your registered class.
 * Always check classID == g_ClassID before acting — this fires for all zombies.
 * Consider using PrintCenterText() or PrintToChat() to notify nearby players.
 *
 * @param client    Zombie client who died
 * @param classID   Their zombie class ID at time of death
 */
forward void ZM_OnZombieDeath(int client, ZMClassID classID);

// ============================================================================
// STOCK HELPERS
// ============================================================================

/**
 * Check if the main ZM plugin is loaded.
 * Use this to gracefully handle the main plugin being absent.
 *
 * @return          True if loaded
 */
stock bool ZM_IsLoaded()
{
	return LibraryExists(ZM_LIBRARY);
}

// ============================================================================
// PLUGIN DEPENDENCY DECLARATION
// ============================================================================

public SharedPlugin __pl_dod_zm =
{
	name = ZM_LIBRARY,
	file = "dod_zombiemod.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_dod_zm_SetNTVOptional()
{
	/* Human skill natives */
	MarkNativeAsOptional("ZM_RegisterHumanSkill");
	MarkNativeAsOptional("ZM_GetClientSkill");
	MarkNativeAsOptional("ZM_IsClientHuman");
	MarkNativeAsOptional("ZM_IsClientZombie");
	MarkNativeAsOptional("ZM_IsModActive");

	/* Zombie class natives */
	MarkNativeAsOptional("ZM_RegisterZombieClass");
	MarkNativeAsOptional("ZM_GetClientZombieClass");
	MarkNativeAsOptional("ZM_GetZombieClassName");
}
#endif
