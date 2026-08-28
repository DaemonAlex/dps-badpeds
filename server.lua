-- ============================================================================
-- FRAMEWORK SHIM (qbx_core native, no qb-core resource required)
-- ============================================================================

local function GetPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

-- Notify a client via ox_lib (maps qb-style types to ox_lib types)
local function NotifyClient(src, msg, nType)
    local t = nType
    if t == 'primary' or t == nil then t = 'inform' end
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = t })
end

local activeInteractions = {}
local npcInventories = {}
local npcNames = {}
local npcIllegal = {}
local npcLocks = {}
local npcModels = {}         -- Store NPC model hashes
local npcCharacterData = {}  -- Store recurring character data for NPCs

-- Cache for item list from inventory system
local cachedItemList = nil
local filteredItemPool = nil
local legalPool = nil
local illegalPool = nil
local illegalByCategory = nil

-- ============================================================================
-- JAIL STATUS CACHE (Performance optimization for high-pop servers)
-- ============================================================================
-- Instead of querying the database every time we need to check if a character
-- is in jail, we maintain an in-memory cache that refreshes periodically.
-- This reduces database load from potentially hundreds of queries to 1 per minute.

local jailStatusCache = {}  -- { ["Firstname_Lastname"] = true } for jailed characters
local lastCacheRefresh = 0  -- GetGameTimer() value of last refresh

-- Refresh the jail status cache from database (async)
local function refreshJailCache()
    local now = GetGameTimer()
    local cacheTTL = (Config.jailStatusCache and Config.jailStatusCache.refreshInterval) or 60000

    -- Only refresh if cache has expired
    if now - lastCacheRefresh < cacheTTL then return end

    -- Optimistically bump the timestamp so concurrent callers don't all query
    lastCacheRefresh = now

    local results = MySQL.query.await([[
        SELECT npc_firstname, npc_lastname, release_at
        FROM npc_jail_records
        WHERE released = 0 AND release_at > NOW()
    ]])

    -- Clear and rebuild cache
    jailStatusCache = {}
    for _, row in ipairs(results or {}) do
        local key = row.npc_firstname .. "_" .. row.npc_lastname
        jailStatusCache[key] = true
    end
end

-- Check if character is in jail using cache (fast, no DB hit unless expired)
local function isCharacterJailedCached(firstname, lastname)
    refreshJailCache() -- Only hits DB if cache expired
    local key = firstname .. "_" .. lastname
    return jailStatusCache[key] == true
end

-- Immediately update cache when we arrest someone (don't wait for refresh)
local function addToJailCache(firstname, lastname)
    local key = firstname .. "_" .. lastname
    jailStatusCache[key] = true
end

-- Remove from cache when released (called by release system if implemented)
local function removeFromJailCache(firstname, lastname)
    local key = firstname .. "_" .. lastname
    jailStatusCache[key] = nil
end

-- ============================================================================
-- JAIL SYSTEM FUNCTIONS
-- ============================================================================

-- Calculate jail time based on items found
local function calculateJailTime(inventory)
    if not inventory then return Config.jailSystem.defaultJailHours or 24 end

    local baseTime = Config.jailSystem.defaultJailHours or 24
    local bonusTime = 0

    for _, item in ipairs(inventory) do
        if not item.legal then
            local itemName = item.item:lower()
            -- Weapons add more time
            if itemName:find("weapon_") then
                bonusTime = bonusTime + (Config.jailSystem.weaponBonus or 12)
            -- Large drug quantities
            elseif itemName:find("brick") then
                bonusTime = bonusTime + (Config.jailSystem.drugBrickBonus or 8)
            -- Regular drugs
            elseif itemName:find("baggy") or itemName:find("joint") or itemName:find("coke") or itemName:find("meth") then
                bonusTime = bonusTime + (Config.jailSystem.drugBonus or 4)
            -- Crime tools
            elseif itemName:find("lockpick") or itemName:find("thermite") or itemName:find("hack") then
                bonusTime = bonusTime + (Config.jailSystem.crimeToolBonus or 6)
            end
        end
    end

    local maxTime = Config.jailSystem.maxJailHours or 72
    return math.min(baseTime + bonusTime, maxTime)
end

-- Record an arrest in the database
-- Street is resolved on the CLIENT (server-side street natives are unreliable)
-- and passed in; we fall back to 'Unknown' if it wasn't provided.
local function recordArrest(src, netId, jailHours, gaveIntel, intelData, street)
    local Player = GetPlayer(src)
    if not Player then return false end

    local npcName = npcNames[netId]
    local npcModel = npcModels[netId] or 'unknown'
    local inventory = npcInventories[netId]

    if not npcName then return false end

    local playerPed = GetPlayerPed(src)
    local coords = GetEntityCoords(playerPed)
    local streetName = street
    if not streetName or streetName == '' then streetName = 'Unknown' end

    -- Build charges from inventory
    local charges = {}
    if inventory then
        for _, item in ipairs(inventory) do
            if not item.legal then
                table.insert(charges, {
                    item = item.item,
                    label = item.label,
                    quantity = item.qty
                })
            end
        end
    end

    -- Calculate release time (game hours to real minutes: 1 game hour = 2 real minutes by default)
    local realMinutes = jailHours * (Config.jailSystem.gameHourToRealMinutes or 2)

    local insertQuery = [[
        INSERT INTO npc_jail_records
        (npc_model, npc_firstname, npc_lastname, npc_gender, arrested_by, arrested_by_name,
         arrest_coords, arrest_street, charges, jail_time_hours, release_at, gave_intel, intel_data)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE), ?, ?)
    ]]

    local citizenId = Player.PlayerData.citizenid
    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local coordsJson = json.encode({x = coords.x, y = coords.y, z = coords.z})
    local chargesJson = json.encode(charges)
    local intelJson = intelData and json.encode(intelData) or nil

    MySQL.insert.await(insertQuery, {
        npcModel,
        npcName.firstname,
        npcName.lastname,
        npcName.gender,
        citizenId,
        officerName,
        coordsJson,
        streetName,
        chargesJson,
        jailHours,
        realMinutes,
        gaveIntel and 1 or 0,
        intelJson
    })

    -- Immediately update jail cache (don't wait for next refresh cycle)
    addToJailCache(npcName.firstname, npcName.lastname)

    -- Notify dps-ainpcs immediately so they can remove the NPC from active spawns
    TriggerEvent('dps-ainpcs:characterArrested', npcName.firstname, npcName.lastname, jailHours)

    return true
end

-- Check if an NPC identity is currently in jail (async)
local function isNpcInJail(firstname, lastname)
    local result = MySQL.query.await([[
        SELECT id, release_at, TIMESTAMPDIFF(MINUTE, NOW(), release_at) as minutes_remaining
        FROM npc_jail_records
        WHERE npc_firstname = ? AND npc_lastname = ?
        AND released = 0
        AND release_at > NOW()
        ORDER BY arrested_at DESC
        LIMIT 1
    ]], {firstname, lastname})

    if result and result[1] then
        return true, result[1].minutes_remaining
    end
    return false, 0
end

-- Get arrest history for an NPC (async)
local function getNpcArrestHistory(firstname, lastname)
    local result = MySQL.query.await([[
        SELECT * FROM npc_jail_records
        WHERE npc_firstname = ? AND npc_lastname = ?
        ORDER BY arrested_at DESC
        LIMIT 5
    ]], {firstname, lastname})

    return result or {}
end

-- Record intel given by NPC
local function recordIntel(src, npcName, intelType, intelContent, locationHint, sourceType)
    local Player = GetPlayer(src)
    if not Player then return false end

    local citizenId = Player.PlayerData.citizenid
    local fullName = npcName.firstname .. ' ' .. npcName.lastname

    MySQL.insert.await([[
        INSERT INTO npc_intel_reports
        (source_type, source_npc_name, receiving_officer, intel_type, intel_content, location_hint, reliability)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        sourceType or 'arrest',
        fullName,
        citizenId,
        intelType,
        intelContent,
        locationHint,
        3 -- Default reliability
    })

    return true
end

-- Recruit NPC as informant
local function recruitInformant(src, netId)
    local Player = GetPlayer(src)
    if not Player then return false end

    local npcName = npcNames[netId]
    local npcModel = npcModels[netId] or 'unknown'

    if not npcName then return false end

    local citizenId = Player.PlayerData.citizenid
    local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

    -- Check if already an informant (async)
    local existing = MySQL.query.await([[
        SELECT id FROM npc_informants
        WHERE npc_firstname = ? AND npc_lastname = ? AND active = 1
    ]], {npcName.firstname, npcName.lastname})

    if existing and existing[1] then
        return false, 'already_informant'
    end

    MySQL.insert.await([[
        INSERT INTO npc_informants
        (npc_model, npc_firstname, npc_lastname, handler_citizenid, handler_name, trust_level)
        VALUES (?, ?, ?, ?, ?, 1)
    ]], {
        npcModel,
        npcName.firstname,
        npcName.lastname,
        citizenId,
        officerName
    })

    -- Also mark in jail record if exists
    MySQL.update.await([[
        UPDATE npc_jail_records SET is_informant = 1, informant_handler = ?
        WHERE npc_firstname = ? AND npc_lastname = ? AND released = 0
        ORDER BY arrested_at DESC LIMIT 1
    ]], {citizenId, npcName.firstname, npcName.lastname})

    return true
end

-- Generate intel content based on type
local function generateIntelContent(intelType)
    local intelTemplates = Config.intelTemplates or {
        drugs = {
            "There's a guy who hangs around {location}, he's been moving weight lately.",
            "Check the parking lot behind {location}, deals go down there every night.",
            "I heard {name} has been cooking in a house near {location}.",
        },
        weapons = {
            "There's an arms deal happening near {location} soon.",
            "Check the trunk of cars parked at {location}, lots of heat moving through there.",
            "Some guys have been stockpiling at a warehouse near {location}.",
        },
        gang = {
            "The {gang} have been recruiting near {location}.",
            "There's beef brewing between crews at {location}.",
            "Watch {location}, something big is being planned.",
        }
    }

    local templates = intelTemplates[intelType] or intelTemplates.drugs
    local template = templates[math.random(#templates)]

    -- Replace placeholders
    local locations = Config.intelLocations or {"Grove Street", "Mirror Park", "Vinewood", "Del Perro", "Vespucci", "La Mesa", "Strawberry", "Davis"}
    local names = {"Marcus", "DeShawn", "Tyrell", "Carlos", "Jimmy", "Big Mike", "Little Ray"}
    local gangs = {"Ballas", "Vagos", "Families", "Marabunta"}

    template = template:gsub("{location}", locations[math.random(#locations)])
    template = template:gsub("{name}", names[math.random(#names)])
    template = template:gsub("{gang}", gangs[math.random(#gangs)])

    return template
end

-- ============================================================================
-- END JAIL SYSTEM FUNCTIONS
-- ============================================================================

-- Build lookup table for illegal items (faster checks)
local illegalLookup = {}
local excludedLookup = {}

local function buildLookupTables()
    for _, item in ipairs(Config.illegalItems or {}) do
        illegalLookup[item] = true
    end
    for _, item in ipairs(Config.excludedItems or {}) do
        excludedLookup[item] = true
    end
end

-- Check if an item is illegal
local function isItemIllegal(itemName)
    return illegalLookup[itemName] == true
end

-- Count table entries
function tableCount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Get all items from the inventory system
local function getItemListFromInventory()
    if cachedItemList then return cachedItemList end

    local items = nil

    if Config.inventory == 'qs-inventory' then
        items = exports['qs-inventory']:GetItemList()
    else
        -- ox_inventory (default for this stack)
        items = exports.ox_inventory:Items()
    end

    if items and next(items) then
        cachedItemList = items
    else
        print('[dps-badpeds] WARNING: Could not load items from inventory, using fallback')
        cachedItemList = {}
    end

    return cachedItemList
end

-- Categorise an illegal item so we can bias contraband by a character's specialty
local function categorizeIllegal(itemName)
    local n = itemName:lower()
    if n:find("weapon_") or n:find("ammo") then return 'weapons' end
    if n:find("lockpick") or n:find("thermite") or n:find("hack") or n:find("vpn")
        or n:find("usb") or n:find("laptop") or n:find("crypto") or n:find("ziptie")
        or n:find("handcuff") or n:find("electronickit") then return 'crimetool' end
    if n:find("gold") or n:find("diamond") or n:find("rolex") or n:find("jewel")
        or n:find("chain") or n:find("bracelet") or n:find("necklace") or n:find("stolen")
        or n:find("marked") or n:find("moneybag") or n:find("fake") or n:find("dirty_money") then return 'theft' end
    return 'drugs'
end

-- Map a character specialty to a contraband category
local specialtyCategory = {
    drugs = 'drugs',
    weapons = 'weapons',
    theft = 'theft',
    gang = 'weapons',
    petty = 'crimetool',
    informant = nil,
}

-- Build filtered item pool (excludes job items, seeds, etc.) and split legal/illegal
local function getFilteredItemPool()
    if filteredItemPool then return filteredItemPool end

    local allItems = getItemListFromInventory()
    filteredItemPool = {}

    for itemName, itemData in pairs(allItems) do
        -- Skip excluded items
        if not excludedLookup[itemName] then
            -- Skip items without a label or with certain types
            local label = itemData.label or itemData.name or itemName
            local itemType = itemData.type

            -- qs-inventory item defs carry a `type` field; honor it when present.
            -- ox_inventory (this stack's default) does NOT — it keys items by name and
            -- derives weapon status from the name prefix. Without this branch the pool
            -- comes back empty on ox and every NPC falls back to Config.fallbackItems,
            -- silently defeating the specialty/contraband generation below.
            local includeItem, isWeapon
            if itemType then
                includeItem = (itemType == 'item' or itemType == 'weapon')
                isWeapon = (itemType == 'weapon')
            else
                isWeapon = itemName:lower():find('^weapon_') ~= nil
                includeItem = true
            end

            if includeItem then
                table.insert(filteredItemPool, {
                    item = itemName,
                    label = label,
                    isWeapon = isWeapon,
                    weight = itemData.weight or 0
                })
            end
        end
    end

    -- If pool is empty, use fallback
    if #filteredItemPool == 0 and Config.fallbackItems then
        filteredItemPool = Config.fallbackItems
        print('[dps-badpeds] Using fallback item list')
    end

    -- Split into legal / illegal sub-pools for illegalChance-based generation
    legalPool = {}
    illegalPool = {}
    illegalByCategory = { drugs = {}, weapons = {}, theft = {}, crimetool = {} }

    for _, entry in ipairs(filteredItemPool) do
        if isItemIllegal(entry.item) then
            table.insert(illegalPool, entry)
            local cat = categorizeIllegal(entry.item)
            if illegalByCategory[cat] then
                table.insert(illegalByCategory[cat], entry)
            end
        else
            table.insert(legalPool, entry)
        end
    end

    return filteredItemPool
end

-- Generate random inventory for an NPC, biased by the character's illegalChance
-- and specialty (falls back to sensible defaults for random pedestrians).
local function generateNpcInventory(netId)
    getFilteredItemPool()
    if (not legalPool or #legalPool == 0) and (not illegalPool or #illegalPool == 0) then
        return {}
    end

    local char = netId and npcCharacterData[netId] or nil
    local illegalChance = (char and char.illegalChance) or 40
    local prefCat = char and specialtyCategory[char.specialty] or nil

    local inventory = {}
    local itemCount = math.random(Config.npcItemCount.min or 3, Config.npcItemCount.max or 6)

    for _ = 1, itemCount do
        local chosen
        local pickIllegal = (#illegalPool > 0) and (math.random(100) <= illegalChance)

        if pickIllegal then
            -- Prefer the character's specialty category most of the time
            local catPool = prefCat and illegalByCategory[prefCat]
            if catPool and #catPool > 0 and math.random(100) <= 70 then
                chosen = catPool[math.random(#catPool)]
            else
                chosen = illegalPool[math.random(#illegalPool)]
            end
        elseif #legalPool > 0 then
            chosen = legalPool[math.random(#legalPool)]
        elseif #illegalPool > 0 then
            chosen = illegalPool[math.random(#illegalPool)]
        end

        if chosen then
            local quantity = 1
            if not chosen.isWeapon then
                quantity = math.random(Config.itemQuantity.min or 1, Config.itemQuantity.max or 5)
            end

            table.insert(inventory, {
                item = chosen.item,
                label = chosen.label,
                qty = quantity,
                legal = not isItemIllegal(chosen.item)
            })
        end
    end

    return inventory
end

local function validatePedNetId(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity then return false end
    if not DoesEntityExist(entity) then return false end
    if IsPedAPlayer(entity) then return false end
    return true
end

-- Distance check: returns true if player is within range of NPC
local function isPlayerNearNpc(src, netId, maxDistance)
    maxDistance = maxDistance or 5.0
    local playerPed = GetPlayerPed(src)
    if not playerPed or playerPed == 0 then return false end

    local npcEntity = NetworkGetEntityFromNetworkId(netId)
    if not npcEntity or npcEntity == 0 then return false end

    local playerCoords = GetEntityCoords(playerPed)
    local npcCoords = GetEntityCoords(npcEntity)
    local dist = #(playerCoords - npcCoords)

    return dist <= maxDistance
end

-- Is the source a police officer?
local function isPolice(src)
    local Player = GetPlayer(src)
    return Player and Player.PlayerData.job.name == "police", Player
end

-- ============================================================================
-- INVENTORY HELPERS (stun gun issue/removal + evidence stash)
-- ============================================================================

local function giveStunGun(src, Player)
    if Config.inventory == 'qs-inventory' then
        exports['qs-inventory']:AddItem(src, 'weapon_stungun', 1)
    else
        exports.ox_inventory:AddItem(src, 'weapon_stungun', 1)
    end
end

local function removeStunGun(src, Player)
    if Config.inventory == 'qs-inventory' then
        exports['qs-inventory']:RemoveItem(src, 'weapon_stungun', 1)
    else
        exports.ox_inventory:RemoveItem(src, 'weapon_stungun', 1)
    end
end

local evidenceStashRegistered = false
local function ensureEvidenceStash()
    if evidenceStashRegistered then return end
    if Config.SeizeMode ~= 'evidence' then return end
    local s = Config.evidenceStash or {}
    exports.ox_inventory:RegisterStash(s.id or 'evidence-badpeds', s.label or 'Seized Evidence', s.slots or 100, s.maxWeight or 1000000)
    evidenceStashRegistered = true
end

-- ============================================================================
-- RECURRING CHARACTER ROTATION SYSTEM
-- ============================================================================

local activeCharactersToday = nil
local lastRotationDay = nil

-- Get current game day for rotation (changes every 48 real minutes by default)
local function getGameDay()
    local hours = GetGameTimer() / 1000 / 60 -- Real minutes since server start
    local gameDay = math.floor(hours / 48) -- Each "day" is 48 real minutes
    return gameDay
end

-- Get today's active recurring characters (uses SharedCharacters from shared/characters.lua)
local function getActiveCharacters()
    if not Config.recurringCharacters or not Config.recurringCharacters.enabled then
        return {}
    end

    local today = getGameDay()

    -- Check if we need to rotate
    if Config.recurringCharacters.rotationEnabled and (not activeCharactersToday or lastRotationDay ~= today) then
        lastRotationDay = today
        activeCharactersToday = {}

        -- Use SharedCharacters pool (loaded from shared/characters.lua)
        local allCharacters = SharedCharacters and SharedCharacters.pool or {}
        local numActive = Config.recurringCharacters.activeCharactersPerDay or 6

        -- Use day as seed for consistent rotation across server
        math.randomseed(today * 12345)

        -- Shuffle and pick active characters
        local shuffled = {}
        for i, char in ipairs(allCharacters) do
            shuffled[i] = char
        end

        for i = #shuffled, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

        for i = 1, math.min(numActive, #shuffled) do
            table.insert(activeCharactersToday, shuffled[i])
        end

        -- Reset random seed
        math.randomseed(os.time())

        -- Sync with dps-ainpcs if enabled
        if Config.recurringCharacters.shareWithAINpcs then
            local resourceState = GetResourceState('dps-ainpcs')
            if resourceState == 'started' then
                TriggerEvent('dps-ainpcs:server:setActiveCharacters', activeCharactersToday)
            end
        end
    end

    return activeCharactersToday or (SharedCharacters and SharedCharacters.pool) or {}
end

-- Check if a character is currently in jail (unavailable) - uses cache for performance
local function isCharacterInJail(firstname, lastname)
    if not Config.jailSystem or not Config.jailSystem.enabled then
        return false
    end
    return isCharacterJailedCached(firstname, lastname)
end

-- Check if this NPC should be a recurring character
local function getRecurringCharacter(gender)
    if not Config.recurringCharacters or not Config.recurringCharacters.enabled then
        return nil
    end

    -- Roll for recurring character
    if math.random(100) > (Config.recurringCharacters.spawnChance or 25) then
        return nil
    end

    -- Get today's active characters
    local activeChars = getActiveCharacters()

    -- Filter by gender and availability (not in jail)
    local validCharacters = {}
    for _, char in ipairs(activeChars) do
        if char.gender == gender then
            if not isCharacterInJail(char.firstname, char.lastname) then
                table.insert(validCharacters, char)
            end
        end
    end

    if #validCharacters == 0 then return nil end

    return validCharacters[math.random(#validCharacters)]
end

-- Assign a persistent identity (and possibly a recurring character) to an NPC.
-- Called at interaction start so contraband generation and behaviour can use it.
local function assignNpcIdentity(netId, gender, modelHash)
    if modelHash then
        npcModels[netId] = tostring(modelHash)
    end

    if npcNames[netId] then return end

    local recurringChar = getRecurringCharacter(gender)
    if recurringChar then
        npcNames[netId] = {
            firstname = recurringChar.firstname,
            lastname = recurringChar.lastname,
            gender = recurringChar.gender
        }
        npcCharacterData[netId] = recurringChar
    else
        local firstName
        local lastName = Config.lastNames[math.random(#Config.lastNames)]
        if gender == "MALE" then
            firstName = Config.malefirstNames[math.random(#Config.malefirstNames)]
        else
            firstName = Config.femalefirstNames[math.random(#Config.femalefirstNames)]
        end
        npcNames[netId] = { firstname = firstName, lastname = lastName, gender = gender }
    end
end

-- Build a behaviour profile (flee / intel / informant chances) from the NPC's
-- personality. Random pedestrians fall back to sensible defaults.
local function getBehaviorProfile(netId)
    local char = npcCharacterData[netId]
    local p = char and SharedCharacters and SharedCharacters.GetPersonality and SharedCharacters.GetPersonality(char.personality) or nil
    return {
        fleeChance = (p and p.fleeChance) or 50,
        intelChance = (p and p.intelChance) or 70,
        informantChance = (p and p.informantChance) or 40,
        canGiveIntel = char and char.canGiveIntel, -- nil for random peds (treated as allowed)
    }
end

-- Export for dps-ainpcs to check character availability (uses cache for performance)
exports('IsCharacterAvailable', function(firstname, lastname)
    return not isCharacterJailedCached(firstname, lastname)
end)

-- Export for dps-ainpcs to get active characters
exports('GetActiveCharacters', function()
    return getActiveCharacters()
end)

-- Export for dps-ainpcs to notify when their NPC was arrested elsewhere
exports('NotifyCharacterArrested', function(firstname, lastname)
    addToJailCache(firstname, lastname)
end)

-- Export to get the shared character pool
exports('GetSharedCharacters', function()
    return SharedCharacters and SharedCharacters.pool or {}
end)

-- Export to get a specific character by ID
exports('GetCharacterById', function(characterId)
    return SharedCharacters and SharedCharacters.GetById(characterId) or nil
end)

-- Export to get characters by area (for location-based spawning)
exports('GetCharactersByArea', function(area)
    return SharedCharacters and SharedCharacters.GetByArea(area) or {}
end)

-- Export to force cache refresh (for admin commands)
exports('RefreshJailCache', function()
    lastCacheRefresh = 0  -- Reset timer to force refresh
    refreshJailCache()
    return true
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    buildLookupTables()
    ensureEvidenceStash()

    -- Log shared character pool status
    if SharedCharacters and SharedCharacters.pool then
        print('[dps-badpeds] Loaded ' .. #SharedCharacters.pool .. ' shared characters')
    else
        print('[dps-badpeds] WARNING: SharedCharacters pool not loaded!')
    end

    -- Initialize jail cache on startup
    Citizen.SetTimeout(1000, function()
        refreshJailCache()
    end)

    -- Delay item loading to ensure inventory resource is ready
    Citizen.SetTimeout(2000, function()
        getFilteredItemPool()
    end)
end)

-- Server-side pending intel offers (src -> { netId, type, content }) so the
-- accepted deal cannot be forged by the client, and one-shot flags.
pendingIntelOffers = pendingIntelOffers or {}
stunIssued = stunIssued or {}
intelAttempted = intelAttempted or {}
intelGiven = intelGiven or {}      -- src -> { netId, data } actually recorded

-- Clean up any state held by a player who disconnects mid-interaction
AddEventHandler('playerDropped', function()
    local src = source
    local held = activeInteractions[src]
    if held then
        activeInteractions[src] = nil
        -- Drop the per-NPC state as well. FiveM recycles network ids, so leaving
        -- these populated made a brand-new pedestrian inherit the old NPC's
        -- identity, contraband inventory and illegal flag.
        npcInventories[held] = nil
        npcNames[held] = nil
        npcIllegal[held] = nil
        npcModels[held] = nil
        npcCharacterData[held] = nil
    end
    for netId, holder in pairs(npcLocks) do
        if holder == src then
            npcLocks[netId] = nil
        end
    end
    pendingIntelOffers[src] = nil
    stunIssued[src] = nil
    intelAttempted[src] = nil
    intelGiven[src] = nil
end)

-- ============================================================================
-- INTERACTION EVENTS
-- ============================================================================

RegisterNetEvent('pedInteraction:request')
AddEventHandler('pedInteraction:request', function(netId, gender, modelHash)
    local src = source

    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end

    local police, Player = isPolice(src)
    if not Player or not police then return end

    local prev = activeInteractions[src]
    if prev then
        -- Release the PREVIOUS ped's lock and state here; the client cannot be
        -- relied on to send exitclearance for it (it was being handed a server
        -- entity handle, and activeInteractions was overwritten before it replied).
        if npcLocks[prev] == src then npcLocks[prev] = nil end
        npcInventories[prev] = nil
        npcNames[prev] = nil
        npcIllegal[prev] = nil
        npcModels[prev] = nil
        npcCharacterData[prev] = nil
        pendingIntelOffers[src] = nil
        stunIssued[src] = nil
        intelGiven[src] = nil
        TriggerClientEvent('npc:closeMenu', src, { netId = prev })
    end

    if npcLocks[netId] and npcLocks[netId] ~= src then
        NotifyClient(src, 'This pedestrian is already being interacted with.', 'error')
        return
    end

    activeInteractions[src] = netId
    npcLocks[netId] = src

    -- Assign identity + recurring character up front so frisk contraband and
    -- flee/intel behaviour all key off the same character.
    assignNpcIdentity(netId, gender, modelHash)

    TriggerClientEvent('pedInteraction:approved', src, netId, getBehaviorProfile(netId))
end)

RegisterNetEvent('addinventory')
AddEventHandler('addinventory', function(netId)
    local src = source

    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end

    local police = isPolice(src)
    if not police then return end
    if activeInteractions[src] ~= netId then return end

    -- Generate inventory if not exists
    if not npcInventories[netId] then
        npcInventories[netId] = generateNpcInventory(netId)
    end

    local npcItems = {}
    local illegal = false

    for idx, item in ipairs(npcInventories[netId]) do
        if item.qty > 0 then
            local legalTag = item.legal and "" or " ~r~(illegal)~s~"
            table.insert(npcItems, {
                header = (item.label or item.item) .. " x" .. item.qty .. legalTag,
                txt = "Click to seize this item",
                icon = item.legal and "fas fa-box" or "fas fa-exclamation-triangle",
                params = {
                    event = "npc:seizeItem",
                    args = { netId = netId, itemIndex = idx }
                }
            })
        end
        if item.legal == false then illegal = true end
    end

    npcIllegal[netId] = illegal
    TriggerClientEvent('addmenu', src, illegal, npcItems, netId)
end)

RegisterNetEvent("GetPedInfo")
AddEventHandler("GetPedInfo", function(netId, ped, mugshot, mugshotname, gender, modelHash)
    local src = source

    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end

    local police = isPolice(src)
    if not police then return end
    if activeInteractions[src] ~= netId then return end

    -- Identity is normally assigned at interaction start; ensure it exists here too.
    assignNpcIdentity(netId, gender, modelHash)

    local firstname = npcNames[netId].firstname
    local lastname = npcNames[netId].lastname
    local storedGender = npcNames[netId].gender

    -- Check arrest history if jail system enabled
    local arrestHistory = {}
    local inJail = false
    local minutesRemaining = 0

    if Config.jailSystem and Config.jailSystem.enabled then
        -- Route the "in jail?" boolean through the in-memory cache (no per-lookup DB hit)
        inJail = isCharacterJailedCached(firstname, lastname)
        arrestHistory = getNpcArrestHistory(firstname, lastname)
    end

    -- Get recurring character data if applicable
    local characterData = npcCharacterData[netId]
    local isKnownCriminal = characterData ~= nil

    TriggerClientEvent('addname', src, netId, mugshot, mugshotname, true, firstname, lastname, storedGender, arrestHistory, inJail, minutesRemaining, isKnownCriminal, characterData)
end)

-- ============================================================================
-- SEIZURE: route contraband to an evidence stash or destroy + log it.
-- NEVER give the item to the seizing officer (NPC inventories are random
-- high-value items, so that would be an infinite farming exploit).
-- ============================================================================
RegisterNetEvent('npc:seizeItem:server')
AddEventHandler('npc:seizeItem:server', function(netId, itemIndex)
    local src = source

    local police, Player = isPolice(src)
    if not Player or not police then return end
    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end
    if activeInteractions[src] ~= netId then return end

    local inventory = npcInventories[netId]
    if not inventory or not inventory[itemIndex] then return end

    local item = inventory[itemIndex]
    if item.qty <= 0 then
        NotifyClient(src, 'This item has already been seized.', 'error')
        return
    end

    local itemName = item.item
    local quantity = item.qty
    local seized = false

    if Config.SeizeMode == 'evidence' then
        ensureEvidenceStash()
        local ok = exports.ox_inventory:AddItem(Config.evidenceStash.id, itemName, quantity)
        seized = ok and ok ~= false
    else
        -- 'destroy' mode: item is simply removed from the NPC and logged.
        seized = true
    end

    if seized then
        -- Remove from NPC inventory
        npcInventories[netId][itemIndex].qty = 0

        -- Audit log (who seized what, and where it went)
        local officerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        print(('[dps-badpeds] SEIZURE: %s (%s) seized %dx %s -> %s'):format(
            officerName, Player.PlayerData.citizenid, quantity, itemName, Config.SeizeMode))

        local dest = (Config.SeizeMode == 'evidence') and ' (evidence)' or ' (destroyed)'
        NotifyClient(src, 'Seized ' .. quantity .. 'x ' .. (item.label or itemName) .. dest, 'success')
        TriggerClientEvent('npc:refreshInventory', src, netId)
    else
        NotifyClient(src, 'Failed to seize item - evidence locker full?', 'error')
    end
end)

-- Officer receives a stun gun for a foot pursuit (only when contraband present)
RegisterNetEvent('additem:stungun')
AddEventHandler('additem:stungun', function(netId)
    local src = source

    local police, Player = isPolice(src)
    if not Player or not police then return end
    if not isPlayerNearNpc(src, netId, 10.0) then return end
    if activeInteractions[src] ~= netId then return end

    -- One stun gun per interaction: this was unbounded, so an officer could spam
    -- the event and farm weapon_stungun items into their inventory.
    if npcIllegal[netId] and stunIssued[src] ~= netId then
        stunIssued[src] = netId
        giveStunGun(src, Player)
    end
end)

RegisterNetEvent('arrestnpc')
AddEventHandler('arrestnpc', function(netId, gaveIntel, intelData, street)
    local src = source

    local police, Player = isPolice(src)
    if not Player or not police then return end
    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 10.0) then return end
    if activeInteractions[src] ~= netId then return end

    if npcIllegal[netId] then
        removeStunGun(src, Player)
    end

    -- Record arrest in database if jail system enabled
    if Config.jailSystem and Config.jailSystem.enabled then
        local jailHours = calculateJailTime(npcInventories[netId])

        -- Trust the SERVER's record of whether intel was actually exchanged, and
        -- the content we generated - the client previously supplied both, so the
        -- sentence reduction and the stored jail record were forgeable.
        local given = intelGiven[src]
        local realIntel = (given ~= nil and given.netId == netId)
        local realIntelData = realIntel and given.data or nil
        intelGiven[src] = nil

        -- Intel reduces the sentence
        if realIntel and Config.jailSystem.intelReduction then
            jailHours = math.max(1, math.floor(jailHours * Config.jailSystem.intelReduction))
        end

        -- Clamp the free-text street label before it reaches the DB
        if type(street) ~= 'string' then
            street = nil
        elseif #street > 64 then
            street = street:sub(1, 64)
        end

        local gaveIntel = realIntel
        recordArrest(src, netId, jailHours, realIntel, realIntelData, street)

        -- Notify about jail time
        local npcName = npcNames[netId]
        if npcName then
            local realMinutes = jailHours * (Config.jailSystem.gameHourToRealMinutes or 2)
            local suffix = gaveIntel and ' [intel deal: reduced]' or ''
            NotifyClient(src,
                npcName.firstname .. ' ' .. npcName.lastname .. ' sentenced to ' .. jailHours .. ' hours (~' .. realMinutes .. ' real minutes)' .. suffix,
                'success')
        end
    end

    -- Cleanup
    activeInteractions[src] = nil
    npcLocks[netId] = nil
    npcInventories[netId] = nil
    npcNames[netId] = nil
    npcIllegal[netId] = nil
    npcModels[netId] = nil
    npcCharacterData[netId] = nil
    TriggerClientEvent('deletenpc', src, netId)
end)

-- ============================================================================
-- INTEL TRADING EVENTS
-- ============================================================================

-- NPC offers intel to avoid arrest (or reduce sentence)
RegisterNetEvent('npc:requestIntelOffer')
AddEventHandler('npc:requestIntelOffer', function(netId)
    local src = source

    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end
    local police = isPolice(src)
    if not police then return end
    if activeInteractions[src] ~= netId then return end

    local npcName = npcNames[netId]
    local inventory = npcInventories[netId]

    if not npcName or not npcIllegal[netId] then return end

    -- Determine intel type based on what they have
    local intelType = 'drugs' -- default
    if inventory then
        for _, item in ipairs(inventory) do
            if not item.legal then
                local itemName = item.item:lower()
                if itemName:find("weapon_") then
                    intelType = 'weapons'
                    break
                end
            end
        end
    end

    -- Chance NPC has useful intel is driven by personality (intelChance);
    -- characters flagged canGiveIntel = false never talk.
    local char = npcCharacterData[netId]
    local hasIntel
    -- One roll per player+ped: without this the client could re-invoke until the
    -- personality chance came up, making intelChance meaningless.
    local rollKey = tostring(src) .. ':' .. tostring(netId)
    if intelAttempted[src] == rollKey then
        hasIntel = pendingIntelOffers[src] ~= nil and pendingIntelOffers[src].netId == netId
    elseif char and char.canGiveIntel == false then
        intelAttempted[src] = rollKey
        hasIntel = false
    else
        intelAttempted[src] = rollKey
        local profile = getBehaviorProfile(netId)
        hasIntel = math.random(100) <= (profile.intelChance or 70)
    end

    local intelContent = nil
    if hasIntel then
        intelContent = generateIntelContent(intelType)
    end

    -- Remember what WE offered so acceptIntelDeal cannot be handed forged
    -- type/content by the client, and so the roll cannot be re-rolled.
    pendingIntelOffers[src] = hasIntel and { netId = netId, intelType = intelType, content = intelContent } or nil

    TriggerClientEvent('npc:intelOfferResponse', src, netId, hasIntel, intelType, intelContent, npcName)
end)

-- Player accepts intel deal
RegisterNetEvent('npc:acceptIntelDeal')
AddEventHandler('npc:acceptIntelDeal', function(netId, intelType, intelContent)
    local src = source

    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end
    local police, Player = isPolice(src)
    if not Player or not police then return end
    if activeInteractions[src] ~= netId then return end

    local npcName = npcNames[netId]
    if not npcName then return end

    -- Only honour an offer this server actually made, and use OUR type/content:
    -- the client previously supplied both, so arbitrary rows (any length, any
    -- text, even with no offer and no contraband) could be written to the DB.
    local offer = pendingIntelOffers[src]
    if not offer or offer.netId ~= netId or not offer.content then return end
    pendingIntelOffers[src] = nil
    intelType = offer.intelType
    intelContent = offer.content
    intelGiven[src] = { netId = netId, data = { type = intelType, content = intelContent } }

    -- Record the intel
    local locationHint = Config.intelLocations and Config.intelLocations[math.random(#Config.intelLocations)] or nil
    recordIntel(src, npcName, intelType, intelContent, locationHint, 'arrest')

    -- If using dps-ainpcs, sync intel
    if Config.aiIntegration and Config.aiIntegration.enabled then
        local resourceState = GetResourceState('dps-ainpcs')
        if resourceState == 'started' then
            TriggerEvent('dps-ainpcs:server:recordIntel', {
                source = npcName.firstname .. ' ' .. npcName.lastname,
                type = intelType,
                content = intelContent,
                reliability = 3,
                officerId = Player.PlayerData.citizenid
            })
        end
    end

    NotifyClient(src, 'Intel recorded. NPC will receive reduced sentence.', 'success')
end)

-- Player offers to recruit NPC as informant
RegisterNetEvent('npc:offerInformantDeal')
AddEventHandler('npc:offerInformantDeal', function(netId)
    local src = source

    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end
    local police = isPolice(src)
    if not police then return end
    if activeInteractions[src] ~= netId then return end

    local npcName = npcNames[netId]
    if not npcName then return end

    -- Willingness to become an informant is driven by personality (informantChance);
    -- characters flagged canGiveIntel = false refuse outright.
    local char = npcCharacterData[netId]
    local accepts
    if char and char.canGiveIntel == false then
        accepts = false
    else
        local profile = getBehaviorProfile(netId)
        accepts = math.random(100) <= (profile.informantChance or 40)
    end

    if accepts then
        local success, reason = recruitInformant(src, netId)
        if success then
            TriggerClientEvent('npc:informantResponse', src, netId, true, npcName)
        else
            TriggerClientEvent('npc:informantResponse', src, netId, false, npcName, reason)
        end
    else
        TriggerClientEvent('npc:informantResponse', src, netId, false, npcName, 'refused')
    end
end)

-- Get NPC context for AI dialogue
RegisterNetEvent('npc:getAIContext')
AddEventHandler('npc:getAIContext', function(netId)
    local src = source

    if not validatePedNetId(netId) then return end
    local police = isPolice(src)
    if not police then return end
    if activeInteractions[src] ~= netId then return end

    local context = {
        name = npcNames[netId],
        hasIllegal = npcIllegal[netId] or false,
        inventory = npcInventories[netId],
        model = npcModels[netId]
    }

    -- Add arrest history if available
    if Config.jailSystem and Config.jailSystem.enabled and context.name then
        context.arrestHistory = getNpcArrestHistory(context.name.firstname, context.name.lastname)
        context.inJail = isCharacterJailedCached(context.name.firstname, context.name.lastname)
    end

    TriggerClientEvent('npc:aiContextResponse', src, netId, context)
end)

RegisterNetEvent('exitclearance')
AddEventHandler('exitclearance', function(netId)
    local src = source

    if activeInteractions[src] == netId then
        activeInteractions[src] = nil
        if npcLocks[netId] == src then
            npcLocks[netId] = nil
        end
        -- Full per-NPC cleanup so released peds don't leak state
        npcInventories[netId] = nil
        npcNames[netId] = nil
        npcIllegal[netId] = nil
        npcModels[netId] = nil
        npcCharacterData[netId] = nil
        TriggerClientEvent('Cleartasks', src, netId)
    end
end)

-- Refresh inventory callback for after seizing items
RegisterNetEvent('npc:requestInventoryRefresh')
AddEventHandler('npc:requestInventoryRefresh', function(netId)
    local src = source

    if not validatePedNetId(netId) then return end
    if not isPlayerNearNpc(src, netId, 5.0) then return end
    local police = isPolice(src)
    if not police then return end
    if activeInteractions[src] ~= netId then return end

    local inventory = npcInventories[netId]
    if not inventory then return end

    local npcItems = {}
    local illegal = false
    local hasItems = false

    for idx, item in ipairs(inventory) do
        if item.qty > 0 then
            hasItems = true
            local legalTag = item.legal and "" or " ~r~(illegal)~s~"
            table.insert(npcItems, {
                header = (item.label or item.item) .. " x" .. item.qty .. legalTag,
                txt = "Click to seize this item",
                icon = item.legal and "fas fa-box" or "fas fa-exclamation-triangle",
                params = {
                    event = "npc:seizeItem",
                    args = { netId = netId, itemIndex = idx }
                }
            })
        end
        if item.legal == false and item.qty > 0 then illegal = true end
    end

    if not hasItems then
        table.insert(npcItems, {
            header = "No items remaining",
            txt = "",
            isMenuHeader = true
        })
    end

    npcIllegal[netId] = illegal
    TriggerClientEvent('addmenu', src, illegal, npcItems, netId)
end)
