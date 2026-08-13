# dps-badpeds - Police NPC Interaction System

A FiveM resource that allows police officers to interact with random pedestrian NPCs - check IDs, frisk for items, seize contraband, and make arrests. Built **qbx_core-native** (Qbox) using ox_lib, ox_target and ox_inventory, for a FivePD-style experience.

---

## Table of Contents
- [What This Script Does](#what-this-script-does)
- [Gameplay Flow](#gameplay-flow)
- [Features](#features)
- [File Structure](#file-structure)
- [Dependencies](#dependencies)
- [Configuration](#configuration)
- [Technical Details](#technical-details)
- [Potential Improvements](#potential-improvements)
- [Integration with dps-ainpcs](#integration-with-dps-ainpcs)
- [Installation](#installation)

---

## What This Script Does

This script gives police officers the ability to stop and interact with **any random NPC pedestrian** in the world. Unlike player-to-player interactions, this creates organic police roleplay content without needing another player.

**Think of it as**: FivePD-style pedestrian stops for roleplay servers.

### The Problem It Solves
- Police officers have nothing to do when no criminals are online
- Creates realistic patrol gameplay
- Generates dynamic dispatch calls for other officers
- Provides training scenarios for new officers

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
| Job restriction | Only visible to players with `police` job |

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
| **Multiple Jobs** | Support sheriff, state police, etc. | Easy |
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
| Target not appearing | Check job is `police`, ensure ox_target running |
| Items not generating | Verify inventory resource name in config |
| "Item does not exist" | Item spawn code not in your inventory |
| Seized items vanish | Expected - they go to the `evidence-badpeds` stash (or are destroyed if `SeizeMode = 'destroy'`) |
| Dispatch not sending | Check wasabi_mdt is running, dispatch enabled |
| NPC not responding | Another officer may have it locked |

---

## Credits

- **Author**: DPS Development
- **Framework**: Qbox (qbx_core) / Overextended (ox_lib, ox_target, ox_inventory, oxmysql)

---

## License

Free to use and modify for personal or server use.
Redistribution or resale requires permission from the author.

