/**
 * dod_zm_ammo_drop.sp
 *
 * Description:
 *   Drops an ammo box at the position of an Allied player on death.
 *   Touching the box restores primary ammo, one pistol clip, grenades,
 *   and rifle grenades (for Garand/BAR carriers).
 *   Intended for use with the DoD:S Zombie Mod.
 *
 * Credits:
 *   Based on DoD:S DropManager by zadroot
 *   https://github.com/zadroot/DoD_Dropmanager
 *
 * Version 1.1.0
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

// ====[ CONSTANTS ]============================================================

#define PLUGIN_NAME    "DoD:S ZM Ammo Drop"
#define PLUGIN_VERSION "1.1.0"

#define MAX_WEAPON_LENGTH 24
#define DOD_MAXPLAYERS    33

// HammerID tag written to dropped ammo box entities so touch callbacks
// can identify them. Value matches the Ammobox position in the original
// DropManager items enum (INVALID_ITEM=-1, NOITEM=0, Healthkit=1, Ammobox=2).
#define ITEM_AMMOBOX 2

// ====[ ENUMS ]================================================================

enum // Slots
{
	SLOT_PRIMARY = 0,
	SLOT_SECONDARY,
	SLOT_MELEE,
	SLOT_GRENADE,
	SLOT_EXPLOSIVE
}

enum // Teams
{
	Spectators = 1,
	Allies,
	Axis
}

enum // Pickup rules
{
	allteams = 0,
	mates,
	enemies
}

// ====[ AMMO DATA ]============================================================

// Stock asset paths - model does not require precaching, sound does
static const char AmmoSound[]       = "items/ammo_pickup.wav";
static const char AlliesAmmoModel[] = "models/ammo/ammo_us.mdl";

// ---- Primary weapons --------------------------------------------------------
// Weapon classnames - strip the "weapon_" prefix (7 chars) before comparing
static const char PrimaryWeapons[][] =
{
	"garand", "k98",        "thompson", "mp40", "bar",     "mp44",
	"spring", "k98_scoped", "30cal",    "mg42", "bazooka", "pschreck"
};

// Per-weapon reserve ammo data offsets (index matches PrimaryWeapons[])
// Source: dod_ammo.sp g_iAmmoOffsets table
static const int PrimaryAmmoOffset[]   = { 16, 20, 32, 32, 36, 32, 28, 20,  40,  44, 48, 48 };

// Per-weapon clip sizes (used to calculate how much ammo a box provides)
static const int PrimaryAmmoClipSize[] = {  8,  5, 30, 30, 20, 30,  5,  5, 150, 250,  1,  1 };

// ---- Pistols ----------------------------------------------------------------
// Classnames compared against SLOT_SECONDARY (strip "weapon_" prefix)
static const char PistolWeapons[][] = { "colt", "p38" };

// Reserve ammo offsets - source: dod_ammo.sp (Colt=4, P38=8)
static const int PistolAmmoOffset[] = { 4, 8 };

// Clip sizes (Colt M1911 = 7 rounds, P38 = 8 rounds)
static const int PistolClipSize[]   = { 7, 8 };

// ---- Grenades ---------------------------------------------------------------
// Frag grenade reserve ammo offsets - source: dod_ammo.sp (frag_us=52, frag_ger=56)
static const int GrenadeAmmoOffset[] = { 52, 56 }; // [0]=Allies, [1]=Axis

// ---- Rifle grenades ---------------------------------------------------------
// Rifle grenade offsets - source: dod_ammo.sp (riflegren_us=84, riflegren_ger=88)
static const int RifleGrenAmmoOffset[] = { 84, 88 }; // [0]=Allies, [1]=Axis

// Primary weapons that can fire rifle grenades
static const char RifleGrenWeapons[][] = { "garand", "bar" };

// ====[ GLOBALS ]==============================================================

int g_iAmmoOffset;

ConVar g_cvLifeTime;
ConVar g_cvClipSize;
ConVar g_cvPickupRule;
ConVar g_cvGrenades;
ConVar g_cvRifleGrenades;

// ====[ PLUGIN INFO ]==========================================================

public Plugin myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root, modified for Zombiemod by Claude.ai guided by DNA.styx",
	description = "Allows player to drop health kits, ammo boxes, explosives and some weapons using different ways",
	version     = PLUGIN_VERSION,
	url         = "https://github.com/DNA-styx/DoD_ZombieMod_Plugins"
};

// ====[ PLUGIN START ]=========================================================

/* OnPluginStart()
 *
 * When the plugin starts up.
 * ---------------------------------------------------------------------------- */
public void OnPluginStart()
{
	// Cache the m_iAmmo property offset for CDODPlayer
	g_iAmmoOffset = FindSendPropInfo("CDODPlayer", "m_iAmmo");

	// Create plugin convars
	g_cvLifeTime     = CreateConVar("zm_ammodrop_lifetime",      "45", "Number of seconds a dropped ammo box stays on the ground. 0 = never remove.",                                                         FCVAR_NOTIFY, true, 0.0);
	g_cvClipSize     = CreateConVar("zm_ammodrop_clipsize",       "2", "Number of primary weapon clips a dropped ammo box contains.",                                                                         FCVAR_NOTIFY, true, 1.0, true, 5.0);
	g_cvPickupRule   = CreateConVar("zm_ammodrop_pickuprule",     "1", "Determines who can pick up dropped ammo boxes: 0 = everyone (Zombies can destroy the box by touching it), 1 = teammates only, 2 = enemies only.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvGrenades     = CreateConVar("zm_ammodrop_grenades",       "2", "Number of grenades to give on ammo box pickup. 0 = disabled.",                                                                        FCVAR_NOTIFY, true, 0.0);
	g_cvRifleGrenades = CreateConVar("zm_ammodrop_riflegrenades", "4", "Number of rifle grenades to give on pickup (Garand/BAR carriers only). 0 = disabled.",                                               FCVAR_NOTIFY, true, 0.0);

	// Hook player death event
	HookEvent("player_death", OnPlayerDeath);

	// Create and exec plugin configuration file
	AutoExecConfig(true, "dod_zm_ammo_drop", "zombiemod");
}

/* OnConfigsExecuted()
 *
 * When the map has loaded and all plugin configs are done executing.
 * ---------------------------------------------------------------------------- */
public void OnConfigsExecuted()
{
	// Ammo box model is a stock asset and does not need precaching
	PrecacheSound(AmmoSound);
}

// ====[ EVENTS ]===============================================================

/* OnPlayerDeath()
 *
 * Called when a player dies.
 * ---------------------------------------------------------------------------- */
public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	// Only drop for Allied (human) players
	if (GetClientTeam(client) != Allies)
		return;

	CreateAmmoBox(client);
}

// ====[ AMMO BOX CREATION ]====================================================

/* CreateAmmoBox()
 *
 * Creates a prop_physics_override ammo box entity at the position of a
 * dead Allied player.
 * ---------------------------------------------------------------------------- */
void CreateAmmoBox(int client)
{
	int item = CreateEntityByName("prop_physics_override");
	if (item == -1)
		return;

	// Allied players always drop the Allied ammo box model
	SetEntityModel(item, AlliesAmmoModel);

	// Spawn the entity - model must be set before DispatchSpawn
	if (!DispatchSpawn(item))
		return;

	// Tag entity with HammerID so the touch callback can identify it
	SetEntProp(item, Prop_Data, "m_iHammerID", ITEM_AMMOBOX);

	// Build spawn origin from the corpse position
	float origin[3];
	GetClientAbsOrigin(client, origin);

	// Raise the box slightly off the ground
	origin[2] += 5.0;

	// Apply team and collision properties
	SetEntProp(item, Prop_Send, "m_iTeamNum",       GetClientTeam(client));
	SetEntProp(item, Prop_Send, "m_usSolidFlags",   152);
	SetEntProp(item, Prop_Send, "m_CollisionGroup", 11);

	// Teleport to corpse position with no velocity
	TeleportEntity(item, origin, NULL_VECTOR, NULL_VECTOR);

	// Set item lifetime if configured
	float lifetime = g_cvLifeTime.FloatValue;
	if (lifetime > 0.0)
	{
		char output[32];
		Format(output, sizeof(output), "OnUser1 !self:kill::%.2f:-1", lifetime);
		SetVariantString(output);
		AcceptEntityInput(item, "AddOutput");
		AcceptEntityInput(item, "FireUser1");
	}

	// Defer touch hook so the entity is fully settled in the world first
	CreateTimer(0.0, Timer_HookTouch, EntIndexToEntRef(item), TIMER_FLAG_NO_MAPCHANGE);
}

// ====[ TOUCH HANDLING ]=======================================================

/* Timer_HookTouch()
 *
 * Deferred SDKHook to attach touch callbacks once the ammo box entity
 * is fully initialised in the world.
 * ---------------------------------------------------------------------------- */
public Action Timer_HookTouch(Handle timer, any ref)
{
	int item = EntRefToEntIndex(ref);

	// Make sure the entity is still valid
	if (item == INVALID_ENT_REFERENCE)
		return Plugin_Stop;

	SDKHook(item, SDKHook_StartTouch, OnAmmoBoxTouched);
	SDKHook(item, SDKHook_Touch,      OnAmmoBoxTouched);
	SDKHook(item, SDKHook_EndTouch,   OnAmmoBoxTouched);

	return Plugin_Stop;
}

/* OnAmmoBoxTouched()
 *
 * When the ammo box is touched by a player.
 * ---------------------------------------------------------------------------- */
public Action OnAmmoBoxTouched(int ammobox, int client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	// Check pickup rule against box team and toucher team
	int pickuprule = g_cvPickupRule.IntValue;
	int clteam     = GetClientTeam(client);
	int ammoteam   = GetEntProp(ammobox, Prop_Send, "m_iTeamNum");

	if ((pickuprule == allteams)
	||  (pickuprule == mates   && ammoteam == clteam)
	||  (pickuprule == enemies && ammoteam != clteam))
	{
		float vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);

		AcceptEntityInput(ammobox, "Kill");
		EmitAmbientSound(AmmoSound, vecOrigin, client);

		GivePrimaryAmmo(client);
		GivePistolAmmo(client);
		GiveGrenadeAmmo(client);
		GiveRifleGrenadeAmmo(client);
	}

	return Plugin_Handled;
}

// ====[ AMMUNITION ]===========================================================

/* GivePrimaryAmmo()
 *
 * Adds primary weapon clips to the player's reserve on pickup.
 * ---------------------------------------------------------------------------- */
void GivePrimaryAmmo(int client)
{
	int primaryWeapon = GetPlayerWeaponSlot(client, SLOT_PRIMARY);
	if (!IsValidEdict(primaryWeapon))
		return;

	// Retrieve the weapon classname and strip the "weapon_" prefix
	char weaponName[MAX_WEAPON_LENGTH];
	GetEdictClassname(primaryWeapon, weaponName, sizeof(weaponName));

	int weaponID = -1;
	for (int i = 0; i < sizeof(PrimaryWeapons); i++)
	{
		if (StrEqual(weaponName[7], PrimaryWeapons[i]))
		{
			weaponID = i;
			break;
		}
	}

	// Unknown weapon - nothing to do
	if (weaponID == -1)
		return;

	int ammoAddr = g_iAmmoOffset + PrimaryAmmoOffset[weaponID];
	int currAmmo = GetEntData(client, ammoAddr);
	int addAmmo  = PrimaryAmmoClipSize[weaponID] * g_cvClipSize.IntValue;

	SetEntData(client, ammoAddr, currAmmo + addAmmo);
}

/* GivePistolAmmo()
 *
 * Gives one clip of pistol ammo to the player on pickup.
 * ---------------------------------------------------------------------------- */
void GivePistolAmmo(int client)
{
	int pistol = GetPlayerWeaponSlot(client, SLOT_SECONDARY);
	if (!IsValidEdict(pistol))
		return;

	// Retrieve the pistol classname and strip the "weapon_" prefix
	char weaponName[MAX_WEAPON_LENGTH];
	GetEdictClassname(pistol, weaponName, sizeof(weaponName));

	int weaponID = -1;
	for (int i = 0; i < sizeof(PistolWeapons); i++)
	{
		if (StrEqual(weaponName[7], PistolWeapons[i]))
		{
			weaponID = i;
			break;
		}
	}

	// Not a recognised pistol - nothing to do
	if (weaponID == -1)
		return;

	int ammoAddr = g_iAmmoOffset + PistolAmmoOffset[weaponID];
	int currAmmo = GetEntData(client, ammoAddr);

	SetEntData(client, ammoAddr, currAmmo + PistolClipSize[weaponID]);
}

/* GiveGrenadeAmmo()
 *
 * Gives grenades to the player on pickup, based on their team.
 * ---------------------------------------------------------------------------- */
void GiveGrenadeAmmo(int client)
{
	int amount = g_cvGrenades.IntValue;
	if (amount <= 0)
		return;

	// Select the correct grenade offset for the player's team
	int teamIndex = (GetClientTeam(client) == Allies) ? 0 : 1;
	int ammoAddr  = g_iAmmoOffset + GrenadeAmmoOffset[teamIndex];
	int currAmmo  = GetEntData(client, ammoAddr);

	SetEntData(client, ammoAddr, currAmmo + amount);
}

/* GiveRifleGrenadeAmmo()
 *
 * Gives rifle grenades to Garand or BAR carriers on pickup.
 * ---------------------------------------------------------------------------- */
void GiveRifleGrenadeAmmo(int client)
{
	int amount = g_cvRifleGrenades.IntValue;
	if (amount <= 0)
		return;

	int primaryWeapon = GetPlayerWeaponSlot(client, SLOT_PRIMARY);
	if (!IsValidEdict(primaryWeapon))
		return;

	// Check if the player is carrying a rifle-grenade-capable weapon
	char weaponName[MAX_WEAPON_LENGTH];
	GetEdictClassname(primaryWeapon, weaponName, sizeof(weaponName));

	bool capable = false;
	for (int i = 0; i < sizeof(RifleGrenWeapons); i++)
	{
		if (StrEqual(weaponName[7], RifleGrenWeapons[i]))
		{
			capable = true;
			break;
		}
	}

	if (!capable)
		return;

	// Select the correct rifle grenade offset for the player's team
	int teamIndex = (GetClientTeam(client) == Allies) ? 0 : 1;
	int ammoAddr  = g_iAmmoOffset + RifleGrenAmmoOffset[teamIndex];
	int currAmmo  = GetEntData(client, ammoAddr);

	SetEntData(client, ammoAddr, currAmmo + amount);
}

// ====[ HELPERS ]==============================================================

/* IsValidClient()
 *
 * Returns true if the client index refers to an in-game player on a
 * playing team.
 * ---------------------------------------------------------------------------- */
bool IsValidClient(int client)
{
	return (1 <= client <= MaxClients
		&& IsClientInGame(client)
		&& GetClientTeam(client) > Spectators);
}
