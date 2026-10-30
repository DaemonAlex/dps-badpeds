-- Vibe patrol (DPS 2026-10-30, Damon): an emergency vehicle rolls through on full
-- lights and siren now and then, leaving from one of its real base stations. Pure
-- ambience, local to this client like the corner crews: the driver is blocked from
-- every event, so it is a prop in motion, not a responder.

local P = Config.vibePatrol or {}
local car, cop, bornAt = nil, nil, 0

local function cleanup()
    if cop and DoesEntityExist(cop) then SetEntityAsMissionEntity(cop, true, true); DeleteEntity(cop) end
    if car and DoesEntityExist(car) then SetEntityAsMissionEntity(car, true, true); DeleteEntity(car) end
    car, cop = nil, nil
end

local function pickUnit(mc, hot)
    -- weighted pick among units that have a base inside the band; remember the base
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
            if hot and u.leo then w = w * ((P.hotLeoBias or 3)) end
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

local function spawnPatrol(hot)
    local me = PlayerPedId()
    local mc = GetEntityCoords(me)
    local unit, base = pickUnit(mc, hot)
    local sx, sy, sz
    if base then
        sx, sy, sz = base.x, base.y, base.z
    else
        -- nothing based nearby: a unit passing through, from a road this far out
        unit = (P.units or {})[1]
        if not unit then return end
        local lo = (P.fallbackDist and P.fallbackDist[1]) or 280.0
        local hi = (P.fallbackDist and P.fallbackDist[2]) or 380.0
        local ang = math.random() * 6.283
        local d = lo + math.random() * (hi - lo)
        sx, sy, sz = mc.x + math.cos(ang) * d, mc.y + math.sin(ang) * d, mc.z
    end
    local got, found, node, heading = pcall(GetClosestVehicleNodeWithHeading, sx, sy, sz, 0, 3.0, 0)
    if not (got and found and node) then return end
    local vmodel, pmodel = joaat(unit.model), joaat(unit.driver)
    if not IsModelInCdimage(vmodel) or not IsModelInCdimage(pmodel) then return end
    lib.requestModel(vmodel, 8000); lib.requestModel(pmodel, 8000)
    car = CreateVehicle(vmodel, node.x, node.y, node.z, heading or 0.0, false, true)
    if not DoesEntityExist(car) then car = nil return end
    cop = CreatePedInsideVehicle(car, 6, pmodel, -1, false, true)
    SetModelAsNoLongerNeeded(vmodel); SetModelAsNoLongerNeeded(pmodel)
    if not DoesEntityExist(cop) then cleanup() return end
    SetBlockingOfNonTemporaryEvents(cop, true)   -- sees nothing, chases nobody
    SetEntityInvincible(cop, true)
    SetVehicleEngineOn(car, true, true, false)
    SetDriverAbility(cop, 1.0)
    SetDriverAggressiveness(cop, 0.0)
    if math.random(100) <= (unit.sirenChance or 30) then
        -- code-3 pass: full lights and wail, runs reds, steers around traffic
        SetVehicleHasMutedSirens(car, false)
        SetVehicleSiren(car, true)
        TaskVehicleDriveWander(cop, car, unit.speed or 25.0, 787004)
    else
        -- routine patrol: no siren, normal pace, stops at lights
        TaskVehicleDriveWander(cop, car, unit.quietSpeed or 16.0, 786603)
    end
    bornAt = GetGameTimer()
end

-- One roll a minute; the server says yes against the City Pulse and real-cop count.
CreateThread(function()
    while true do
        Wait(60000)
        if (P.enabled ~= false) and not car and not IsPedDeadOrDying(PlayerPedId(), true) then
            local ok = lib.callback.await('dps-badpeds:patrol:roll', false)
            if ok then spawnPatrol(type(ok) == "table" and ok.hot) end
        end
    end
end)

-- Watch the active patrol out of earshot, then let it go.
CreateThread(function()
    while true do
        if car then
            if not DoesEntityExist(car)
               or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(car)) > (P.despawnDist or 500.0)
               or GetGameTimer() - bornAt > (P.lifeSec or 240) * 1000 then
                cleanup()
            end
            Wait(10000)
        else
            Wait(30000)
        end
    end
end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then cleanup() end end)
