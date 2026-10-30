-- Vibe patrol (DPS 2026-10-30, Damon): emergency vehicles with somewhere to be.
-- Every unit drives FROM its station TO a destination on the far side of you,
-- so it passes through like a real cop going to a call, never circling. Some
-- siren passes are the call itself: a suspect car flying past with cruisers in
-- chase. All of it is local ambience: blocked peds, props in motion.

local P = Config.vibePatrol or {}
local act = nil   -- { ents = {entity...}, lead = veh, bornAt, dest = vec3 }

local function cleanup()
    if not act then return end
    for _, e in ipairs(act.ents) do
        if DoesEntityExist(e) then SetEntityAsMissionEntity(e, true, true); DeleteEntity(e) end
    end
    act = nil
end

local function track(e) act.ents[#act.ents + 1] = e end

local function pickUnit(mc, hot)
    local lo = (P.baseBand and P.baseBand[1]) or 180.0
    local hi = (P.baseBand and P.baseBand[2]) or 650.0
    local pool, total = {}, 0
    for _, u in ipairs(P.units or {}) do
        local near = {}
        for _, b in ipairs(u.bases or {}) do
            local d = #(mc - b)
            if d >= lo and d <= hi then near[#near + 1] = b end
        end
        if #near > 0 then
            local w = u.weight or 1
            if hot and u.leo then w = w * (P.hotLeoBias or 3) end
            total = total + w
            pool[#pool + 1] = { u = u, bases = near, w = w }
        end
    end
    if total == 0 then return nil end
    local r, acc = math.random() * total, 0
    for _, e in ipairs(pool) do
        acc = acc + e.w
        if r <= acc then return e.u, e.bases[math.random(#e.bases)] end
    end
end

---Spawn point on a road near `from`, and a destination PAST the player so the
---route runs through their world and keeps going.
local function routeFor(mc, from)
    local got, found, node, heading = pcall(GetClosestVehicleNodeWithHeading, from.x, from.y, from.z, 0, 3.0, 0)
    if not (got and found and node) then return nil end
    local dir = mc - vector3(node.x, node.y, node.z)
    local flat = vector3(dir.x, dir.y, 0.0)
    local len = #flat
    if len < 1.0 then return nil end
    flat = flat / len
    local reach = (P.passBeyond or 700.0) + math.random(0, 400)
    local dest = mc + flat * reach          -- the far side of the player, roughly on the same line
    return node, (heading or 0.0), vector3(dest.x, dest.y, mc.z)
end

local function spawnVehicle(model, driver, node, heading)
    local vmodel, pmodel = joaat(model), joaat(driver)
    if not IsModelInCdimage(vmodel) or not IsModelInCdimage(pmodel) then return nil end
    lib.requestModel(vmodel, 8000); lib.requestModel(pmodel, 8000)
    local veh = CreateVehicle(vmodel, node.x, node.y, node.z, heading, false, true)
    if not DoesEntityExist(veh) then return nil end
    local ped = CreatePedInsideVehicle(veh, 6, pmodel, -1, false, true)
    SetModelAsNoLongerNeeded(vmodel); SetModelAsNoLongerNeeded(pmodel)
    if not DoesEntityExist(ped) then SetEntityAsMissionEntity(veh, true, true); DeleteEntity(veh); return nil end
    SetPedDefaultComponentVariation(ped)
    SetEntityInvincible(ped, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetDriverAbility(ped, 1.0)
    return veh, ped
end

local function dressUnit(veh, unit)
    SetVehicleModKit(veh, 0)
    if unit.livery ~= nil then
        SetVehicleLivery(veh, unit.livery)
        SetVehicleMod(veh, 48, unit.livery, false)
    end
    if unit.colors then SetVehicleColours(veh, unit.colors[1], unit.colors[2]) end
    SetVehicleDirtLevel(veh, 0.0)
end

local function spawnPatrol(hot, forceChase)
    local me = PlayerPedId()
    local mc = GetEntityCoords(me)
    local unit, base = pickUnit(mc, hot)
    if not unit then
        unit = (P.units or {})[1]
        if not unit then return end
        local lo = (P.fallbackDist and P.fallbackDist[1]) or 280.0
        local hi = (P.fallbackDist and P.fallbackDist[2]) or 380.0
        local ang = math.random() * 6.283
        base = vector3(mc.x + math.cos(ang) * (lo + math.random() * (hi - lo)),
                       mc.y + math.sin(ang) * (lo + math.random() * (hi - lo)), mc.z)
    end
    local node, heading, dest = routeFor(mc, base)
    if not node then return end

    local siren = forceChase or (math.random(100) <= (unit.sirenChance or 30))
    local chase = unit.leo and siren and (forceChase or math.random(100) <= (P.chaseChance or 25))

    act = { ents = {}, lead = nil, bornAt = GetGameTimer(), dest = dest }

    if chase then
        -- the call itself: a suspect car flying through with cruisers behind
        local smodels = P.chaseSuspects or { 'sultan', 'buffalo', 'futo', 'ruiner' }
        local sveh, sped = spawnVehicle(smodels[math.random(#smodels)], 'a_m_y_stlat_01', node, heading)
        if not sveh then act = nil return end
        track(sveh); track(sped)
        SetVehicleColours(sveh, math.random(0, 159), 0)
        SetBlockingOfNonTemporaryEvents(sped, true)
        TaskVehicleDriveToCoordLongrange(sped, sveh, dest.x, dest.y, dest.z, P.chaseSpeed or 36.0, 787004, 25.0)
        act.lead = sveh
        local cops = (P.chaseCops and math.random(P.chaseCops[1], P.chaseCops[2])) or math.random(1, 2)
        for i = 1, cops do
            local back = vector3(node.x - math.sin(math.rad(heading)) * -(14 * i), node.y - math.cos(math.rad(heading)) * (14 * i), node.z)
            local cveh, cped = spawnVehicle(unit.model, unit.driver, back, heading)
            if cveh then
                track(cveh); track(cped)
                dressUnit(cveh, unit)
                SetBlockingOfNonTemporaryEvents(cped, true)
                SetVehicleHasMutedSirens(cveh, false)
                SetVehicleSiren(cveh, true)
                SetDriverAggressiveness(cped, 1.0)
                TaskVehicleChase(cped, sped)
                SetTaskVehicleChaseBehaviorFlag(cped, 32, true)   -- can ram
                SetTaskVehicleChaseIdealPursuitDistance(cped, 8.0)
            end
        end
    else
        local veh, ped = spawnVehicle(unit.model, unit.driver, node, heading)
        if not veh then act = nil return end
        track(veh); track(ped)
        dressUnit(veh, unit)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetDriverAggressiveness(ped, 0.0)
        act.lead = veh
        if siren then
            SetVehicleHasMutedSirens(veh, false)
            SetVehicleSiren(veh, true)
            TaskVehicleDriveToCoordLongrange(ped, veh, dest.x, dest.y, dest.z, unit.speed or 25.0, 787004, 25.0)
        else
            TaskVehicleDriveToCoordLongrange(ped, veh, dest.x, dest.y, dest.z, unit.quietSpeed or 16.0, 786603, 25.0)
        end
    end
end

-- One roll a minute; the server says yes against the City Pulse and real-cop count.
CreateThread(function()
    TriggerServerEvent('dps-badpeds:patrol:hello')
    while true do
        Wait(60000)
        if (P.enabled ~= false) and not act and not IsPedDeadOrDying(PlayerPedId(), true) then
            local ok = lib.callback.await('dps-badpeds:patrol:roll', false)
            if ok then spawnPatrol(type(ok) == "table" and ok.hot) end
        end
    end
end)

-- Let the pass finish: gone when it reaches the call, leaves earshot, or times out.
CreateThread(function()
    while true do
        if act then
            local lead = act.lead
            if not lead or not DoesEntityExist(lead)
               or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(lead)) > (P.despawnDist or 500.0)
               or (act.dest and #(GetEntityCoords(lead) - act.dest) < 45.0)
               or GetGameTimer() - act.bornAt > (P.lifeSec or 240) * 1000 then
                cleanup()
            end
            Wait(8000)
        else
            Wait(30000)
        end
    end
end)

-- Test triggers (Damon): /vibenow = one pass now; /vibenow chase = a pursuit now.
RegisterCommand('vibenow', function(_, args)
    cleanup()
    spawnPatrol(true, args and args[1] == 'chase')
end, false)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then cleanup() end end)
