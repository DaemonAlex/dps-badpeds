# dps-badpeds - Police NPC Interaction System

A FiveM resource that allows police officers to interact with random pedestrian NPCs - check IDs, frisk for items, seize contraband, and make arrests. Built **qbx_core-native** (Qbox) using ox_lib, ox_target and ox_inventory, for a FivePD-style experience.

---

## Table of Contents
- [What This Script Does](#what-this-script-does)
- [Gameplay Flow](#gameplay-flow)
- [Features](#features)
- [File Structure](#file-structure)
- [On its own, and with other scripts](#on-its-own-and-with-other-scripts)
- [Dependencies](#dependencies)
- [Configuration](#configuration)
- [Technical Details](#technical-details)
- [Potential Improvements](#potential-improvements)
- [Integration with dps-ainpcs](#integration-with-dps-ainpcs)
- [Installation](#installation)
- [Recent changes](#recent-changes)
- [Author](#author)
- [Other DPS scripts](#other-dps-scripts)

---

## What This Script Does

This script gives police officers the ability to stop and interact with **any random NPC pedestrian** in the world. Unlike player-to-player interactions, this creates organic police roleplay content without needing another player.

**Think of it as**: FivePD-style pedestrian stops for roleplay servers.

### The Problem It Solves
- Police officers have nothing to do when no criminals are online
- Creates realistic patrol gameplay
- Generates dynamic dispatch calls for other officers
- Provides training scenarios for new officers

- Makes the streets feel alive for everyone: corner crews on the gang blocks, drivers who snap after a crash, and emergency vehicles that pass through on their way to a call

In short: it is for police who need something to do on a quiet shift, and for a city that should not feel empty when few players are on.

---

## Gameplay Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         OFFICER APPROACHES NPC                          │
│                    (Within 20m, target prompt appears)                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           POLICE MENU                                   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  [👤] Check ID Card      - View NPC's identification            │   │
│  │  [🔍] Frisk Pedestrian   - Search for items                     │   │
│  │  [❌] Close Menu         - Release the NPC                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
            ┌──────────────┐                ┌──────────────┐
            │  CHECK ID    │                │    FRISK     │
            │              │                │              │
            │ • Mugshot    │                │ NPC puts     │
            │ • Name       │                │ hands up     │
            │ • Gender     │                │              │
            │              │                │ 3-6 random   │
            │ Press ESC    │                │ items from   │
            │ to close     │                │ inventory    │
            └──────────────┘                └──────────────┘
                    │                               │
                    ▼                               ▼
            Return to menu          ┌───────────────┴───────────────┐
                                    ▼                               ▼
                            ┌──────────────┐                ┌──────────────┐
                            │ LEGAL ITEMS  │                │ILLEGAL ITEMS │
                            │    ONLY      │                │    FOUND     │
                            │              │                │              │
                            │ • Water      │                │ • Drugs      │
                            │ • Food       │                │ • Weapons    │
                            │ • Cigarettes │                │ • Lockpicks  │
                            │              │                │              │
                            │ Return to    │                │  DISPATCH    │
                            │ menu         │                │  SENT TO     │
                            └──────────────┘                │  OTHER COPS  │
                                                            └──────────────┘
                                                                    │
                                                                    ▼
                                                    ┌──────────────────────────┐
                                                    │      ARREST MENU         │
                                                    │                          │
                                                    │ • Click items to SEIZE   │
                                                    │ • Frisk again            │
                                                    │ • NEGOTIATE INTEL (NEW)  │
                                                    │ • ARREST                 │
                                                    └──────────────────────────┘
                                                                    │
                                        ┌───────────────────────────┼───────────────────────────┐
                                        ▼                           ▼                           ▼
                                ┌──────────────┐            ┌──────────────┐            ┌──────────────┐
                                │   ARREST     │            │  NEGOTIATE   │            │  (continued) │
                                │   DIRECT     │            │    INTEL     │            │              │
                                └──────────────┘            └──────────────┘            └──────────────┘
                                        │                           │
                                        ▼                           ▼
                        ┌───────────────┴───────────────┐   ┌──────────────────────────┐
                        ▼                               ▼   │  70% HAS INTEL           │
                ┌──────────────┐                ┌──────────────┐                        │
                │  COMPLIANT   │                │   RUNNER     │  • Hear intel first    │
                │    (50%)     │                │    (50%)     │  • Accept deal         │
                │              │                │              │  • Reject & arrest     │
                │ NPC surrenders│               │ NPC FLEES!   │  • Offer informant deal│
                │ Fade to black │               │              │                        │
                │ Arrest done   │               │ Dispatch:    └──────────────────────────┘
                │              │                │ "Foot Pursuit"│           │
                │ Dispatch:    │                │              │            ▼
                │ "Arrest Made"│                │ Officer gets │    ┌──────────────┐
                │              │                │ stun gun     │    │  INFORMANT   │
                │ Jail time    │                │              │    │    DEAL      │
                │ calculated   │                │ Must taze &  │    │              │
                └──────────────┘                │ arrest       │    │ 40% accepts  │
                                                │              │    │ Release or   │
                                                │ Dispatch:    │    │ Arrest anyway│
                                                │ "Arrest Made"│    └──────────────┘
                                                └──────────────┘
```

---

## Features

### 1. Dynamic NPC Detection
| Feature | Description |
|---------|-------------|
| Auto-scanning | Scans for pedestrians within 20m every 1.5 seconds |
| Network registration | Deferred: a ped is only registered as networked when an officer actually interacts (perf) |
| Target pruning | Targets are removed when a ped despawns or leaves range, so handles don't leak |
| Target integration | Works with ox_target (default) or qb-target |
| Job restriction | Only visible to players whose job has the type `leo` (any law-enforcement job) |

### 2. ID Card System
| Feature | Description |
|---------|-------------|
| Dynamic mugshot | Captures NPC's face using GTA's headshot system |
| Generated names | Random first/last name based on gender |
| Persistent identity | Same NPC = same name (until deleted) |
| Custom UI | Displays ID card with photo overlay |

### 3. Frisk/Search System
| Feature | Description |
|---------|-------------|
| Animations | NPC plays "hands up" animation |
| Dynamic items | Pulls from your actual inventory system |
| Legal/illegal | Items classified via config blacklist |
| **Clickable seizure** | Click items to take them |
| Quantity variation | Random amounts (1-5 per item) |

### 4. Arrest System
| Feature | Description |
|---------|-------------|
| Conditional | Only available when contraband found |
| Personality-driven flight | Whether a suspect runs is driven by their personality `fleeChance` (paranoid/aggressive run often, smooth/calm rarely), not a coin flip |
| Chase mechanic | Runner must be tazed to arrest |
| Stun gun provision | Officer receives stun gun for chase |
| Evidence-safe seizure | Seized contraband goes to an evidence stash (or is destroyed + logged) — never into the officer's own inventory |

### 5. MDT/Dispatch Integration
| Event | Dispatch Sent | Priority |
|-------|---------------|----------|
| Illegal items found | "Contraband Located" | 2 |
| Suspect flees | "Foot Pursuit" | 3 |
| Arrest complete | "Arrest Made" | 1 |

### 6. Intel Trading System
| Feature | Description |
|---------|-------------|
| **Intel Negotiation** | NPCs can offer information to reduce sentence |
| **Personality-driven intel** | Chance a suspect talks uses their personality `intelChance`; characters flagged `canGiveIntel = false` stay silent |
| **Sentence reduction** | Accepting an intel deal actually multiplies the sentence by `Config.jailSystem.intelReduction` (default 0.5) |
| **Dynamic Intel** | Generated based on items found (drugs/weapons/gang) |
| **Intel Database** | All intel stored in `npc_intel_reports` table |
| **Informant Recruitment** | Chance NPC accepts uses their personality `informantChance` |
| **Release Option** | Release informants without charges to maintain cover |

### 6b. Personalities & Specialties
Recurring characters (see `shared/characters.lua`) carry a `personality` and `specialty` that now
drive real behaviour:

| Data | Effect |
|------|--------|
| `personality.fleeChance` | Likelihood the suspect runs on arrest |
| `personality.intelChance` | Likelihood they have useful intel to trade |
| `personality.informantChance` | Likelihood they accept an informant deal |
| `character.illegalChance` | How likely their frisk turns up contraband |
| `character.specialty` | Biases which contraband they carry (drugs/weapons/theft/petty/gang) |

Random (non-recurring) pedestrians use safe defaults (fleeChance 50, intelChance 70, informantChance 40, illegalChance 40).

### 7. Jail/Unavailability System (NEW)
| Feature | Description |
|---------|-------------|
| **Arrest Records** | All arrests stored in database |
| **Dynamic Sentencing** | Jail time based on contraband severity |
| **Criminal History** | ID card shows prior arrests |
| **Real-Time Conversion** | 1 game hour = 2 real minutes (configurable) |
| **Max Sentence** | 72 game hours maximum |

**Sentencing Guidelines:**
| Offense | Base + Bonus Hours |
|---------|-------------------|
| Weapons | +12 hours |
| Drug Bricks | +8 hours |
| Regular Drugs | +4 hours |
| Crime Tools | +6 hours |

### 8. AI Integration (Optional)
| Feature | Description |
|---------|-------------|
| **dps-ainpcs Support** | Connect to AI NPC system |
| **Dynamic Dialogue** | AI-generated responses based on context |
| **Fallback System** | Static dialogues if AI unavailable |

### 8b. Street Life
| Feature | Description |
|---------|-------------|
| **City Pulse** | One number for how much NPC crime the city needs right now. It drops when gang members are online or real incidents happen, and it is zero when nobody is online. Other scripts can read it with `exports['dps-badpeds']:GetPulse()` |
| **Rough nights** | At dusk (20:00 game time) the night is rolled as quiet, normal, rough or wild. Rough and wild nights raise the pulse and lean on the Davis blocks |
| **Corner crews** | Small groups of local NPCs stand on 15 gang-block corners. Police can talk to, frisk and arrest them with the normal flow. 60% carry contraband. When a cop comes close they pocket their hands, walk off or run |
| **Police tips** | Now and then an anonymous caller reports a group dealing on a corner. Tips are random and never closer than 20 minutes apart |
| **Road rage** | Bump an NPC car and the driver may snap. He chases and rams you. If you get out, he gets out too. On wild nights he may have a pistol |
| **Vibe patrol** | Police cars, ambulances and fire engines drive past from their real stations to somewhere beyond you. Most police passes are quiet. Some run lights and siren, and some are a pursuit of a suspect car. Passes come more often near the gang blocks. They stop when more than 3 real officers are on duty |
| **Pavement rule** | Crew NPCs are never placed in the road |

Commands: `/pulse` shows the pulse and its inputs (console or the `command` ace). `/vibenow` forces one patrol pass for testing, and `/vibenow chase` forces a pursuit.

### 9. Security
| Protection | Description |
|------------|-------------|
| Server authority | All validation done server-side |
| Distance checks | Must be within 5-10m for actions |
| NPC locking | One officer per NPC |
| Net ID validation | Prevents entity spoofing |

---

## File Structure

```
dps-badpeds/
├── fxmanifest.lua      # Resource manifest (v2.1.0)
├── config.lua          # All configuration (~220 lines)
│   ├── Jail system settings
│   ├── AI integration settings
│   ├── Intel templates
│   └── Dispatch configuration
├── client/
│   ├── crews.lua       # Corner crews
│   ├── roadrage.lua    # Road rage
│   └── patrol.lua      # Vibe patrol
├── server/
│   ├── pulse.lua       # City Pulse (export GetPulse, /pulse)
│   └── street.lua      # Crew spots, police tips, road rage and patrol rolls
├── shared/
│   └── characters.lua  # Shared character pool (also loaded by dps-ainpcs)
├── client.lua          # Client logic (~835 lines)
│   ├── NPC detection loop
│   ├── Target registration
│   ├── Menu handling
│   ├── ID card display (with criminal history)
│   ├── Arrest scenarios
│   ├── Intel trading UI
│   ├── Informant recruitment
│   ├── Dispatch integration
│   └── AI dialogue hooks
├── server.lua          # Server logic (~760 lines)
│   ├── Jail system functions
│   ├── Intel generation
│   ├── Informant management
│   ├── Database operations
│   ├── Validation functions
│   ├── NPC inventory generation
│   ├── Item seizure handling
│   ├── Arrest processing
│   └── Data cleanup
├── sql/
│   └── jail_records.sql  # Database migration
├── stream/
│   └── idcard.ytd      # ID card texture (106KB)
└── README.md           # This file
```

---

## On its own, and with other scripts

**On its own.** With qbx_core, ox_lib, ox_target, ox_inventory and oxmysql you get everything a police officer does with an NPC: stop, ID card, frisk, seize, chase, arrest, intel deals, informants and jail records. You also get the street life: the City Pulse, corner crews, road rage and the vibe patrol. Seized items go to an ox_inventory evidence stash. With no dispatch script running, no calls are sent and the rest works the same.

**With a paid police computer (wasabi_mdt).** This is the default dispatch. Other officers see a call on the MDT when contraband is found ("Contraband Located"), when a suspect runs ("Foot Pursuit") and when an arrest is made ("Arrest Made"). The street life adds anonymous calls: a tip about a group dealing on a corner, and "Road rage, shots fired" when an armed driver opens fire. The script only sends calls through the wasabi_mdt `CreateDispatch` export. It reads nothing from the MDT and changes nothing in it, and it checks that wasabi_mdt is running first.

**With another dispatch script (ps-dispatch or cd_dispatch).** Set `Config.dispatch.resource`. The three stop and arrest calls go out through that script's event. cd_dispatch is paid and ps-dispatch is free. The corner tips and the road rage call use the wasabi_mdt call format, so they are only confirmed to work with wasabi_mdt.

**With a paid inventory (qs-inventory).** Set `Config.inventory = 'qs-inventory'`. The NPC's pockets are filled from the qs-inventory item list, and the stun gun for a chase is given and taken through it. The evidence stash is an ox_inventory feature, so ox_inventory is the tested setup.

**With dps-ainpcs.** dps-ainpcs needs this script. Both use the character list in `shared/characters.lua`, so the known criminals police meet on the street are the same people players talk to as informants and dealers. When police arrest one of them here, this script tells dps-ainpcs, which ends any talk with that NPC. While the character is in jail, dps-ainpcs asks this script (`IsCharacterAvailable`) and keeps the NPC out of reach. The AI dialogue option (`Config.aiIntegration`) is off by default.

**With dps-gangwars and dps-hookers.** These run next to this script with no direct link. The corner crews here stand on the same blocks as the gang NPCs from dps-gangwars, and the vibe patrol passes more often there.

---

## Dependencies

### Required
```
qbx_core      - Framework (qbx_core native; no qb-core resource needed even with the qb bridge on)
ox_lib        - Menus + notifications (lib.notify / lib.registerContext)
ox_target     - NPC targeting
ox_inventory  - Item data + evidence stash + item give/take
oxmysql       - Jail/intel database
```

> Note: qb-target and qs-inventory paths still exist in the code for portability, but the
> defaults and the tested stack are ox_target + ox_inventory.

### Inventory Support
```lua
Config.inventory = 'ox_inventory'  -- Options:
-- 'ox_inventory'  (default, tested)
-- 'qs-inventory'
```

### Optional (Dispatch)
```lua
Config.dispatch.resource = 'wasabi_mdt'  -- Options:
-- 'wasabi_mdt'
-- 'ps-dispatch'
-- 'cd_dispatch'
```

---

## Configuration

### config.lua Overview

```lua
-- Target & Inventory
Config.target = 'ox_target'
Config.inventory = 'ox_inventory'

-- Seizure handling (never gives contraband to the officer)
Config.SeizeMode = 'evidence' -- 'evidence' (ox_inventory stash) | 'destroy' (remove + log)
Config.evidenceStash = { id = 'evidence-badpeds', label = 'Seized Evidence', slots = 100, maxWeight = 1000000 }

-- Dispatch Integration
Config.dispatch = {
    enabled = true,
    resource = 'wasabi_mdt',
    illegalItemsFound = { enabled = true, priority = 2, ... },
    suspectFleeing = { enabled = true, priority = 3, ... },
    arrestMade = { enabled = true, priority = 1, ... },
}

-- NPC Inventory
Config.npcItemCount = { min = 3, max = 6 }
Config.itemQuantity = { min = 1, max = 5 }

-- Illegal Items (triggers arrest option)
Config.illegalItems = {
    "joint", "cokebaggy", "weapon_pistol", "lockpick", ...
}

-- Excluded Items (won't spawn on NPCs)
Config.excludedItems = {
    "phone", "police_badge", "weapon_stungun", ...
}

-- Name Generation
Config.malefirstNames = { "John", "Michael", ... }
Config.femalefirstNames = { "Emily", "Madison", ... }
Config.lastNames = { "Smith", "Johnson", ... }
```

### How Items Are Generated

1. **On resource start**: Server calls `exports.ox_inventory:Items()` (or `qs-inventory:GetItemList()`)
2. **Filtering**: Removes items in `excludedItems` list, then splits into legal / illegal sub-pools
3. **On frisk**: Generates 3-6 items, weighting illegal vs legal by the character's `illegalChance` and biasing the illegal category by `specialty`
4. **Classification**: Checks against `illegalItems` blacklist
5. **Persistence**: Inventory stored server-side until NPC deleted

---

## Technical Details

### Event Communication

```
CLIENT                              SERVER
   │                                   │
   │  pedInteraction:request ────────► │ Validate NPC, lock it
   │ ◄──────── pedInteraction:approved │
   │                                   │
   │  addinventory ──────────────────► │ Generate/return items
   │ ◄──────────────────────── addmenu │
   │                                   │
   │  npc:seizeItem:server ──────────► │ Give item to player
   │ ◄───────────── npc:refreshInventory│
   │                                   │
   │  arrestnpc ─────────────────────► │ Remove stun gun, cleanup
   │ ◄────────────────────── deletenpc │
```

### Data Storage (Server-Side)
```lua
activeInteractions[playerSource] = netId  -- Who's talking to which NPC
npcInventories[netId] = { items... }      -- NPC's generated inventory
npcNames[netId] = { first, last, gender } -- NPC's generated identity
npcIllegal[netId] = true/false            -- Has illegal items?
npcLocks[netId] = playerSource            -- Who has this NPC locked?
```

---

## Potential Improvements

### High Priority
| Feature | Description | Effort |
|---------|-------------|--------|
| **Warrant Check** | Query MDT for active warrants on NPC name | Medium |
| **Vehicle Stops** | Pull over NPCs in vehicles, search car | High |
| **Multiple Jobs** | Done on 25 September 2026: any job with the type `leo` can use the script | Done |
| **ox_lib Menu** | Modern menu instead of qb-menu | Easy |

### Medium Priority
| Feature | Description | Effort |
|---------|-------------|--------|
| Item Weighting | Illegal items rarer than legal | Easy |
| NPC Reactions | Nervous behavior if carrying drugs | Medium |
| Citation System | Tickets for minor offenses | Medium |
| Evidence Bagging | Package items for MDT cases | Medium |
| Chase Improvements | NPC steals car, more pursuit variety | High |

### Nice to Have
| Feature | Description | Effort |
|---------|-------------|--------|
| Area-based items | Gang areas = more weapons | Easy |
| Time-based | More crime at night | Easy |
| K9 Integration | Dog sniffs out drugs | High |
| NPC Memory | Remember previous interactions | Medium |

---

## Integration with dps-ainpcs

Try the **dps-ainpcs** script, it creates AI-powered NPCs with conversations, trust systems, and intel trading. These two scripts complement each other:

### Option 1: Keep Separate (Recommended)
- **dps-badpeds**: For random street NPCs (any pedestrian)
- **dps-ainpcs**: For specific configured AI NPCs (informants, dealers)
- Police can frisk random people, but AI NPCs have deeper interaction

### Option 2: Merge Features
Add police frisk capability to dps-ainpcs NPCs:
```lua
-- In dps-ainpcs, add to NPC options:
{
    label = "Frisk",
    icon = "fas fa-search",
    job = "police",
    onSelect = function(npc)
        -- Trigger dps-badpeds's frisk system
        -- Or implement custom frisk for AI NPCs
    end
}
```

### Option 3: Full Integration Ideas
| Feature | Description |
|---------|-------------|
| **AI Resistance** | AI NPCs could argue, demand warrant, or lie |
| **Trust Impact** | Frisking an informant damages trust relationship |
| **Intel from Arrest** | Arrested NPC might give up information |
| **Bribery** | NPC offers money to avoid arrest |
| **Lawyer Request** | "I want my lawyer" dialogue option |

### Shared Data
Both scripts could share:
- NPC identity (same name system)
- Criminal history
- Trust/reputation
- MDT records

---

## Installation

1. **Download** and place in resources folder

2. **Run SQL Migration** (if using jail system):
   ```sql
   -- Run the contents of sql/jail_records.sql in your database
   -- Creates: npc_jail_records, npc_informants, npc_intel_reports tables
   ```

3. **Add to server.cfg**:
   ```cfg
   ensure qbx_core
   ensure ox_lib
   ensure ox_target
   ensure ox_inventory
   ensure oxmysql        # Required for jail system
   ensure wasabi_mdt     # Optional for dispatch
   ensure dps-ainpcs     # Optional for AI dialogue
   ensure dps-badpeds
   ```

4. **Configure** `config.lua`:
   - Set target system (`ox_target` default, or `qb-target`)
   - Set inventory system (`ox_inventory` default, or `qs-inventory`)
   - Set seizure handling (`Config.SeizeMode` + `Config.evidenceStash`)
   - Enable/disable jail system
   - Enable/disable AI integration
   - Adjust illegal items list
   - Configure dispatch settings
   - Customize intel templates

5. **Restart** server or `ensure dps-badpeds`

### Quick Start (Minimal Setup)
```lua
-- config.lua minimal changes
Config.target = 'ox_target'
Config.inventory = 'ox_inventory'
Config.jailSystem.enabled = false  -- Disable if not using database
Config.aiIntegration.enabled = false
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Target not appearing | Check your job has the type `leo`, ensure ox_target running |
| Items not generating | Verify inventory resource name in config |
| "Item does not exist" | Item spawn code not in your inventory |
| Seized items vanish | Expected - they go to the `evidence-badpeds` stash (or are destroyed if `SeizeMode = 'destroy'`) |
| Dispatch not sending | Check wasabi_mdt is running, dispatch enabled |
| NPC not responding | Another officer may have it locked |

---

## Recent changes

- **12 November 2026.** README: what it is for, how it works alone and with paid scripts, other DPS scripts. The job check text now matches the code.
- **30 October 2026.** Vibe patrol added: police, ambulance and fire units drive through from their real stations to a point beyond the player. Most police passes are routine with no siren. Passes are heavier near the gang blocks. Some siren passes are a pursuit of a suspect car. `/vibenow` forces a pass for testing. The crew pavement check was fixed (it read the game's position result in the wrong shape and stopped the spawner).
- **29 October 2026.** Street life added: the City Pulse (export `GetPulse`, `/pulse`), rough nights rolled at dusk, corner crews on 15 spots, random police tips and road rage.
- **25 September 2026.** Police checks use the job type `leo`, so every law-enforcement job can use the script. It used to be the `police` job only.

---

## Author

Made by [DaemonAlex](https://github.com/DaemonAlex) for DelPerroSands.

---

## Credits

- **Author**: DPS Development
- **Framework**: Qbox (qbx_core) / Overextended (ox_lib, ox_target, ox_inventory, oxmysql)

---

## License

Free to use and modify for personal or server use.
Redistribution or resale requires permission from the author.

## Other DPS scripts

All of these are made for DelPerroSands and run together on one Qbox server. Each one works on
its own. The ones marked "pairs with" do more when both are running.

| Script | What it does |
|---|---|
| [dps-inventory](https://github.com/DaemonAlex/dps-inventory) | The inventory: ox_inventory with equipment slots, backpacks, armour plates and a self status panel, in the DelPerroSands colours. |
| [dps-medical](https://github.com/DaemonAlex/dps-medical) | Patient records, illness and diagnostic tests. A companion to wasabi_ambulance. Pairs with dps-inventory: symptoms and diagnoses show on the status panel. |
| [dps-insurance](https://github.com/DaemonAlex/dps-insurance) | Ties m-Insurance into the MDT, impound, hospital and medical chart. Pairs with dps-medical. |
| [dps-studio](https://github.com/DaemonAlex/dps-studio) | Build rooms, doors and portals in game from one panel (`/studio`), with owners and managers so staff do not have to support them. |
| [dps-shops](https://github.com/DaemonAlex/dps-shops) | Shop clerks who greet and react to a robbery, then player-owned shops. |
| [dps-fleet](https://github.com/DaemonAlex/dps-fleet) | Vehicle browser and workshop on one panel: extras, liveries and mods for emergency vehicles. |
| [dps-parking](https://github.com/DaemonAlex/dps-parking) | Parking with valet, impound, violations and reserved spots. |
| [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence) | Vehicles stay where they were parked. Pairs with dps-parking. |
| [dps-towjob](https://github.com/DaemonAlex/dps-towjob) | Queue-based tow job with jg-mechanic integration. |
| [dps-services](https://github.com/DaemonAlex/dps-services) | Request a tow and follow it live on the lb-phone and lb-tablet. Pairs with dps-towjob. |
| [dps-autoshops](https://github.com/DaemonAlex/dps-autoshops) | Self-service repair shops when no mechanic is on duty. |
| [dps-cityworker](https://github.com/DaemonAlex/dps-cityworker) | City infrastructure job and career. |
| [dps-ainpcs](https://github.com/DaemonAlex/dps-ainpcs) | NPCs you can talk to, with trust, quests and intel. |
| [dps-gangwars](https://github.com/DaemonAlex/dps-gangwars) | Ambient gang NPCs, territory population and war reinforcements. |
| [dps-rotations](https://github.com/DaemonAlex/dps-rotations) | Moves dealers, harvests and other spots on a fixed schedule. |
| [dps-trains](https://github.com/DaemonAlex/dps-trains) | The train system. Pairs with dps-trains-stock, dps-traintools and dps-transitapp. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
