# DoD:S Zombie Mod - Plugin Development Specification v1.1

## Overview

Complete guide for creating custom human skill plugins for the DoD:S Zombie Mod. This modular plugin system allows developers to create custom skills without modifying the main plugin.

**Version 1.1 Features:**
- Standardized message prefix system
- Helper functions for chat messages  
- Visual distinction between personal and broadcast messages
- Duplicate registration protection (v0.8.8+)

---

## Quick Start (5 Minutes)

### 1. Include the API Header
```sourcepawn
#include <sourcemod>
#include <sdktools>
#include <dod_zm>  // Required API header
```

### 2. Store Skill ID
```sourcepawn
ZMSkillID g_SkillID = ZM_SKILL_INVALID;
```

### 3. Register Your Skill
```sourcepawn
public void OnAllPluginsLoaded()
{
    if (g_SkillID == ZM_SKILL_INVALID && ZM_IsLoaded())
    {
        g_SkillID = ZM_RegisterHumanSkill(
            "My Skill",              // Name in menu
            "Does something cool"    // Description
        );
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY) && g_SkillID == ZM_SKILL_INVALID)
        g_SkillID = ZM_RegisterHumanSkill("My Skill", "Does something cool");
}
```

### 4. Check If Active
```sourcepawn
public Action OnPlayerRunCmd(int client, int &buttons, /*...*/)
{
    // Check if player has YOUR skill
    if (ZM_GetClientSkill(client) != g_SkillID)
        return Plugin_Continue;
    
    // Your skill logic here
    if ((buttons & IN_ATTACK2) && !(g_LastButtons[client] & IN_ATTACK2))
    {
        ActivateAbility(client);
    }
    
    g_LastButtons[client] = buttons;
    return Plugin_Continue;
}
```

### 5. Compile & Deploy
```bash
./compile.sh dod_zm_myskill.sp
# Place .smx in plugins/ folder
sm plugins load dod_zm_myskill
```

Done! Your skill appears in the equipment menu.

---

## System Architecture

### Main Components
- **Main Plugin:** `dod_zombiemod.smx` - Core zombie mod with native registrations
- **API Header:** `dod_zm.inc` - Defines natives, forwards, helper functions, message prefixes
- **Skill Plugins:** `dod_zm_*.smx` - Individual skill plugins that register with main plugin

### How It Works
1. Main plugin loads and registers natives via `AskPluginLoad2`
2. Main plugin creates library `"dod_zm_core"`
3. Skill plugins load and register via `ZM_RegisterHumanSkill()`
4. Main plugin builds dynamic menu with all registered skills
5. Players select skills from menu (locked per life)
6. Skill plugins check `ZM_GetClientSkill(client) == g_SkillID` to activate

### Plugin Reload Support (v0.8.8+)
- Main plugin detects duplicate registrations
- Skill plugins can be reloaded without creating duplicate menu entries
- Same skill ID maintained across reloads

---

## Message System (v1.1)

### Standardized Prefixes

All skill plugins should use standard `[ZM]` prefix with color-coding:

**Personal Messages (to one player):**
```sourcepawn
ZM_PrintToChat(client, "Ability activated!");
// Shows: [ZM] Ability activated! 
// Prefix color: Olive/Yellow (indicates targeted message)
```

**Broadcast Messages (to all players):**
```sourcepawn
ZM_PrintToChatAll("Round starting!");
// Shows: [ZM] Round starting!
// Prefix color: Green (indicates server-wide message)
```

### Why Two Colors?
- **Olive prefix** = "This message is just for you"
- **Green prefix** = "Everyone sees this message"

This helps players instantly understand message context.

---

## Complete API Reference

### Message Helper Functions (Stock)

#### `ZM_PrintToChat`
```sourcepawn
stock void ZM_PrintToChat(int client, const char[] format, any ...)
```
**Purpose:** Send personal message to one client with standard prefix  
**Color:** Olive/yellow prefix `[ZM]` (targeted message)  
**Parameters:**
- `client` - Client to send message to
- `format` - Message format string (printf-style)
- `...` - Format arguments

**Example:**
```sourcepawn
ZM_PrintToChat(client, "Ability activated!");
ZM_PrintToChat(client, "Cooldown: %d seconds", cooldown);
```

---

#### `ZM_PrintToChatAll`
```sourcepawn
stock void ZM_PrintToChatAll(const char[] format, any ...)
```
**Purpose:** Broadcast message to all clients with standard prefix  
**Color:** Green prefix `[ZM]` (server-wide message)  
**Parameters:**
- `format` - Message format string (printf-style)
- `...` - Format arguments

**Example:**
```sourcepawn
ZM_PrintToChatAll("Round starting in %d seconds!", time);
ZM_PrintToChatAll("Player %N selected Engineer skill!", client);
```

---

### Natives (Functions You Call)

#### `ZM_RegisterHumanSkill`
```sourcepawn
ZMSkillID ZM_RegisterHumanSkill(const char[] name, const char[] description)
```
**Purpose:** Register your skill with the main plugin  
**When:** Call in `OnAllPluginsLoaded()` or `OnLibraryAdded()`  
**Parameters:**
- `name` - Skill name shown in menu (max 64 chars)
- `description` - Skill description shown to players (max 128 chars)

**Returns:** `ZMSkillID` (skill ID) or `ZM_SKILL_INVALID` (-1) on failure

**Example:**
```sourcepawn
g_SkillID = ZM_RegisterHumanSkill("Medic", "Heal teammates with right-click");
```

**Important:** Always check `g_SkillID == ZM_SKILL_INVALID` before registering to avoid duplicate attempts.

---

#### `ZM_GetClientSkill`
```sourcepawn
ZMSkillID ZM_GetClientSkill(int client)
```
**Purpose:** Get the currently active skill for a client  
**Parameters:**
- `client` - Client index (1-MaxClients)

**Returns:** `ZMSkillID` or `ZM_SKILL_NONE` (0) if no skill selected

**Example:**
```sourcepawn
if (ZM_GetClientSkill(client) == g_SkillID)
{
    // Player has YOUR skill active
}
```

---

#### `ZM_IsClientHuman`
```sourcepawn
bool ZM_IsClientHuman(int client)
```
**Purpose:** Check if client is on human team (Allies)  
**Parameters:**
- `client` - Client index

**Returns:** `true` if human, `false` otherwise

---

#### `ZM_IsClientZombie`
```sourcepawn
bool ZM_IsClientZombie(int client)
```
**Purpose:** Check if client is on zombie team (Axis)  
**Parameters:**
- `client` - Client index

**Returns:** `true` if zombie, `false` otherwise

---

#### `ZM_IsModActive`
```sourcepawn
bool ZM_IsModActive()
```
**Purpose:** Check if zombie mod is currently active  
**Returns:** `true` if active, `false` otherwise

---

#### `ZM_IsLoaded` (Stock Helper)
```sourcepawn
bool ZM_IsLoaded()
```
**Purpose:** Check if main ZM plugin is loaded  
**Returns:** `true` if loaded, `false` otherwise  
**Note:** This is a stock function defined in the .inc file

---

### Forwards (Events You Receive)

#### `ZM_OnSkillAssigned`
```sourcepawn
forward void ZM_OnSkillAssigned(int client, ZMSkillID skillID);
```
**Purpose:** Called when a player selects a skill  
**When:** After player spawns and selects from equipment menu  
**Parameters:**
- `client` - Client who selected skill
- `skillID` - The skill ID they selected (0 = none, 1+ = skill)

**Use Case:** Initialize skill state when player selects your skill

**Example:**
```sourcepawn
public void ZM_OnSkillAssigned(int client, ZMSkillID skillID)
{
    if (skillID == g_SkillID)
    {
        ZM_PrintToChat(client, "Medic skill selected!");
    }
}
```

---

#### `ZM_OnRoundStart`
```sourcepawn
forward void ZM_OnRoundStart();
```
**Purpose:** Called when round starts  
**Use Case:** Reset round-based state, counters, cooldowns

---

#### `ZM_OnRoundEnd`
```sourcepawn
forward void ZM_OnRoundEnd();
```
**Purpose:** Called when round ends  
**Use Case:** Clean up round state

---

#### `ZM_OnClientDeath`
```sourcepawn
forward void ZM_OnClientDeath(int client);
```
**Purpose:** Called when a client dies  
**Parameters:**
- `client` - Client who died

**Use Case:** Kill timers, remove buffs, clean up client state

---

#### `ZM_OnClientSpawn`
```sourcepawn
forward void ZM_OnClientSpawn(int client, ZMTeam team);
```
**Purpose:** Called when a client spawns  
**Parameters:**
- `client` - Client who spawned
- `team` - Team they spawned on (`ZM_TEAM_ALLIES` or `ZM_TEAM_AXIS`)

**Use Case:** Reset per-life state

---

### Enums & Constants

```sourcepawn
#define ZM_LIBRARY "dod_zm_core"
#define ZM_MAX_SKILL_NAME 64
#define ZM_MAX_SKILL_DESC 128

// Message prefixes for standardized formatting
#define ZM_PREFIX_PERSONAL "\x04[ZM]\x01"    // Olive prefix for individual messages
#define ZM_PREFIX_BROADCAST "\x03[ZM]\x01"   // Green prefix for broadcast messages

enum ZMSkillID
{
    ZM_SKILL_INVALID = -1,  // Registration failed
    ZM_SKILL_NONE = 0,      // No skill selected
    // Skills IDs start at 1 and increment
};

enum ZMTeam
{
    ZM_TEAM_UNASSIGNED = 0,
    ZM_TEAM_SPECTATOR = 1,
    ZM_TEAM_ALLIES = 2,    // Humans
    ZM_TEAM_AXIS = 3       // Zombies
};
```

---

## Common Patterns

### Pattern 1: Button-Activated Ability

```sourcepawn
int g_LastButtons[MAXPLAYERS+1];

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
    if (g_SkillID == ZM_SKILL_INVALID)
        return Plugin_Continue;
    
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Continue;
    
    if (ZM_GetClientSkill(client) != g_SkillID)
        return Plugin_Continue;
    
    if (!ZM_IsClientHuman(client))
        return Plugin_Continue;
    
    // Detect RIGHT CLICK press (not hold!)
    if ((buttons & IN_ATTACK2) && !(g_LastButtons[client] & IN_ATTACK2))
    {
        ActivateAbility(client);
    }
    
    g_LastButtons[client] = buttons;
    return Plugin_Continue;
}
```

---

### Pattern 2: Cooldown System with Feedback

```sourcepawn
float g_NextUseTime[MAXPLAYERS+1];

void ActivateAbility(int client)
{
    float currentTime = GetGameTime();
    
    if (currentTime < g_NextUseTime[client])
    {
        float remaining = g_NextUseTime[client] - currentTime;
        ZM_PrintToChat(client, "Ability on cooldown: %.1f seconds", remaining);
        return;
    }
    
    // Do ability
    DoAbilityEffect(client);
    
    // Set cooldown
    g_NextUseTime[client] = currentTime + 15.0;  // 15 seconds
    ZM_PrintToChat(client, "Ability activated!");
}

// Reset on spawn
public void ZM_OnClientSpawn(int client, ZMTeam team)
{
    g_NextUseTime[client] = 0.0;
}
```

---

### Pattern 3: Temporary Buff

```sourcepawn
bool g_BuffActive[MAXPLAYERS+1];
Handle g_BuffTimer[MAXPLAYERS+1];

void ApplyBuff(int client)
{
    g_BuffActive[client] = true;
    
    // Apply effect
    SetEntityGravity(client, 0.5);
    
    // Timer to remove
    g_BuffTimer[client] = CreateTimer(10.0, Timer_RemoveBuff, 
        GetClientUserId(client));
    
    ZM_PrintToChat(client, "Low gravity activated for 10 seconds!");
}

public Action Timer_RemoveBuff(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    if (client && IsClientInGame(client))
    {
        g_BuffActive[client] = false;
        SetEntityGravity(client, 1.0);
        g_BuffTimer[client] = null;
        
        ZM_PrintToChat(client, "Buff expired!");
    }
    return Plugin_Stop;
}

// Clean up on death/disconnect
public void ZM_OnClientDeath(int client)
{
    if (g_BuffTimer[client] != null)
    {
        KillTimer(g_BuffTimer[client]);
        g_BuffTimer[client] = null;
    }
    g_BuffActive[client] = false;
}
```

---

### Pattern 4: Passive Ability with Broadcast

```sourcepawn
public void ZM_OnSkillAssigned(int client, ZMSkillID skillID)
{
    if (skillID == g_SkillID && ZM_IsClientHuman(client))
    {
        // Apply passive effect
        int health = GetClientHealth(client);
        SetEntityHealth(client, health + 50);
        
        ZM_PrintToChat(client, "+50 HP bonus!");
        ZM_PrintToChatAll("Player %N selected Tank skill!", client);
    }
}
```

---

### Pattern 5: Resource System with Feedback

```sourcepawn
int g_Charges[MAXPLAYERS+1];
#define MAX_CHARGES 5

void UseCharge(int client)
{
    if (g_Charges[client] >= MAX_CHARGES)
    {
        ZM_PrintToChat(client, "No charges left (%d/%d)", 
            g_Charges[client], MAX_CHARGES);
        return;
    }
    
    g_Charges[client]++;
    
    // Do ability
    ZM_PrintToChat(client, "Charge used (%d/%d)", 
        g_Charges[client], MAX_CHARGES);
}

// Reset on spawn
public void ZM_OnClientSpawn(int client, ZMTeam team)
{
    g_Charges[client] = 0;
}
```

---

## Required Plugin Structure

### Minimal Working Plugin

```sourcepawn
#include <sourcemod>
#include <sdktools>
#include <dod_zm>  // REQUIRED: Include the API

#pragma semicolon 1
#pragma newdecls required

// Plugin info
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_NAME "DoD:S ZM - Your Skill Name"

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = "Your Name",
    description = "Your skill description",
    version = PLUGIN_VERSION,
    url = ""
};

// Store skill ID
ZMSkillID g_SkillID = ZM_SKILL_INVALID;

// Initialize
public void OnPluginStart()
{
    // Hook events, create ConVars, etc.
}

// Register skill (when ZM already loaded)
public void OnAllPluginsLoaded()
{
    if (g_SkillID == ZM_SKILL_INVALID && ZM_IsLoaded())
    {
        g_SkillID = ZM_RegisterHumanSkill(
            "Your Skill",
            "What it does"
        );
    }
}

// Register skill (when ZM loads after us)
public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY) && g_SkillID == ZM_SKILL_INVALID)
    {
        g_SkillID = ZM_RegisterHumanSkill(
            "Your Skill",
            "What it does"
        );
    }
}

// Handle ZM unloading
public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY))
    {
        // Clean up
        g_SkillID = ZM_SKILL_INVALID;
    }
}

// Clean up on disconnect
public void OnClientDisconnect(int client)
{
    // Clean up client state
}

// Your skill logic
public Action OnPlayerRunCmd(int client, int &buttons, /*...*/)
{
    if (ZM_GetClientSkill(client) != g_SkillID)
        return Plugin_Continue;
    
    // Your ability logic here
    
    return Plugin_Continue;
}
```

---

## Critical Requirements

### Must Have:

1. **Include the API:** `#include <dod_zm>`
2. **Store skill ID:** `ZMSkillID g_SkillID = ZM_SKILL_INVALID;`
3. **Register in OnAllPluginsLoaded:** Check `g_SkillID == ZM_SKILL_INVALID` first
4. **Register in OnLibraryAdded:** Check `g_SkillID == ZM_SKILL_INVALID` first
5. **Handle OnLibraryRemoved:** Clean up and reset `g_SkillID`
6. **Check skill active:** Always use `ZM_GetClientSkill(client) == g_SkillID`
7. **Check team:** Use `ZM_IsClientHuman(client)` for human-only abilities
8. **Use standard messages:** Use `ZM_PrintToChat()` or `ZM_PrintToChatAll()` for feedback

### Common Mistakes:

1. Not checking if skill already registered (handled by main plugin in v0.8.8+)
2. Not checking if player has skill - ability works for everyone
3. Not tracking button state - spam on OnPlayerRunCmd
4. Not cleaning up timers - memory leaks
5. Forgetting OnLibraryAdded - broken if ZM reloads
6. Hardcoding skill ID - breaks when other skills load
7. Using custom message prefixes - inconsistent player experience

---

## File Naming & Locations

### File Names
```
dod_zm_skillname.sp
```

**Examples:**
- `dod_zm_medic.sp` - Medic skill
- `dod_zm_engineer.sp` - Engineer skill
- `dod_zm_scout.sp` - Scout skill

### Directory Structure
```
addons/sourcemod/
├── scripting/
│   ├── include/
│   │   └── dod_zm.inc              ← API header (SKILL PLUGINS ONLY)
│   └── dod_zm_yourskill.sp         ← Your plugin
└── plugins/
    ├── dod_zombiemod.smx           ← Main plugin
    └── dod_zm_yourskill.smx        ← Your skill
```

**Important:** The main plugin (`dod_zombiemod.smx`) does **NOT** need `dod_zm.inc`. The .inc file is **ONLY** for skill plugin developers.

---

## Testing Checklist

Before releasing your skill plugin:

- [ ] Plugin loads without main ZM plugin
- [ ] Plugin registers skill when ZM loads
- [ ] Plugin can be reloaded without duplicates (v0.8.8+)
- [ ] Skill appears in equipment menu
- [ ] Skill activates correctly
- [ ] Only works for humans (not zombies)
- [ ] Resets on death
- [ ] Resets on round start
- [ ] Timers cleaned up on disconnect
- [ ] No console errors
- [ ] Uses standard message prefixes (ZM_PrintToChat/ZM_PrintToChatAll)
- [ ] Personal messages use olive prefix
- [ ] Broadcast messages use green prefix
- [ ] Good player feedback (clear messages, sounds)
- [ ] Works with other skills (no conflicts)
- [ ] Handles main plugin reload gracefully

---

## Debugging Tips

### Enable Logging
```sourcepawn
PrintToServer("[My Skill] Player %N activated ability", client);
LogMessage("[My Skill] Skill ID: %d, Player skill: %d", 
    g_SkillID, ZM_GetClientSkill(client));
```

### Check Registration
```sourcepawn
if (g_SkillID == ZM_SKILL_INVALID)
    SetFailState("Failed to register skill!");
else
    PrintToServer("[My Skill] Registered as ID %d", g_SkillID);
```

### Console Commands for Testing
```
sm plugins list              // List all plugins
sm plugins reload myskill    // Reload your skill
sm plugins unload myskill    // Unload your skill
```

---

## FAQ

**Q: Can I make skills for zombies?**  
A: Not yet - this system is for human skills only. A zombie class system may be added later.

**Q: How many skills can be registered?**  
A: Currently 32, but this can be increased if needed.

**Q: Will my skill work if the main plugin reloads?**  
A: Yes! If you implement `OnLibraryAdded()` correctly, your skill will re-register automatically.

**Q: Can skills conflict with each other?**  
A: No - each skill has a unique ID and only activates when selected.

**Q: Can I make skills that cost money/points?**  
A: Not built-in, but you could integrate with an economy plugin.

**Q: What happens when I reload my skill plugin?**  
A: As of v0.8.8+, the main plugin detects duplicate registrations and updates the existing entry. No duplicate menu entries!

**Q: How do I share my skill with others?**  
A: Share the .sp file! Others can compile it themselves. Consider posting on GitHub.

---

## Best Practices Summary

1. Always check `g_SkillID == ZM_SKILL_INVALID` before registering
2. Always check `ZM_GetClientSkill(client) == g_SkillID` before activating
3. Track button state to prevent spam
4. Clean up timers in disconnect/death handlers
5. Use `ZM_IsClientHuman()` for human-only abilities
6. Use `ZM_PrintToChat()` for personal messages (olive prefix)
7. Use `ZM_PrintToChatAll()` for broadcasts (green prefix)
8. Test with main plugin reload scenarios
9. Document your skill's usage
10. Balance carefully (cooldowns, costs, effects)
11. Share with the community!

---

## Support

- **GitHub Issues:** https://github.com/DNA-styx/DoD_ZombieMod/issues
- **Discord:** https://discord.gg/bemuuRKscw
- **Documentation:** See `dod_zm.inc` for API details

---

## Quick Start Template

Copy this to start a new skill:

```sourcepawn
#include <sourcemod>
#include <sdktools>
#include <dod_zm>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_NAME "DoD:S ZM - [Skill Name]"

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = "[Your Name]",
    description = "[Skill description]",
    version = PLUGIN_VERSION,
    url = ""
};

ZMSkillID g_SkillID = ZM_SKILL_INVALID;

public void OnPluginStart() {}

public void OnAllPluginsLoaded()
{
    if (g_SkillID == ZM_SKILL_INVALID && ZM_IsLoaded())
        g_SkillID = ZM_RegisterHumanSkill("[Name]", "[Description]");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY) && g_SkillID == ZM_SKILL_INVALID)
        g_SkillID = ZM_RegisterHumanSkill("[Name]", "[Description]");
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, ZM_LIBRARY))
        g_SkillID = ZM_SKILL_INVALID;
}

// Add your skill logic here
// Remember to use ZM_PrintToChat() and ZM_PrintToChatAll()!
```

---

**End of Specification v1.1**

*This document contains everything needed to create custom skill plugins for DoD:S Zombie Mod.*
