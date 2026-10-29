-- Corner crews and road rage, server side (DPS 2026-10-29). The server only decides
-- WHO may run a crew spot and WHEN a tip goes out; the peds live on the owning client.

local C = Config.crews or {}
local spots = C.spots or {}
local active = {}   -- idx -> { owner = src, since = os.time() }

local function pulse() return exports['dps-badpeds']:GetPulse() end

local function budget()
    local p = pulse()
    if (p.effective or 0) < (C.floor or 0.2) then return 0, p end
    return math.min(#spots, math.floor(#spots * math.min(1.0, p.effective) + 0.5)), p
end

local function activeCount()
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n
end

lib.callback.register('dps-badpeds:crew:claim', function(src, idx)
    local s = spots[idx]
    if not s or active[idx] then return false end
    local b, p = budget()
    local n = activeCount()
    if n >= b then return false end
    -- rough and wild nights lean on the Davis blocks: non-Davis spots only get half the budget
    if (p.heat or 1.0) > 1.0 and not s.davis and n >= math.floor(b / 2) then return false end
    active[idx] = { owner = src, since = os.time() }
    return true, math.random(s.min or 2, s.max or 3)
end)

RegisterNetEvent('dps-badpeds:crew:release', function(idx)
    local src = source
    if active[idx] and active[idx].owner == src then active[idx] = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for i, a in pairs(active) do if a.owner == src then active[i] = nil end end
end)

-- Tips: random, pulse-driven, never clocked.
CreateThread(function()
    local lastTip = 0
    while true do
        Wait(60000)
        local cfg = C.tips or {}
        local p = pulse()
        local eff = p.effective or 0
        if eff >= (cfg.floor or 0.2) and os.time() - lastTip >= (cfg.minGapMin or 20) * 60 and activeCount() > 0 then
            local meanMin = (cfg.meanMinAtFull or 60) / math.min(1.5, eff)
            if math.random() < 1.0 / meanMin then
                local list = {}
                for i in pairs(active) do list[#list + 1] = i end
                local s = spots[list[math.random(#list)]]
                lastTip = os.time()
                if GetResourceState(Config.dispatch.resource or 'wasabi_mdt') == 'started' then
                    pcall(function()
                        exports[Config.dispatch.resource or 'wasabi_mdt']:CreateDispatch({
                            type = cfg.type or 'disturbance', title = cfg.title, description = cfg.description,
                            location = s.label, coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z },
                            priority = cfg.priority or 2, senderName = 'Anonymous Caller',
                        })
                    end)
                end
            end
        end
    end
end)

-- Road rage: the roll lives here so the pulse, the heat and the cooldown cannot be faked.
local rageCooldown = {}
lib.callback.register('dps-badpeds:roadrage:roll', function(src)
    local cfg = Config.roadRage or {}
    if not cfg.enabled then return false end
    local now = os.time()
    if rageCooldown[src] and now - rageCooldown[src] < (cfg.cooldownMs or 600000) / 1000 then return false end
    local p = pulse()
    local chance = (cfg.baseChance or 8) * (p.heat or 1.0) * math.max(0.25, p.pulse or 0)
    if (p.inputs and p.inputs.players or 0) == 0 then return false end
    rageCooldown[src] = now
    if math.random() * 100 > chance then return false end
    local armed = p.heatName == 'wild' and math.random(100) <= (cfg.armedChanceWild or 20)
    TriggerEvent('dps-pulse:incident', 'roadrage')
    return { armed = armed }
end)

-- A gun came out in a road-rage fight: dispatch like the hookers' witness rule.
local shotsCooldown = {}
RegisterNetEvent('dps-badpeds:roadrage:shots', function()
    local src = source
    if shotsCooldown[src] and os.time() - shotsCooldown[src] < 120 then return end
    shotsCooldown[src] = os.time()
    local cfg = Config.dispatch and Config.dispatch.roadRage
    if not cfg or not cfg.enabled then return end
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    if GetResourceState(Config.dispatch.resource or 'wasabi_mdt') == 'started' then
        pcall(function()
            exports[Config.dispatch.resource or 'wasabi_mdt']:CreateDispatch({
                type = cfg.type or 'shooting', title = cfg.title, description = cfg.description,
                location = 'Roadside', coords = { x = c.x, y = c.y, z = c.z }, priority = cfg.priority or 3, senderName = 'Anonymous Caller',
            })
        end)
    end
end)
