-- Road rage (DPS 2026-10-29, Damon): bump an ordinary occupied NPC car and sometimes the
-- driver snaps. He chases and rams; bail out and he bails too and comes at you. The roll
-- is server side (pulse, heat, cooldown). One rager per player at a time; cops are fair game.

local R = Config.roadRage or {}
local rager = nil          -- { ped, veh, started, armed, onFoot }
local lastBumpCheck = 0

local function endRage(reason)
    if not rager then return end
    local ped = rager.ped
    if DoesEntityExist(ped) then
        ClearPedTasks(ped)
        SetPedAsNoLongerNeeded(ped)
        SetEntityAsMissionEntity(ped, false, false)
        if DoesEntityExist(rager.veh) then SetVehicleAsNoLongerNeeded(rager.veh) end
        if GetVehiclePedIsIn(ped, false) ~= 0 then TaskVehicleDriveWander(ped, GetVehiclePedIsIn(ped, false), 15.0, 786603) else TaskWanderStandard(ped, 10.0, 10) end
    end
    rager = nil
end

local function startRage(ped, veh, armed)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityAsMissionEntity(veh, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)   -- always fight
    SetPedCombatAttributes(ped, 5, true)    -- can fight armed peds when unarmed
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 1.0)
    if armed then GiveWeaponToPed(ped, joaat('WEAPON_PISTOL'), 60, false, false) end
    StartVehicleHorn(veh, 1500, joaat('NORMAL'), false)
    PlayAmbientSpeech1(ped, 'GENERIC_INSULT_HIGH', 'Speech_Params_Force_Shouted')
    -- ram: drive-to-target with aggressive flags, re-issued while the player is in a car
    TaskVehicleChase(ped, PlayerPedId())
    SetTaskVehicleChaseBehaviorFlag(ped, 1, true)   -- can't cruise
    SetTaskVehicleChaseBehaviorFlag(ped, 32, true)  -- can ram
    SetTaskVehicleChaseIdealPursuitDistance(ped, 0.0)
    rager = { ped = ped, veh = veh, started = GetGameTimer(), armed = armed, onFoot = false }
end

-- Bump detection: our car touched an occupied NPC car.
CreateThread(function()
    while true do
        local sleep = 1000
        if (R.enabled ~= false) and not rager then
            local me = PlayerPedId()
            local myVeh = GetVehiclePedIsIn(me, false)
            if myVeh ~= 0 and GetPedInVehicleSeat(myVeh, -1) == me then
                sleep = 200
                if HasEntityCollidedWithAnything(myVeh) and GetGameTimer() - lastBumpCheck > 2000 then
                    lastBumpCheck = GetGameTimer()
                    local other = nil
                    for _, v in ipairs(GetGamePool('CVehicle')) do
                        if v ~= myVeh and IsEntityTouchingEntity(myVeh, v) then other = v break end
                    end
                    if other then
                        local driver = GetPedInVehicleSeat(other, -1)
                        if driver ~= 0 and not IsPedAPlayer(driver) and not IsPedDeadOrDying(driver, true)
                           and GetVehicleClass(other) ~= 18 and GetVehicleClass(other) ~= 13 and NetworkHasControlOfEntity(driver) then
                            local roll = lib.callback.await('dps-badpeds:roadrage:roll', false)
                            if roll then startRage(driver, other, roll.armed) end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- The chase itself.
CreateThread(function()
    while true do
        if rager then
            local me = PlayerPedId()
            local ped, veh = rager.ped, rager.veh
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or IsPedDeadOrDying(me, true) then
                endRage('over')
            else
                local dist = #(GetEntityCoords(me) - GetEntityCoords(ped))
                if GetGameTimer() - rager.started > (R.durationMs or 90000) or dist > (R.breakOffM or 200.0) then
                    endRage('gave up')
                else
                    local myVeh = GetVehiclePedIsIn(me, false)
                    if myVeh == 0 and not rager.onFoot then
                        -- you bailed: a beat later he bails and comes for you
                        rager.onFoot = true
                        SetTimeout(R.bailDelayMs or 3000, function()
                            if rager and rager.ped == ped and DoesEntityExist(ped) then
                                TaskLeaveVehicle(ped, veh, 256)
                                Wait(1500)
                                if rager and rager.ped == ped then
                                    if rager.armed then
                                        TaskCombatPed(ped, me, 0, 16)
                                        TriggerServerEvent('dps-badpeds:roadrage:shots')
                                    else
                                        SetPedCombatAttributes(ped, 3, false) -- no gun drawn
                                        TaskCombatPed(ped, me, 0, 16)
                                    end
                                end
                            end
                        end)
                    elseif myVeh ~= 0 and rager.onFoot and GetVehiclePedIsIn(ped, false) == 0 and dist > 15.0 then
                        -- you got back in a car and pulled away: he gets back in his and keeps coming
                        rager.onFoot = false
                        TaskEnterVehicle(ped, veh, 8000, -1, 2.0, 1, 0)
                        SetTimeout(8500, function()
                            if rager and rager.ped == ped and GetVehiclePedIsIn(ped, false) == veh then
                                TaskVehicleChase(ped, me)
                                SetTaskVehicleChaseBehaviorFlag(ped, 32, true)
                            end
                        end)
                    end
                end
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then endRage('stop') end
end)
