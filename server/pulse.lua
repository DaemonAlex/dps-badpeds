-- City Pulse (DPS 2026-10-29): one number for "how much fake crime does the city need
-- right now", read by the crews, the tips and road rage, and exported for other scripts.
-- Inputs come from the framework and from our own scripts' dps-pulse:incident events.

local P = Config.pulse or {}
local H = Config.heat or {}
local incidents = {}          -- os.time() stamps of real incidents (last 30 min kept)
local state = { pulse = 0.0, effective = 0.0, heat = 1.0, heatName = 'normal', inputs = {}, at = 0 }
local lastHour, lastHeatRoll = nil, 0

local function prune()
    local cut, keep = os.time() - 1800, {}
    for _, t in ipairs(incidents) do if t >= cut then keep[#keep + 1] = t end end
    incidents = keep
end

AddEventHandler('dps-pulse:incident', function(kind)
    incidents[#incidents + 1] = os.time()
end)

local function rollHeat(reason)
    local odds = H.odds or { quiet = 25, normal = 50, rough = 20, wild = 5 }
    local mult = H.mult or { quiet = 0.6, normal = 1.0, rough = 1.5, wild = 2.2 }
    local r, acc, picked = math.random(100), 0, 'normal'
    for _, name in ipairs({ 'quiet', 'normal', 'rough', 'wild' }) do
        acc = acc + (odds[name] or 0)
        if r <= acc then picked = name break end
    end
    state.heatName, state.heat = picked, mult[picked] or 1.0
    lastHeatRoll = os.time()
    print(('[dps-badpeds] tonight is %s (heat x%.1f, %s)'):format(picked, state.heat, reason))
end

local function compute()
    prune()
    local players = #GetPlayers()
    local cops, gang = 0, 0
    pcall(function() cops = exports.qbx_core:GetDutyCountType('leo') or 0 end)
    pcall(function()
        for _, p in pairs(exports.qbx_core:GetQBPlayers()) do
            local g = p.PlayerData and p.PlayerData.gang
            if g and g.name and g.name ~= 'none' then gang = gang + 1 end
        end
    end)
    local inc = #incidents
    local pulse = 0.0
    if players > 0 then
        local pressure = gang * (P.gangWeight or 0.15) + inc * (P.incidentWeight or 0.10)
        pulse = math.max(0.0, 1.0 - math.min(1.0, pressure))
        if players > (P.crowdAt or 24) then pulse = pulse * (P.crowdMult or 0.7) end
    end
    state.pulse = pulse
    state.effective = math.min(1.5, pulse * state.heat)
    state.inputs = { players = players, cops = cops, gang = gang, incidents30 = inc }
    state.at = os.time()
end

CreateThread(function()
    Wait(5000)
    rollHeat('resource start')
    while true do
        compute()
        Wait((P.intervalMin or 5) * 60000)
    end
end)

-- Clients report the game hour once a minute; the night's heat is rolled when the
-- clock crosses dusk, once per night.
RegisterNetEvent('dps-pulse:hour', function(hour)
    if type(hour) ~= 'number' then return end
    local dusk = H.duskHour or 20
    if lastHour and lastHour < dusk and hour >= dusk and os.time() - lastHeatRoll > 1800 then
        rollHeat('dusk')
    end
    lastHour = hour
end)

exports('GetPulse', function()
    return { pulse = state.pulse, effective = state.effective, heat = state.heat, heatName = state.heatName, inputs = state.inputs, at = state.at }
end)

RegisterCommand('pulse', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command') then return end
    compute()
    local i = state.inputs
    local line = ('pulse %.2f x heat %.1f (%s) = %.2f | players %d, cops %d, gang %d, incidents/30min %d'):format(
        state.pulse, state.heat, state.heatName, state.effective, i.players or 0, i.cops or 0, i.gang or 0, i.incidents30 or 0)
    print('[dps-badpeds] ' .. line)
    if src ~= 0 then TriggerClientEvent('ox_lib:notify', src, { title = 'City Pulse', description = line, type = 'inform', duration = 9000 }) end
end, true)
