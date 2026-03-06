/**
 * =============================================================================
 * DoD:S Zombie Mod - Modular Skill System API
 * 
 * This include file defines the API for creating modular human skill plugins
 * that integrate with the main Zombie Mod plugin.
 * 
 * Version: 1.0.0
 * =============================================================================
 */

#if defined _dod_zm_included
  #endinput
#endif
#define _dod_zm_included

// Library name for dependency checking
#define ZM_LIBRARY "dod_zm_core"

// Maximum skill name and description lengths
#define ZM_MAX_SKILL_NAME 64
#define ZM_MAX_SKILL_DESC 128

/**
 * Skill ID type - returned when registering a skill
 * Use this to check if a player has your skill active
 */
enum ZMSkillID
{
	ZM_SKILL_INVALID = -1,  // Invalid/unregistered skill
	ZM_SKILL_NONE = 0,      // Player has no skill selected
	// Skills start at ID 1 and increment automatically
};

/**
 * Team definitions for clarity
 */
enum ZMTeam
{
	ZM_TEAM_UNASSIGNED = 0,
	ZM_TEAM_SPECTATOR = 1,
	ZM_TEAM_ALLIES = 2,    // Humans
	ZM_TEAM_AXIS = 3       // Zombies
};

// ============================================================================
// NATIVES - Call these from your skill plugin
// ============================================================================

/**
 * Register a human skill with the main plugin
 * Call this in OnAllPluginsLoaded or OnLibraryAdded
 *
 * @param name          Skill name (displayed in menu)
 * @param description   Skill description (shown to players)
 * @return              Skill ID to use for checking if player has this skill,
 *                      or ZM_SKILL_INVALID on failure
 */
native ZMSkillID ZM_RegisterHumanSkill(const char[] name, const char[] description);

/**
 * Get the currently active skill ID for a client
 * Returns ZM_SKILL_NONE if no skill selected
 *
 * @param client    Client index
 * @return          Skill ID or ZM_SKILL_NONE
 */
native ZMSkillID ZM_GetClientSkill(int client);

/**
 * Check if a client is a human (Allies team)
 *
 * @param client    Client index
 * @return          True if human, false otherwise
 */
native bool ZM_IsClientHuman(int client);

/**
 * Check if a client is a zombie (Axis team)
 *
 * @param client    Client index
 * @return          True if zombie, false otherwise
 */
native bool ZM_IsClientZombie(int client);

/**
 * Check if the zombie mod is currently active
 *
 * @return          True if mod active, false otherwise
 */
native bool ZM_IsModActive();

// ============================================================================
// FORWARDS - Implement these in your skill plugin to receive notifications
// ============================================================================

/**
 * Called when a player selects a skill (locked for that life)
 * This is called AFTER the player spawns and selects from menu
 *
 * @param client    Client who selected the skill
 * @param skillID   The skill ID they selected (ZM_SKILL_NONE if none)
 */
forward void ZM_OnSkillAssigned(int client, ZMSkillID skillID);

/**
 * Called when a round starts
 * Use this to reset any round-based state
 */
forward void ZM_OnRoundStart();

/**
 * Called when a round ends
 * Use this to clean up round state
 */
forward void ZM_OnRoundEnd();

/**
 * Called when a client dies
 * Use this to clean up client-specific state
 *
 * @param client    Client who died
 */
forward void ZM_OnClientDeath(int client);

/**
 * Called when a client spawns
 *
 * @param client    Client who spawned
 * @param team      Team they spawned on (ZM_TEAM_ALLIES or ZM_TEAM_AXIS)
 */
forward void ZM_OnClientSpawn(int client, ZMTeam team);

// ============================================================================
// SHARED FUNCTIONS - Helper functions available to all plugins
// ============================================================================

/**
 * Check if the main ZM plugin is loaded
 * Use this in your plugin to gracefully handle the main plugin being absent
 *
 * @return          True if main plugin loaded
 */
stock bool ZM_IsLoaded()
{
	return LibraryExists(ZM_LIBRARY);
}

// ============================================================================
// PUBLIC NATIVES DECLARATION
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
	MarkNativeAsOptional("ZM_RegisterHumanSkill");
	MarkNativeAsOptional("ZM_GetClientSkill");
	MarkNativeAsOptional("ZM_IsClientHuman");
	MarkNativeAsOptional("ZM_IsClientZombie");
	MarkNativeAsOptional("ZM_IsModActive");
}
#endif

// ============================================================================
// MESSAGE PREFIXES - Standard formatting for chat messages
// ============================================================================

/**
 * Prefix for messages sent to individual players
 * Color: Olive/Yellow - indicates targeted message
 * Usage: PrintToChat(client, ZM_PREFIX_PERSONAL " Your message");
 */
#define ZM_PREFIX_PERSONAL "\x04[ZM]\x01"

/**
 * Prefix for messages broadcast to all players
 * Color: Green - indicates server-wide message
 * Usage: PrintToChatAll(ZM_PREFIX_BROADCAST " Server message");
 */
#define ZM_PREFIX_BROADCAST "\x03[ZM]\x01"

/**
 * Helper function: Send personal message to one client
 * 
 * @param client    Client to send message to
 * @param format    Message format string
 * @param ...       Format arguments
 */
stock void ZM_PrintToChat(int client, const char[] format, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);
	PrintToChat(client, "%s %s", ZM_PREFIX_PERSONAL, buffer);
}

/**
 * Helper function: Broadcast message to all clients
 * 
 * @param format    Message format string
 * @param ...       Format arguments
 */
stock void ZM_PrintToChatAll(const char[] format, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);
	PrintToChatAll("%s %s", ZM_PREFIX_BROADCAST, buffer);
}
