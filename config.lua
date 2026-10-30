Config = {}

Config.target = 'ox_target' -- Options: 'qb-target', 'ox_target'
Config.inventory = 'ox_inventory' -- Options: 'qb-inventory', 'qs-inventory', 'ox_inventory'

-- ============================================================================
-- SEIZURE CONFIGURATION
-- ============================================================================
-- Contraband seized from NPCs must NOT go into the officer's own inventory
-- (NPC inventories are randomised high-value items, so that would be an
-- infinite money/weapon exploit). Instead we route seized items to an
-- evidence stash, or simply destroy + log them.

Config.SeizeMode = 'evidence' -- Options: 'evidence' (route to ox_inventory stash) | 'destroy' (remove + log only)

-- ox_inventory stash used when Config.SeizeMode == 'evidence'
Config.evidenceStash = {
    id = 'evidence-badpeds', -- Stash identifier (a single shared evidence locker)
    label = 'Seized Evidence',
    slots = 100,
    maxWeight = 1000000, -- grams
}

-- ============================================================================
-- JAIL SYSTEM CONFIGURATION
-- ============================================================================
-- Requires oxmysql and running the SQL migration in sql/jail_records.sql

Config.jailSystem = {
    enabled = true,                    -- Enable jail/unavailability system
    defaultJailHours = 24,             -- Base jail time in game hours
    maxJailHours = 72,                 -- Maximum jail time
    gameHourToRealMinutes = 2,         -- How many real minutes = 1 game hour (default GTA is 2)

    -- Bonus jail time for different offense types
    weaponBonus = 12,                  -- Extra hours for weapons
    drugBrickBonus = 8,                -- Extra hours for large drug quantities
    drugBonus = 4,                     -- Extra hours for regular drugs
    crimeToolBonus = 6,                -- Extra hours for lockpicks, thermite, etc.

    -- Intel trading reduces sentence
    intelReduction = 0.5,              -- Multiplier when NPC gives intel (0.5 = 50% reduction)
}

-- ============================================================================
-- JAIL STATUS CACHE (Performance for high-pop servers)
-- ============================================================================
-- Instead of querying the database every time we need to check if a character
-- is available, we use an in-memory cache that refreshes periodically.
-- This reduces DB load from potentially hundreds of queries to 1 per minute.

Config.jailStatusCache = {
    refreshInterval = 60000,           -- How often to refresh cache in ms (60000 = 60 seconds)
    debug = false,                     -- Log cache refreshes to console
}

-- ============================================================================
-- AI INTEGRATION (dps-ainpcs)
-- ============================================================================

Config.aiIntegration = {
    enabled = false,                   -- Enable AI dialogue integration
    resource = 'dps-ainpcs',           -- AI NPC resource name
    useAIForDialogue = true,           -- Use AI to generate NPC responses
    fallbackToStatic = true,           -- Use static dialogues if AI unavailable
}

-- ============================================================================
-- INTEL SYSTEM CONFIGURATION
-- ============================================================================

-- Templates for generated intel (placeholders: {location}, {name}, {gang})
Config.intelTemplates = {
    drugs = {
        "There's a guy who hangs around {location}, he's been moving weight lately.",
        "Check the parking lot behind {location}, deals go down there every night.",
        "I heard {name} has been cooking in a house near {location}.",
        "Big shipment coming through {location} this week.",
        "The spot behind the gas station at {location} is where they stash it.",
    },
    weapons = {
        "There's an arms deal happening near {location} soon.",
        "Check the trunk of cars parked at {location}, lots of heat moving through there.",
        "Some guys have been stockpiling at a warehouse near {location}.",
        "{name} runs guns out of {location}. Everyone knows it.",
        "There's a guy at {location} who can get you anything. Military grade.",
    },
    gang = {
        "The {gang} have been recruiting near {location}.",
        "There's beef brewing between crews at {location}.",
        "Watch {location}, something big is being planned.",
        "{gang} jumped some kid near {location} last week. They're expanding.",
        "The corner at {location} belongs to {gang} now.",
    }
}

-- Locations used in intel generation
Config.intelLocations = {
    "Grove Street", "Mirror Park", "Vinewood", "Del Perro", "Vespucci",
    "La Mesa", "Strawberry", "Davis", "Rancho", "East Los Santos",
    "Pillbox Hill", "Little Seoul", "Rockford Hills", "Pacific Bluffs",
    "Paleto Bay", "Sandy Shores", "Grapeseed", "Harmony"
}

-- ============================================================================
-- MDT/DISPATCH INTEGRATION
-- ============================================================================

-- MDT/Dispatch Integration (wasabi_mdt)
Config.dispatch = {
    enabled = true,                    -- Enable dispatch notifications
    resource = 'wasabi_mdt',           -- Dispatch resource name

    -- When illegal items are found during frisk
    illegalItemsFound = {
        enabled = true,
        priority = 2,                  -- 1-5 (5 = highest priority)
        type = 'drugs',                -- Dispatch type/icon
        title = 'Contraband Located',
        description = 'Officer located contraband during pedestrian stop. Requesting backup for potential arrest.',
    },

    -- When suspect flees (chase scenario)
    suspectFleeing = {
        enabled = true,
        priority = 3,
        type = 'pursuit',
        title = 'Foot Pursuit',
        description = 'Suspect fled on foot after being confronted with contraband. Pursuing suspect.',
    },

    -- When arrest is made successfully
    arrestMade = {
        enabled = true,
        priority = 1,
        type = 'arrest',
        title = 'Arrest Made',
        description = 'Suspect apprehended and in custody.',
    },
}

-- How many items should NPCs carry? (random between min and max)
Config.npcItemCount = { min = 3, max = 6 }

-- Quantity range for items (random between min and max)
Config.itemQuantity = { min = 1, max = 5 }

-- Items that are ILLEGAL (will trigger arrest option)
-- Just list the item spawn names - no need to duplicate the whole item database
Config.illegalItems = {
    -- Drugs
    "joint", "cokebaggy", "crack_baggy", "xtcbaggy", "meth", "meth_baggy",
    "weed_brick", "coke_brick", "coke_small_brick", "oxy", "heroin",
    "weed_white-widow", "weed_skunk", "weed_purple-haze", "weed_og-kush",
    "weed_amnesia", "weed_ak47", "weed_baggy", "weed", "lsd", "ecstasy",
    "cocaine", "opium", "shrooms", "acid", "pills", "xanax",

    -- Weapons (non-police)
    "weapon_pistol", "weapon_snspistol", "weapon_heavypistol", "weapon_vintagepistol",
    "weapon_pistol50", "weapon_appistol", "weapon_combatpistol", "weapon_pistol_mk2",
    "weapon_revolver", "weapon_revolver_mk2", "weapon_doubleaction",
    "weapon_knife", "weapon_switchblade", "weapon_dagger", "weapon_machete",
    "weapon_bottle", "weapon_knuckle", "weapon_hatchet", "weapon_battleaxe",
    "weapon_microsmg", "weapon_smg", "weapon_assaultsmg", "weapon_minismg",
    "weapon_pumpshotgun", "weapon_sawnoffshotgun", "weapon_assaultshotgun",
    "weapon_assaultrifle", "weapon_carbinerifle", "weapon_advancedrifle",
    "weapon_specialcarbine", "weapon_bullpuprifle", "weapon_compactrifle",

    -- Ammo
    "pistol_ammo", "smg_ammo", "rifle_ammo", "shotgun_ammo", "sniper_ammo",
    "ammo_pistol", "ammo_smg", "ammo_rifle", "ammo_shotgun", "ammo_sniper",

    -- Crime tools
    "lockpick", "advancedlockpick", "electronickit", "thermite", "hackerdevice",
    "vpn", "laptop", "cryptostick", "trojan_usb", "usb_device",
    "handcuffs", "ziptie", "duct_tape",

    -- Stolen goods
    "markedbills", "goldbar", "rolex", "diamond", "diamond_ring", "jewels",
    "stolen_goods", "dirty_money", "evidence", "moneybag",
    "10kgoldchain", "chain", "bracelet", "necklace",

    -- Fake/forged items
    "fakeid", "fakeplate", "fake_id",
}

-- Items to EXCLUDE from spawning on NPCs (job items, unique items, materials, etc.)
Config.excludedItems = {
    -- Phone/identification (everyone has these, not interesting)
    "phone", "id_card", "driver_license",

    -- Job-specific items
    "police_badge", "ems_badge", "mechanic_badge",
    "radio", "radioscanner", "handcuffs", "weapon_stungun",
    "armor", "heavyarmor", "bodyarmor",

    -- Vehicle/housing keys
    "carkey", "housekey", "keychain",

    -- Crafting materials (boring on NPCs)
    "plastic", "glass", "metalscrap", "copper", "iron", "steel", "aluminum",
    "rubber", "cloth", "leather", "wood", "carbon",

    -- Seeds and farming
    "weed_white-widow_seed", "weed_skunk_seed", "weed_purple-haze_seed",
    "weed_og-kush_seed", "weed_amnesia_seed", "weed_ak47_seed",
    "seed", "fertilizer", "water_can",

    -- Misc excluded
    "stickynote", "empty_evidence_bag", "filled_evidence_bag",
    "parachute", "binoculars",
}

-- Fallback items if GetItemList fails or returns empty
-- These will be used as a backup
Config.fallbackItems = {
    { item = "water_bottle", label = "Water Bottle" },
    { item = "sandwich", label = "Sandwich" },
    { item = "coffee", label = "Coffee" },
    { item = "cigarette", label = "Cigarette" },
    { item = "lighter", label = "Lighter" },
    { item = "money", label = "Cash" },
    { item = "joint", label = "Joint" },
    { item = "cokebaggy", label = "Bag of Coke" },
    { item = "lockpick", label = "Lockpick" },
    { item = "weapon_knife", label = "Knife" },
}

-- ============================================================================
-- RECURRING CHARACTERS (Known Criminals)
-- ============================================================================
-- These characters have a chance to spawn instead of random NPCs
-- They build up rap sheets over time and become familiar faces

Config.recurringCharacters = {
    enabled = true,
    spawnChance = 25,             -- 25% chance a stopped NPC is a known criminal
    shareWithAINpcs = true,       -- Share character pool with dps-ainpcs
    rotationEnabled = true,       -- Rotate which characters are "active" each day
    activeCharactersPerDay = 6,   -- How many recurring characters are active at once
    rotationIntervalMinutes = 48, -- Real minutes per "day" rotation (48 = 1 GTA day)

    -- Character data is in shared/characters.lua (SharedCharacters.pool)
    -- This allows dps-ainpcs to use the same characters
    -- Edit shared/characters.lua to add/modify characters
}

-- Personality data is also in shared/characters.lua (SharedCharacters.personalities)
-- Access via: SharedCharacters.GetPersonality("nervous")

-- ============================================================================
-- RANDOM NPC NAMES
-- ============================================================================

-- Names for NPC identification
Config.malefirstNames = {
    "John", "Michael", "David", "Luis", "Kyle", "Luke", "Shawn", "Tyrone",
    "Adam", "Arthur", "Steve", "Ricardo", "James", "Pablo", "Micah", "Walter",
    "Marcus", "Derek", "Brandon", "Kevin", "Eric", "Jason", "Tyler", "Justin",
    "Carlos", "Antonio", "Raymond", "Eugene", "Trevor", "Franklin", "Lamar",
    "Robert", "William", "Joseph", "Charles", "Thomas", "Daniel", "Matthew",
    "Anthony", "Donald", "Steven", "Andrew", "Kenneth", "George", "Edward"
}

Config.femalefirstNames = {
    "Emily", "Madison", "Abigail", "Chloe", "Hailey", "Ashley", "Samantha",
    "Jessica", "Avery", "Ella", "Grace", "Brooklyn", "Natalie", "Addison",
    "Harper", "Scarlett", "Savannah", "Victoria", "Lily", "Zoey", "Maria",
    "Nicole", "Amanda", "Rachel", "Stephanie", "Michelle", "Christina",
    "Tracey", "Denise", "Tanisha", "Tonya", "Patricia", "Jennifer", "Linda",
    "Elizabeth", "Barbara", "Susan", "Margaret", "Dorothy", "Lisa", "Karen"
}

Config.lastNames = {
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis",
    "Garcia", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
    "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "White",
    "Bell", "Thompson", "Robinson", "Clark", "Lewis", "Lee", "Walker",
    "Hall", "Allen", "Young", "King", "Wright", "Scott", "Green", "Baker",
    "De Santa", "Philips", "Clinton", "Townley", "Adams", "Nelson", "Hill",
    "Mitchell", "Roberts", "Carter", "Phillips", "Evans", "Turner", "Torres"
}

-- ============================================================================
-- STREET LIFE (DPS 2026-10-29, Damon's brief): corner crews, the City Pulse,
-- rough nights, road rage. Peds never spawn in the street (client/crews.lua).
-- ============================================================================

-- The City Pulse: how much fake crime the city needs right now. Recomputed every
-- intervalMin minutes from players online, police on duty, gang members online and
-- real incidents in the last 30 minutes (dps-pulse:incident). 1 = quiet city with
-- people in it, 0 = busy with real crime, or nobody online.
Config.pulse = {
    intervalMin    = 5,
    gangWeight     = 0.15,   -- each gang member online takes this much off the pulse
    incidentWeight = 0.10,   -- each real incident in the last 30 min takes this much off
    crowdAt        = 24,     -- above this many players, the city needs less filler
    crowdMult      = 0.7,
}

-- Rough nights: rolled once at dusk (clients report the game hour), odds in percent,
-- mult multiplies the pulse. Rough and wild nights weight crews towards Davis spots.
Config.heat = {
    duskHour = 20,
    odds = { quiet = 25, normal = 50, rough = 20, wild = 5 },
    mult = { quiet = 0.6, normal = 1.0, rough = 1.5, wild = 2.2 },
}

Config.crews = {
    spawnRange   = 150.0,
    despawnRange = 200.0,
    floor        = 0.2,     -- no crews at all under this effective pulse
    carryChance  = 60,      -- % of crew peds carrying contraband (random peds keep their own roll)
    copRange     = 15.0,    -- a cop this close makes them react
    react        = { walk = 30, flee = 10 }, -- % walk off / % bolt; the rest pocket their hands
    models = { 'g_m_y_ballaeast_01', 'g_m_y_ballaorig_01', 'g_m_y_famca_01', 'g_m_y_famfor_01', 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02',
               'g_m_y_korean_01', 'g_m_y_korlieut_01', 'g_m_y_salvagoon_01', 'g_m_y_salvagoon_02', 'a_m_y_stbla_01', 'a_m_y_stlat_01', 'a_m_m_hillbilly_01', 'a_m_m_hillbilly_02' },
    scenarios = { 'WORLD_HUMAN_DRUG_DEALER', 'WORLD_HUMAN_DRUG_DEALER_HARD', 'WORLD_HUMAN_HANG_OUT_STREET', 'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_LEANING' },
    -- davis = true: the Davis-side blocks the rough nights lean on. Coordinates are the
    -- block centre; the pavement snap places each ped. (approximate) = Damon's /spot wins.
    spots = {
        { label = 'Grove Street',                 coords = vector3(-120.0, -1620.0, 34.0), davis = true,  min = 2, max = 3, models = { 'g_m_y_famca_01', 'g_m_y_famfor_01', 'g_m_y_famdnf_01' } },
        { label = 'Davis',                        coords = vector3(89.0, -1940.0, 20.7),   davis = true,  min = 2, max = 3, models = { 'g_m_y_ballaeast_01', 'g_m_y_ballaorig_01', 'g_m_y_ballasout_01' } },
        { label = 'Rancho',                       coords = vector3(470.0, -1890.0, 25.0),  davis = true,  min = 2, max = 3, models = { 'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03' } },
        { label = 'El Burro Heights',             coords = vector3(1490.0, -2340.0, 55.0), davis = false, min = 2, max = 3 },
        { label = 'Little Seoul',                 coords = vector3(-700.0, -900.0, 19.0),  davis = false, min = 2, max = 3, models = { 'g_m_y_korean_01', 'g_m_y_korean_02', 'g_m_y_korlieut_01' } },
        { label = 'Chamberlain Hills',            coords = vector3(-175.0, -1571.0, 34.0), davis = true,  min = 2, max = 3 },
        { label = 'Strawberry',                   coords = vector3(245.0, -1735.0, 29.0),  davis = true,  min = 2, max = 3 },
        { label = 'La Mesa',                      coords = vector3(741.0, -1520.0, 27.0),  davis = false, min = 2, max = 3 },
        { label = 'Cypress Flats',                coords = vector3(835.0, -2135.0, 29.5),  davis = false, min = 2, max = 3 },
        { label = 'Under the La Mesa overpass',   coords = vector3(725.0, -1275.0, 25.0),  davis = false, min = 2, max = 2 },
        { label = 'Legion Square parking',        coords = vector3(215.0, -785.0, 31.0),   davis = false, min = 2, max = 2, nightOnly = true },
        { label = 'Behind the Vanilla Unicorn',   coords = vector3(140.0, -1270.0, 29.0),  davis = false, min = 2, max = 2 },
        { label = 'Sandy outskirts trailers',     coords = vector3(2700.0, 3400.0, 55.0),  davis = false, min = 2, max = 3, models = { 'a_m_m_hillbilly_01', 'a_m_m_hillbilly_02', 'a_m_y_hippy_01' } },
        { label = 'Stab City trailer park (approximate)', coords = vector3(60.0, 3700.0, 40.0), davis = false, min = 3, max = 4, models = { 'g_m_y_lost_01', 'g_m_y_lost_02', 'g_m_y_lost_03', 'a_m_m_hillbilly_02' } },
        { label = 'Paleto back lots (approximate)', coords = vector3(-200.0, 6260.0, 31.0), davis = false, min = 2, max = 2, models = { 'a_m_m_hillbilly_01', 'a_m_m_hillbilly_02' } },
    },
    -- Police tips: random, driven by the pulse, never clocked. At effective pulse 1 the
    -- average gap is meanMinAtFull minutes; never two inside minGapMin; none under floor.
    tips = {
        meanMinAtFull = 60, minGapMin = 20, floor = 0.2, priority = 2, type = 'disturbance',
        title = 'Suspicious activity reported',
        description = 'Caller reports a group loitering and dealing on the corner.',
    },
}

-- Road rage: bump an occupied NPC car and sometimes the driver snaps.
Config.roadRage = {
    enabled         = true,
    baseChance      = 8,        -- % per bump, times the night's heat, scaled by the pulse (floor 0.25)
    cooldownMs      = 600000,   -- one per player per ten minutes at most
    durationMs      = 90000,    -- he gives up after this
    breakOffM       = 200.0,    -- or once you are this far away
    bailDelayMs     = 3000,     -- you get out, he follows this much later
    armedChanceWild = 20,       -- % armed with a pistol, wild nights only
}

Config.dispatch.roadRage = {
    enabled = true, priority = 3, type = 'shooting',
    title = 'Road rage, shots fired',
    description = 'Caller reports an armed driver attacking a motorist after a collision.',
}

-- Vibe patrol (DPS 2026-10-30, Damon): emergency vehicles roll through with lights
-- and siren, purely for the feel of a living city ("I live in Chicago near a
-- hospital, I hear sirens at least 4x a day"). Each unit leaves from one of its
-- real stations, department-correct per our jobs canon: LSPD in the city, BCSO in
-- the county, LSFD ambulance from the hospitals, SAMS in the county, fire engines
-- from the fire houses. Pure ambience: nobody gets chased, nothing responds.
-- SASP has no model in the fleet yet; add a unit here when one lands.
Config.vibePatrol = {
    enabled       = true,
    meanMin       = 20,                -- average minutes between passes per player at full pulse
    minGapMin     = 8,                 -- never two passes inside this, per player
    baseBand      = { 180.0, 650.0 },  -- a unit rolls only if one of its stations is this far from you
    fallbackDist  = { 280.0, 380.0 },  -- no station in the band: LSPD passes through from a road this far out
    despawnDist   = 500.0,
    lifeSec       = 240,
    maxCopsOnDuty = 3,                 -- more real cops than this on duty = no fake patrols
    units = {
        { label = 'LSPD cruiser',   model = 'hvpolice3',       driver = 's_m_y_cop_01',       weight = 5, speed = 27.0,
          bases = { vec3(428.2, -984.3, 29.8),    -- Mission Row
                    vec3(360.9, -1584.7, 29.3),   -- Davis
                    vec3(638.2, 1.7, 82.8),       -- Vinewood
                    vec3(826.4, -1289.9, 28.2),   -- La Mesa
                    vec3(-1108.4, -845.3, 19.3) } }, -- Vespucci
        { label = 'BCSO sheriff',   model = 'sheriff',         driver = 's_m_y_sheriff_01',   weight = 3, speed = 26.0,
          bases = { vec3(1853.1, 3686.6, 34.3),   -- Sandy Shores SO
                    vec3(-443.3, 6015.6, 31.7) } },  -- Paleto Bay SO
        { label = 'LSFD ambulance', model = 'hvfdambulance',   driver = 's_m_m_paramedic_01', weight = 3, speed = 24.0,
          bases = { vec3(294.8, -574.1, 43.2),    -- Pillbox bay
                    vec3(-449.7, -340.8, 34.5) } },  -- Mount Zonah
        { label = 'SAMS ambulance', model = 'hvsamsambulance', driver = 's_m_m_paramedic_01', weight = 2, speed = 24.0,
          bases = { vec3(1839.6, 3672.9, 34.3),   -- Sandy medical
                    vec3(-247.8, 6331.1, 32.4) } },  -- Paleto care centre
        { label = 'Fire engine',    model = 'hvfiretruk',      driver = 's_m_y_fireman_01',   weight = 1, speed = 20.0,
          bases = { vec3(199.5, -1643.4, 28.8),   -- Davis FD
                    vec3(1193.5, -1464.6, 34.9),  -- El Burro FD
                    vec3(-635.5, -120.6, 38.0),   -- Rockford FD
                    vec3(1690.5, 3585.3, 35.6),   -- Sandy FD
                    vec3(-381.1, 6120.6, 31.5) } },  -- Paleto FD
    },
}
