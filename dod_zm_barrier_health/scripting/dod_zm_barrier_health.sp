#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define TEAM_AXIS 3

public Plugin myinfo = {
    name = "ZombieMod - Barrier Health Display",
    author = "Google Gemini guided by DNA.styx",
    description = "Display health of entities when damaged by Zombies",
    version = "1.4"
};

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity > MaxClients && IsValidEntity(entity))
    {
        SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
    }
}

public void OnTakeDamagePost(int entity, int attacker, int inflictor, float damage, int damageType)
{
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker))
    {
        if (GetClientTeam(attacker) == TEAM_AXIS)
        {
            if (IsValidEntity(entity) && HasEntProp(entity, Prop_Data, "m_iHealth"))
            {
                int health = GetEntProp(entity, Prop_Data, "m_iHealth");

                // If health is 0 or less, it's unbreakable or already destroyed. 
                // We exit here so nothing is printed to the screen.
                if (health <= 0)
                {
                    return;
                }

                PrintCenterText(attacker, "Object Health: %d", health);
            }
        }
    }
}