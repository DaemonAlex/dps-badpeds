-- Corner crews (DPS 2026-10-29): small groups of local peds on the gang blocks that the
-- existing police flow (Talk / frisk / arrest, dps-badpeds client.lua) already handles,
-- because they are ordinary CPed entities in the game pool. The server hands out spots
-- against the City Pulse budget; this file only places and animates them.
-- Street rule: every ped is snapped to pavement and refused near a road node or a car.

local C = Config.crews or {}
local spots = C.spots or {}
local crews = {}        -- idx -> { peds = {}, claimed = true }
local pending = {}      -- idx -> true while a claim is in flight
local lastHourSent = -1

local function pavementSpot(x, y, z)
    local ok, px, py, pz = GetSafeCoordForPed(x, y, z, true, 16)
    if not ok then ok, px, py, pz = GetSafeCoordForPed(x, y, z, false, 16) end
    if not ok then return nil end
    -- GetClosestVehicleNodeWithHeading returns (bool, vector3, heading) on this build
    -- (matches dps-gangwars); wrap it so a pathfind-not-ready fault can't crash the thread.
    local got, found, node = pcall(GetClosestVehicleNodeWithHeading, px, py, pz, 1, 3.0, 0)
    if got and found and node then
        local away = vector3(px - node.x, py - node.y, 0.0)
        local d = #away
        if d < 3.0 then
            if d < 0.1 then return nil end
            away = away / d
            px, py = node.x + away.x * 3.5, node.y + away.y * 3.5
            local g, gz = GetGroundZFor_3dCoord(px, py, pz + 2.0, false)
            if g then pz = gz end
        end
    end
    if GetClosestVehicle(px, py, pz, 5.0, 0, 70) ~= 0 then return nil end
    return vector3(px, py, pz)
end

local function isNight()
    local h = GetClockHours()
    return h >= 20 or h < 6
end

local function spawnCrew(idx, count)
    local s = spots[idx]
    local models = s.models or C.models or {}
    local set = { peds = {} }
    for i = 1, count do
        local ang = (i / count) * 6.283
        local spot = pavementSpot(s.coords.x + math.cos(ang) * 2.5, s.coords.y + math.sin(ang) * 2.5, s.coords.z)
        if spot and #models > 0 then
            local hash = joaat(models[math.random(#models)])
            if IsModelInCdimage(hash) then
                lib.requestModel(hash, 5000)
                local heading = GetHeadingFromVector_2d(s.coords.x - spot.x, s.coords.y - spot.y)
                local ped = CreatePed(26, hash, spot.x, spot.y, spot.z, heading, false, true)
                if DoesEntityExist(ped) then
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetPedCanRagdollFromPlayerImpact(ped, true)
                    SetPedRelationshipGroupHash(ped, joaat('AMBIENT_GANG_BALLAS'))
                    local scen = (C.scenarios or {})[math.random(#(C.scenarios or {'WORLD_HUMAN_HANG_OUT_STREET'}))] or 'WORLD_HUMAN_HANG_OUT_STREET'
                    TaskStartScenarioInPlace(ped, scen, 0, true)
                    Entity(ped).state:set('type', 'dps_crew', false)
                    Entity(ped).state:set('carry', math.random(100) <= (C.carryChance or 60), false)
                    set.peds[#set.peds + 1] = ped
                end
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
    crews[idx] = set
end

local function removeCrew(idx)
    local set = crews[idx]
    if set then
        for _, ped in ipairs(set.peds) do
            if DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end
        crews[idx] = nil
    end
    TriggerServerEvent('dps-badpeds:crew:release', idx)
end

-- Spots come and go with distance; the server says yes or no against the pulse budget.
CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local night = isNight()
        for idx, s in ipairs(spots) do
            local dist = #(me - s.coords)
            if not crews[idx] and not pending[idx] and dist < (C.spawnRange or 150.0) and (night or not s.nightOnly) then
                pending[idx] = true
                CreateThread(function()
                    local ok, count = lib.callback.await('dps-badpeds:crew:claim', false, idx)
                    if ok then spawnCrew(idx, count or 2) end
                    pending[idx] = nil
                end)
            elseif crews[idx] and (dist > (C.despawnRange or 200.0) or (s.nightOnly and not night)) then
                removeCrew(idx)
            end
        end
        -- the server rolls rough nights on the game clock; one report a minute
        local h = GetClockHours()
        if h ~= lastHourSent then
            lastHourSent = h
            TriggerServerEvent('dps-pulse:hour', h)
        end
        Wait(3000)
    end
end)

-- A cop close by: some walk off, a few bolt, the rest pocket their hands.
CreateThread(function()
    while true do
        local sleep = 2000
        local me = PlayerPedId()
        local mine = GetEntityCoords(me)
        local cop = false
        for _, pid in ipairs(GetActivePlayers()) do
            local p = GetPlayerPed(pid)
            if #(GetEntityCoords(p) - mine) < 60.0 then
                -- any player in a police vehicle counts; the job check lives server side
                local v = GetVehiclePedIsIn(p, false)
                if v ~= 0 and GetVehicleClass(v) == 18 then cop = true break end
            end
        end
        if cop then
            sleep = 1000
            for idx, set in pairs(crews) do
                if not set.reacted then
                    set.reacted = true
                    for _, ped in ipairs(set.peds) do
                        if DoesEntityExist(ped) then
                            local r = math.random(100)
                            if r <= (C.react and C.react.flee or 10) then
                                TaskSmartFleePed(ped, me, 120.0, 20000, false, false)
                            elseif r <= (C.react and C.react.flee or 10) + (C.react and C.react.walk or 30) then
                                TaskWanderStandard(ped, 10.0, 10)
                            else
                                ClearPedTasks(ped)
                                TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for idx in pairs(crews) do removeCrew(idx) end
end)
