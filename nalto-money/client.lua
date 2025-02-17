local QBCore = exports['qb-core']:GetCoreObject()

local trollies = {}
local currentBank = 'vault'
local activeHackZones = {}
local failedAttempts = {}
local drilledSpots = {}
local drillcooldowns = {}
local lastVaultAlertTime = 0
local vaultAlertCooldown = 60000 -- 1-minute cooldown
local completedHacks = {}

-- Vault Door Configurations
local VAULT_DOORS = {
    {
        hash = 1011509889,
        name = "vault_door_prop_1",
        coords = vector4(242.13691711426, -1091.4302978516, 29.663249969482, 88.031440734863)
    },
    {
        hash = 1011509889,
        name = "vault_door_prop_2", 
        coords = vector4(245.9981842041, -1096.8836669922, 29.663249969482, 88.031509399414)
    },
    {
        hash = 1011509889,
        name = "vault_door_prop_3", 
        coords = vector4(244.6826171875, -1099.0671386719, 29.663249969482, 358.03143310547)
    },
    {
        hash = -2050208642,
        name = "vault_door_prop_4", 
        coords = vector4(246.7999420166, -1101.2583007812, 29.739528656006, 268.03146362305)
    },
    {
        hash = -2050208642,
        name = "vault_door_prop_5", 
        coords = vector4(245.93334960938, -1104.4332275391, 29.739528656006, 178.0082244873)
    },
    {
        hash = -2050208642,
        name = "vault_door_prop_6", 
        coords = vector4(240.38436889648, -1104.2425537109, 29.739528656006, 178.03143310547)
    }
}

-- Hacking Locations
local HACK_LOCATIONS = {
    {
        coords = vector3(239.08, -1089.60, 28.52),
        targetDoorIndex = {1},
        label = "Disable Door Lock (First Point)",
        animDict = "anim@scripted@ulp_missions@computerhack@heeled@",
        animName = "hack_loop"
    },
    {
        coords = vector3(242.49, -1094.92, 28.66),
        targetDoorIndex = {2},
        label = "Disable Door Lock (Second Point)",
        animDict = "anim@scripted@ulp_missions@computerhack@heeled@",
        animName = "hack_loop"
    },
    {
        coords = vector3(249.96, -1092.86, 28.50),
        targetDoorIndex = {3},
        label = "Secondary System Override",
        animDict = "anim@scripted@ulp_missions@computerhack@heeled@",
        animName = "hack_loop"
    },
    {
        coords = vector3(248.78, -1098.21, 28.80),
        targetDoorIndex = {4, 5},  
        label = "Perimeter Control Bypass",
        animDict = "anim@heists@ornate_bank@hack",
        animName = "hack_loop_laptop"
    },
    {
        coords = vector3(246.90, -1094.71, 28.84),
        targetDoorIndex = {6},
        label = "Final Security Breach",
        animDict = "anim@heists@ornate_bank@hack",
        animName = "hack_loop_laptop"
    }
}

local SPECIAL_HACK_COORDS = {
    [4] = { coords = vector3(248.78, -1098.22, 29.90), heading = 181.60 },
    [5] = { coords = vector3(246.99, -1094.65, 29.90), heading = 100.0 }
}

-- Function to find corresponding vault door
local function FindCorrespondingVaultDoor(hackLocationIndex)
    local hackLocation = HACK_LOCATIONS[hackLocationIndex]
    
    if not hackLocation then 
        QBCore.Functions.Notify("Invalid hack location", "error")
        return nil 
    end
    
    if type(hackLocation.targetDoorIndex) == "table" then
        local doors = {}
        for _, doorIndex in ipairs(hackLocation.targetDoorIndex) do
            if VAULT_DOORS[doorIndex] then
                table.insert(doors, VAULT_DOORS[doorIndex])
            else
                QBCore.Functions.Notify("Invalid door index: " .. tostring(doorIndex), "error")
            end
        end
        return #doors > 0 and doors or nil
    else
        local door = VAULT_DOORS[hackLocation.targetDoorIndex]
        if not door then
            QBCore.Functions.Notify("Invalid door index: " .. tostring(hackLocation.targetDoorIndex), "error")
            return nil
        end
        return door
    end
end

-- Function to manage vault door
local function ManageVaultDoor(doorConfig, state)
    if not doorConfig then
        QBCore.Functions.Notify("Invalid door configuration", "error")
        return
    end

    if not doorConfig.coords or not doorConfig.hash then
        QBCore.Functions.Notify("Incomplete door configuration", "error")
        return
    end

    local doorObject = GetClosestObjectOfType(
        doorConfig.coords.x, 
        doorConfig.coords.y, 
        doorConfig.coords.z, 
        2.0, 
        doorConfig.hash, 
        false, 
        false, 
        false
    )

    if doorObject and DoesEntityExist(doorObject) then
        if state == "open" then
            SetEntityHeading(doorObject, doorConfig.coords.w + 1.0)
            FreezeEntityPosition(doorObject, false)
        else
            SetEntityHeading(doorObject, doorConfig.coords.w)
            FreezeEntityPosition(doorObject, true)
        end
    else
        QBCore.Functions.Notify("Door object not found", "error")
    end
end

-- Function to play hacking animation
local function PlayHackAnimation(locationIndex)
    local location = HACK_LOCATIONS[locationIndex]
    
    -- Request animation dictionary
    RequestAnimDict(location.animDict)
    while not HasAnimDictLoaded(location.animDict) do
        Citizen.Wait(100)
    end
    
    -- Play animation
    local playerPed = PlayerPedId()
    TaskPlayAnim(playerPed, location.animDict, location.animName, 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- Function to stop hacking animation
local function StopHackAnimation()
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
end

local function RemoveHackZone(zoneId)
    if activeHackZones[zoneId] then
        exports['qb-target']:RemoveZone(zoneId)
        activeHackZones[zoneId] = nil
    end
end

local function HasRequiredItem(locationIndex)
    local requiredItem = Config.HackItems[locationIndex]
    if not requiredItem then return false end

    local hasItem = QBCore.Functions.HasItem(requiredItem.item)
    if not hasItem then
        QBCore.Functions.Notify("You need a " .. requiredItem.item .. " to hack this.", "error")
        return false
    end

    return true
end

local function VaultBankRobbery()
    local currentTime = GetGameTimer()
    if currentTime - lastVaultAlertTime >= vaultAlertCooldown then
        local coords = GetEntityCoords(cache.ped)
        
        -- Prepare alert data
        local alertData = {
            title = "Vault Robbery",
            coords = coords,
            description = "Robbery in progress at Vault Bank!"
        }
        
        -- Trigger the appropriate alert system
        if exports['ps-dispatch'] then
            exports['ps-dispatch']:VaultBankRobbery(coords)
        else
            TriggerServerEvent('police:server:policeAlert', 'Vault Bank Robbery in Progress')
        end

        lastVaultAlertTime = currentTime
    end
end

-- Export the function for external usage
exports('VaultBankRobbery', VaultBankRobbery)

local function startPinCracker(pinLength, timer)
    if exports['bd-minigames'] and exports['bd-minigames'].PinCracker then
        return exports['bd-minigames']:PinCracker(pinLength, timer) -- Start the PinCracker minigame
    else
        QBCore.Functions.Notify("Minigame not found", "error")
        return false
    end
end

RegisterNetEvent('vault:attemptHack')
AddEventHandler('vault:attemptHack', function(data)
    local locationIndex = data.locationIndex
    local hackLocation = HACK_LOCATIONS[locationIndex]

    if not hackLocation then
        QBCore.Functions.Notify("Invalid hack location", "error")
        return
    end

    QBCore.Functions.TriggerCallback('vault:server:getCops', function(cops)
        if cops >= Config.Police.minimumCount then
            -- Check if hack is already completed
            if completedHacks[locationIndex] then
                QBCore.Functions.Notify('This system has already been breached.', 'error')
                return
            end

            -- Check for required item
            if not HasRequiredItem(locationIndex) then
                return
            end

            local targetDoor = FindCorrespondingVaultDoor(locationIndex)
            if not targetDoor then
                QBCore.Functions.Notify("No valid vault door found for this location", "error")
                return
            end

            -- Player ID for tracking failed attempts
            local playerId = GetPlayerServerId(PlayerId())
            failedAttempts[playerId] = failedAttempts[playerId] or 0

            -- Reset doors to closed position with validation
            if type(targetDoor) == "table" then
                for _, door in ipairs(targetDoor) do
                    if door then
                        ManageVaultDoor(door, "close")
                    end
                end
            else
                ManageVaultDoor(targetDoor, "close")
            end

            local playerPed = PlayerPedId()

            -- Hacks 1-3: PinCracker Minigame
            if locationIndex >= 1 and locationIndex <= 3 then
                HandlePinCrackerHack(locationIndex, targetDoor, playerId)
            elseif locationIndex == 4 then
                HandleSpecialHack4(locationIndex, targetDoor, playerId)
            elseif locationIndex == 5 then
                HandleSpecialHack5(locationIndex, targetDoor, playerId)
            end

            -- If hack is successful, mark it as completed
            QBCore.Functions.TriggerCallback('vault:server:CheckHackState', function(canHack)
                if canHack then
                    if hackSuccess then
                        TriggerServerEvent('vault:server:CompleteHack', locationIndex)
                    end
                end
            end, locationIndex)
        else
            QBCore.Functions.Notify('Not enough police in the city!', 'error')
            return
        end
    end)
end)


-- Function to disable a hack location
RegisterNetEvent('vault:client:DisableHackLocation')
AddEventHandler('vault:client:DisableHackLocation', function(locationIndex)
    local zoneId = "vault_hack_" .. locationIndex
    if activeHackZones[zoneId] then
        exports['qb-target']:RemoveZone(zoneId)
        activeHackZones[zoneId] = nil
        completedHacks[locationIndex] = true
    end
end)

-- Function to reset all hack locations
RegisterNetEvent('vault:client:ResetAllHacks')
AddEventHandler('vault:client:ResetAllHacks', function()
    -- Remove all existing zones first
    for zoneId in pairs(activeHackZones) do
        exports['qb-target']:RemoveZone(zoneId)
        activeHackZones[zoneId] = nil
    end
    
    -- Recreate all hack zones
    for i, location in ipairs(HACK_LOCATIONS) do
        local zoneId = "vault_hack_" .. i
        activeHackZones[zoneId] = true
        
        exports['qb-target']:AddBoxZone(zoneId, location.coords, 1.0, 1.0, {
            name = zoneId,
            heading = 0,
            debugPoly = false,
            minZ = location.coords.z - 1,
            maxZ = location.coords.z + 1,
        }, {
            options = {
                {
                    type = "client",
                    event = "vault:attemptHack",
                    icon = "fas fa-laptop-code",
                    label = location.label,
                    locationIndex = i
                }
            },
            distance = 0.73
        })
    end
    completedHacks = {}
end)

-- Get initial hack states when player loads in
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('vault:server:GetHackStates', function(hackStates)
        completedHacks = hackStates
        -- Disable any completed hack locations
        for locationIndex, completed in pairs(completedHacks) do
            if completed then
                local zoneId = "vault_hack_" .. locationIndex
                if activeHackZones[zoneId] then
                    exports['qb-target']:RemoveZone(zoneId)
                    activeHackZones[zoneId] = nil
                end
            end
        end
    end)
end)

-- Handle PinCracker minigame for locations 1-3
function HandlePinCrackerHack(locationIndex, targetDoor, playerId)
    PlayHackAnimation(locationIndex)

    -- Trigger alert only for the first hack
    if locationIndex == 1 then
        VaultBankRobbery()
    end

    local pinLength = 1
    local timer = 50
    local hackSuccess = startPinCracker(pinLength, timer)

    if hackSuccess then
        HandleHackSuccess(locationIndex, targetDoor, playerId)
    else
        HandleHackFailure(locationIndex, playerId)
    end

    StopHackAnimation()
end

-- Handle special hack for location 4
function HandleSpecialHack4(locationIndex, targetDoor, playerId)
    local hackLocationSpecial = SPECIAL_HACK_COORDS[locationIndex]
    local difficulty = 22  -- Specific difficulty for hack 4
    local rows = 3        -- Specific settings for hack 4
    local columns = 1
    

    HandleSpecialHackSequence(locationIndex, targetDoor, playerId, hackLocationSpecial, difficulty, rows, columns)
end

-- Handle special hack for location 5
function HandleSpecialHack5(locationIndex, targetDoor, playerId)
    local hackLocationSpecial = SPECIAL_HACK_COORDS[locationIndex]
    local difficulty = 25 -- Higher difficulty for hack 5
    local rows = 3       -- More complex grid for hack 5
    local columns = 1
    

    HandleSpecialHackSequence(locationIndex, targetDoor, playerId, hackLocationSpecial, difficulty, rows, columns)
end

-- Common special hack sequence for locations 4 and 5
function HandleSpecialHackSequence(locationIndex, targetDoor, playerId, hackLocationSpecial, difficulty, rows, columns)
    local playerPed = PlayerPedId()
    local animDict = 'anim@heists@ornate_bank@hack'
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(100)
    end

    -- Setup phase
    local props = SetupHackingProps(playerPed, hackLocationSpecial)
    
    -- Enter animation
    PlayHackEnterAnimation(playerPed, props, hackLocationSpecial, animDict)
    
    -- Main hacking loop
    local netScene2 = PlayHackLoopAnimation(playerPed, props, hackLocationSpecial, animDict)

    -- Start hacking minigame
    local hackingInProgress = true
    exports['hacking']:OpenHackingGame(difficulty, rows, columns, function(Success)
        hackingInProgress = false
        if Success then
            HandleHackSuccess(locationIndex, targetDoor, playerId)
        else
            HandleHackFailure(locationIndex, playerId)
        end
    end)

    while hackingInProgress do
        Wait(100)
    end

    -- Cleanup phase
    PlayHackExitAnimation(playerPed, props, hackLocationSpecial, animDict)
    CleanupHackingScene(props, playerPed, animDict)
end

-- Helper functions for special hacks
function SetupHackingProps(playerPed, hackLocationSpecial)
    SetEntityCoords(playerPed, hackLocationSpecial.coords.x, hackLocationSpecial.coords.y, hackLocationSpecial.coords.z - 1.0, false, false, false, true)
    SetEntityHeading(playerPed, hackLocationSpecial.heading)

    return {
        laptop = CreateObject(`hei_prop_hst_laptop`, hackLocationSpecial.coords.x, hackLocationSpecial.coords.y, hackLocationSpecial.coords.z, true, true, false),
        bag = CreateObject(`hei_p_m_bag_var22_arm_s`, hackLocationSpecial.coords.x, hackLocationSpecial.coords.y, hackLocationSpecial.coords.z, true, true, false)
    }
end

function PlayHackEnterAnimation(playerPed, props, hackLocationSpecial, animDict)
    local netScene = NetworkCreateSynchronisedScene(hackLocationSpecial.coords.x, hackLocationSpecial.coords.y, hackLocationSpecial.coords.z, 0.0, 0.0, hackLocationSpecial.heading, 2, false, false, 1.0, 0, 1.3)
    NetworkAddPedToSynchronisedScene(playerPed, netScene, animDict, "hack_enter", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(props.bag, netScene, animDict, "hack_enter_bag", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(props.laptop, netScene, animDict, "hack_enter_laptop", 4.0, -8.0, 1)
    NetworkStartSynchronisedScene(netScene)
    Wait(6000)
end

function PlayHackLoopAnimation(playerPed, props, hackLocationSpecial, animDict)
    local netScene = NetworkCreateSynchronisedScene(hackLocationSpecial.coords.x, hackLocationSpecial.coords.y, hackLocationSpecial.coords.z, 0.0, 0.0, hackLocationSpecial.heading, 2, false, true, 1.0, 0, 1.3)
    NetworkAddPedToSynchronisedScene(playerPed, netScene, animDict, "hack_loop", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(props.bag, netScene, animDict, "hack_loop_bag", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(props.laptop, netScene, animDict, "hack_loop_laptop", 4.0, -8.0, 1)
    NetworkStartSynchronisedScene(netScene)
    return netScene
end

function PlayHackExitAnimation(playerPed, props, hackLocationSpecial, animDict)
    local netScene = NetworkCreateSynchronisedScene(hackLocationSpecial.coords.x, hackLocationSpecial.coords.y, hackLocationSpecial.coords.z, 0.0, 0.0, hackLocationSpecial.heading, 2, false, false, 1.0, 0, 1.3)
    NetworkAddPedToSynchronisedScene(playerPed, netScene, animDict, "hack_exit", 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(props.bag, netScene, animDict, "hack_exit_bag", 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(props.laptop, netScene, animDict, "hack_exit_laptop", 4.0, -8.0, 1)
    NetworkStartSynchronisedScene(netScene)
    Wait(4500)
end

function CleanupHackingScene(props, playerPed, animDict)
    DeleteObject(props.laptop)
    DeleteObject(props.bag)
    ClearPedTasks(playerPed)
    RemoveAnimDict(animDict)
end

RegisterNetEvent('vault:client:UpdateDoorState', function(doorId, state)
    local door = VAULT_DOORS[doorId]
    if not door then return end
    
    local doorObject = GetClosestObjectOfType(
        door.coords.x,
        door.coords.y,
        door.coords.z,
        2.0,
        door.hash,
        false,
        false,
        false
    )
    
    if doorObject and DoesEntityExist(doorObject) then
        if state == "open" then
            -- Add a slight delay to match the sound
            Wait(500)
            SetEntityHeading(doorObject, door.coords.w + 90.0)
            FreezeEntityPosition(doorObject, false)
        else
            SetEntityHeading(doorObject, door.coords.w)
            FreezeEntityPosition(doorObject, true)
        end
    end
end)

-- Success/Failure handlers
function HandleHackSuccess(locationIndex, targetDoor, playerId)
    failedAttempts[playerId] = 0
    
    -- Play success sound
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'door-unlock', 0.3)
    
    -- Sync only the doors for this specific hack location
    Wait(500)
    TriggerServerEvent('vault:syncDoorState', "open", locationIndex)
    
    QBCore.Functions.Notify("Vault door successfully hacked!", "success")

    -- Only spawn trolleys if this was the final hack
    if locationIndex == #HACK_LOCATIONS then
        -- Initialize trolley tables
        trollies = {}
        trollies[currentBank] = {}

        -- Spawn trolleys only after final hack
        for index, trolleyInfo in pairs(Config.Vault[currentBank].trolly) do
            local trolley = SpawnTrolleyProp(trolleyInfo.coords, trolleyInfo.type)
            trollies[currentBank][index] = trolley

            -- Add target interaction with corrected setup
            exports['qb-target']:AddTargetEntity(trolley, {
                options = {
                    {
                        num = 1,
                        type = "client",
                        event = "vault:client:LootTrolly",
                        icon = "fas fa-hand-holding",
                        label = "Loot Trolley",
                        bank = currentBank,
                        index = index,
                        entity = trolley
                    }
                },
                distance = 1.5
            })
        end

        QBCore.Functions.Notify("Security systems breached! Trolleys exposed!", "success")
    end

    RemoveHackZone("vault_hack_" .. locationIndex)
end

-- Spawn trolleys and set targets dynamically
local function SpawnTrolleys()
    trollies = {}
    trollies[currentBank] = {}

    for index, trolleyInfo in pairs(Config.Vault[currentBank].trolly) do
        local trolleyModel = `ch_prop_cash_low_trolly_01`
        lib.requestModel(trolleyModel)
        local trolley = CreateObject(trolleyModel, trolleyInfo.coords.x, trolleyInfo.coords.y, trolleyInfo.coords.z, true, true, false)
        SetEntityHeading(trolley, trolleyInfo.coords.w)
        trollies[currentBank][index] = trolley

        -- Add interaction zone for each trolley
        exports['qb-target']:AddTargetEntity(trolley, {
            options = {
                {
                    type = "client",
                    event = "vault:client:LootTrolly",
                    icon = "fas fa-hand-holding",
                    label = "Loot Trolley",
                    args = { bank = currentBank, index = index }
                }
            },
            distance = 1.5
        })
    end

    QBCore.Functions.Notify("Trolleys have appeared!", "success")
end


function HandleHackFailure(locationIndex, playerId)
    failedAttempts[playerId] = failedAttempts[playerId] + 1
    local attemptsLeft = 4 - failedAttempts[playerId]

    if failedAttempts[playerId] >= 4 then
        failedAttempts[playerId] = 0
        TriggerServerEvent('vault:removeHackItem', Config.HackItems[locationIndex].item, 1)
        QBCore.Functions.Notify("You failed too many times! Device removed.", "error")
    else
        QBCore.Functions.Notify("Hack failed! Attempts left: " .. attemptsLeft, "error")
    end
end


local function numberSlide(iterations, difficulty, numberOfKeys)
    local promise = promise:new()

    ---@type KeyDifficultyConfig
    local config = {
        difficulty = difficulty or 50,
        numberOfKeys = numberOfKeys or 5,
    }

    local result = StartGame(GameTypes.numberSlide, iterations, config)
    promise:resolve(result)

    return Citizen.Await(promise)
end
exports("NumberSlide", numberSlide)

local function digitDazzle(iterations, config)
    local promise = promise:new()

    local result = StartGame(GameTypes.digitDazzle, iterations, config)
    promise:resolve(result)

    return Citizen.Await(promise)
end
exports("DigitDazzle", digitDazzle)

local function wordWiz(iterations, config)
    local promise = promise:new()
    
    local result = StartGame(GameTypes.wordWiz, iterations, config)
    promise:resolve(result)
    
    return Citizen.Await(promise)
end

exports("WordWiz", wordWiz)



LootTrolly = function(trolly, bank, index)
    local ped = cache.ped

    local moneyModel = `hei_prop_heist_cash_pile`
    if Config.Vault[bank].trolly[index].type == 'gold' then 
        moneyModel = `ch_prop_gold_bar_01a` 
    end

    local CurrentTrolly = trolly
    local netId = NetworkGetNetworkIdFromEntity(CurrentTrolly)

    local MoneyObject = CreateObject(moneyModel, GetEntityCoords(ped), true)
    SetEntityVisible(MoneyObject, false, false)
    AttachEntityToEntity(MoneyObject, ped, GetPedBoneIndex(ped, 60309), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 0, true)
    
    lib.requestModel(`hei_p_m_bag_var22_arm_s`)
    local GrabBag = CreateObject(`hei_p_m_bag_var22_arm_s`, GetEntityCoords(ped), true, false, false)
    SetModelAsNoLongerNeeded(`hei_p_m_bag_var22_arm_s`)
    
    local GrabOne = NetworkCreateSynchronisedScene(GetEntityCoords(CurrentTrolly), GetEntityRotation(CurrentTrolly), 2, false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, GrabOne, 'anim@heists@ornate_bank@grab_cash', 'intro', 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(GrabBag, GrabOne, 'anim@heists@ornate_bank@grab_cash', 'bag_intro', 4.0, -8.0, 1)
    SetPedComponentVariation(ped, 5, 0, 0, 0)
    
    NetworkStartSynchronisedScene(GrabOne)
    Wait(1500)
    SetEntityVisible(MoneyObject, true, true)
    
    local GrabTwo = NetworkCreateSynchronisedScene(GetEntityCoords(CurrentTrolly), GetEntityRotation(CurrentTrolly), 2, false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, GrabTwo, 'anim@heists@ornate_bank@grab_cash', 'grab', 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(GrabBag, GrabTwo, 'anim@heists@ornate_bank@grab_cash', 'bag_grab', 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(CurrentTrolly, GrabTwo, 'anim@heists@ornate_bank@grab_cash', 'cart_cash_dissapear', 4.0, -8.0, 1)
    
    NetworkStartSynchronisedScene(GrabTwo)
    Wait(37000)
    SetEntityVisible(MoneyObject, false, false)
    
    local GrabThree = NetworkCreateSynchronisedScene(GetEntityCoords(CurrentTrolly), GetEntityRotation(CurrentTrolly), 2, false, false, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(ped, GrabThree, 'anim@heists@ornate_bank@grab_cash', 'exit', 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(GrabBag, GrabThree, 'anim@heists@ornate_bank@grab_cash', 'bag_exit', 4.0, -8.0, 1)
    
    NetworkStartSynchronisedScene(GrabThree)

    Wait(1800)

    DeleteEntity(GrabBag)
    DeleteObject(MoneyObject)
    
    -- Delete the original trolley
    DeleteEntity(CurrentTrolly)

    -- Spawn the new empty trolley model
    lib.requestModel(`hei_prop_hei_cash_trolly_03`)
    local newTrolley = CreateObject(`hei_prop_hei_cash_trolly_03`, Config.Vault[bank].trolly[index].coords.x, Config.Vault[bank].trolly[index].coords.y, Config.Vault[bank].trolly[index].coords.z, true, true, false)
    SetEntityHeading(newTrolley, Config.Vault[bank].trolly[index].coords.w)
    FreezeEntityPosition(newTrolley, true)
    SetEntityAsMissionEntity(newTrolley, true, true)

    -- Mark the trolley as taken
    TriggerServerEvent('vault:server:SetTrollyTaken', bank, index)

    -- Add Loosenotes Reward
if Config.Vault[bank].trolly[index].type == 'money' then
    local rewardConfig = Config.Rewards.Trollys['money'].vault.loosenotes
    local loosenotesAmount = math.random(rewardConfig.minAmount, rewardConfig.maxAmount)
    
    -- Trigger event to give loosenotes reward
    TriggerServerEvent('vault:giveReward', 'item', 'loosenotes', loosenotesAmount)
    
    -- Notify player about loosenotes
    QBCore.Functions.Notify(string.format("You found %d loosenotes!", loosenotesAmount), "success")
end

end


-- Register the drilling event
RegisterNetEvent('spot:startDrilling', function(data)
    -- Get the spot ID from the data
    local spotId = data.spotId
    
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    -- Check if player has drill item
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasDrill)
        if not hasDrill then
            QBCore.Functions.Notify("You need a drill to do this!", "error")
            return
        end
        
        -- Create Drill and Attach
        local drillObjectModel = joaat('hei_prop_heist_drill')
        lib.requestModel(drillObjectModel)
        local DrillObject = CreateObject(drillObjectModel, pos.x, pos.y, pos.z, true, true, true)
        SetModelAsNoLongerNeeded(drillObjectModel)
        AttachEntityToEntity(DrillObject, ped, GetPedBoneIndex(ped, 57005), 0.14, 0, -0.01, 90.0, -90.0, 180.0, true, true, false, true, 1, true)

        -- Play Drilling Animation
        lib.playAnim(ped, 'anim@heists@fleeca_bank@drilling', 'drill_straight_idle', 3.0, 3.0, -1, 1, 0, false, false, false)

        -- Drilling State
        local isDrilling = true

        -- Load and Play Drilling Sound
        RequestScriptAudioBank('DLC_HEIST_FLEECA_SOUNDSET', false)
        local soundId = GetSoundId()
        PlaySoundFromEntity(soundId, 'Drill', DrillObject, 'DLC_HEIST_FLEECA_SOUNDSET', true, 0)

        -- Drilling Dust Effect
        CreateThread(function()
            lib.requestNamedPtfxAsset('core')
            while isDrilling do
                UseParticleFxAssetNextCall('core')
                local drillObjectCoords = GetEntityCoords(DrillObject)
                StartNetworkedParticleFxNonLoopedAtCoord('ent_dst_rocks', drillObjectCoords.x, drillObjectCoords.y, drillObjectCoords.z, 0.0, 0.0, GetEntityHeading(ped) - 180.0, 1.0, 0.0, 0.0, 0.0)
                Wait(600)
            end
            RemoveNamedPtfxAsset('core')
        end)

        -- Progress Bar
        QBCore.Functions.Progressbar("drilling", "Drilling...", 10000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Success callback
            isDrilling = false

            -- Cleanup after Drilling
            StopAnimTask(ped, 'anim@heists@fleeca_bank@drilling', 'drill_straight_idle', 1.0)
            StopSound(soundId)
            ReleaseSoundId(soundId)
            ReleaseScriptAudioBank()
            DeleteEntity(DrillObject)

            -- Randomly select reward
            local rewards = { 'rolex', 'loosenotes', 'cubanchain' }
            local reward = rewards[math.random(1, #rewards)]
            local amount = math.random(10, 20)

            -- Give reward
            TriggerServerEvent('QBCore:Server:AddItem', reward, amount)
            TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items[reward], 'add')
            QBCore.Functions.Notify("You received " .. amount .. " " .. reward .. "!", "success")

            -- Remove the drill spot interaction
            exports['qb-target']:RemoveZone(spotId)
            
            -- Update server about drilled spot
            TriggerServerEvent('vault:server:SetSpotDrilled', spotId)

        end, function() -- Cancel callback
            isDrilling = false

            -- Cleanup on cancellation
            StopAnimTask(ped, 'anim@heists@fleeca_bank@drilling', 'drill_straight_idle', 1.0)
            StopSound(soundId)
            ReleaseSoundId(soundId)
            ReleaseScriptAudioBank()
            DeleteEntity(DrillObject)
            QBCore.Functions.Notify("Drilling canceled.", "error")
        end)
    end, "drill")
end)

Citizen.CreateThread(function()
    local drillingSpots = {
        { id = "drill_spot_244", coords = vector3(244.22, -1107.29, 28.34) },
        { id = "drill_spot_246", coords = vector3(246.20, -1106.22, 28.36) },
        { id = "drill_spot_248", coords = vector3(248.68, -1101.00, 28.36) },
        { id = "drill_spot_249", coords = vector3(249.76, -1102.97, 28.36) },
        { id = "drill_spot_240", coords = vector3(240.57, -1106.04, 28.34) },
        { id = "drill_spot_238", coords = vector3(238.65, -1107.26, 28.31) }
    }

    -- Get already drilled spots from server
    QBCore.Functions.TriggerCallback('vault:server:GetDrilledSpots', function(drilledSpots)
        for _, spot in ipairs(drillingSpots) do
            -- Only create zones for spots that haven't been drilled
            if not drilledSpots[spot.id] then
                exports['qb-target']:AddBoxZone(spot.id, spot.coords, 1.0, 1.0, {
                    name = spot.id,
                    heading = 0,
                    debugPoly = false,
                    minZ = spot.coords.z - 0.5,
                    maxZ = spot.coords.z + 0.5,
                }, {
                    options = {
                        {
                            type = "client",
                            event = "spot:startDrilling",
                            icon = "fas fa-wrench",
                            label = "Drill Spot",
                            spotId = spot.id -- Pass the spot ID in the data
                        }
                    },
                    distance = 1.0
                })
            end
        end
    end)
end)

-- Listen for updates to drilled spots from server
RegisterNetEvent('vault:client:UpdateDrilledSpots', function(spotId)
    exports['qb-target']:RemoveZone(spotId)
end)

-- Handle vault reset
RegisterNetEvent('vault:client:ResetDrilledSpots', function()
    -- Recreate all drilling spots
    Citizen.CreateThread(function()
        local drillingSpots = {
            { id = "drill_spot_244", coords = vector3(244.22, -1107.29, 28.34) },
            { id = "drill_spot_246", coords = vector3(246.20, -1106.22, 28.36) },
            { id = "drill_spot_248", coords = vector3(248.68, -1101.00, 28.36) },
            { id = "drill_spot_249", coords = vector3(249.76, -1102.97, 28.36) },
            { id = "drill_spot_240", coords = vector3(240.57, -1106.04, 28.34) },
            { id = "drill_spot_238", coords = vector3(238.65, -1107.26, 28.31) }
        }

        for _, spot in ipairs(drillingSpots) do
            exports['qb-target']:AddBoxZone(spot.id, spot.coords, 1.0, 1.0, {
                name = spot.id,
                heading = 0,
                debugPoly = false,
                minZ = spot.coords.z - 0.5,
                maxZ = spot.coords.z + 0.5,
            }, {
                options = {
                    {
                        type = "client",
                        event = "spot:startDrilling",
                        icon = "fas fa-wrench",
                        label = "Drill Spot",
                        spotId = spot.id
                    }
                },
                distance = 1.0
            })
        end
    end)
end)


-- Spawn trolleys when the resource starts
CreateThread(SpawnTrolleys)


RegisterNetEvent('vault:client:SetTrollyTaken', function(bank, index)
    if Config.Vault[bank] and Config.Vault[bank].trolly[index] then
        Config.Vault[bank].trolly[index].taken = true
    end
end)

function SetTrollyState(bank, index, state)
    if Config.Vault[bank] and Config.Vault[bank].trolly[index] then
        Config.Vault[bank].trolly[index].taken = state.taken or false
        Config.Vault[bank].trolly[index].busy = state.busy or false
        TriggerClientEvent('vault:client:UpdateTrollyState', -1, bank, index, state)
    end
end


function requestModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end
end


if not IsModelValid(model) then
    print("Invalid model, falling back to default trolley.")
    model = `hei_prop_hei_cash_trolly_01` -- Fallback to money trolley
end


function SpawnTrolleyProp(coords, type)
    local model = `hei_prop_hei_cash_trolly_01` -- Default to money
    if type == 'gold' then
        model = `ch_prop_gold_trolly_01a`
    end

    print("Spawning trolley of type:", type, "with model:", model)

    -- Request the model
    requestModel(model)
    if not IsModelValid(model) then
        print("Invalid model detected, falling back to default model.")
        model = `hei_prop_hei_cash_trolly_01`
    end

    -- Spawn trolley
    local trolley = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityHeading(trolley, coords.w)
    FreezeEntityPosition(trolley, true)
    SetEntityAsMissionEntity(trolley, true, true)
    SetModelAsNoLongerNeeded(model)

    return trolley
end

RegisterNetEvent('vault:client:LootTrolly', function(data)
    local trolly = data.entity
    if not trolly then return end
    
    local pos = GetEntityCoords(trolly)
    local bank = 'vault' -- Since we're working with the vault bank
    
    for k, v in pairs(Config.Vault[bank].trolly) do
        if #(pos - v.coords.xyz) < 1.0 then
            if v.busy or v.taken then
                QBCore.Functions.Notify("Trolley already looted or in use.", "error")
                return 
            end
            
            -- Set trolley as busy
            TriggerServerEvent('vault:server:SetTrollyBusy', bank, k)
            LocalPlayer.state.inv_busy = true
            
            -- Start loot animation and process
            LootTrolly(trolly, bank, k)
            
            LocalPlayer.state.inv_busy = false
            break
        end
    end
end)

-- Add target interactions for all hack locations
Citizen.CreateThread(function()
    for i, location in ipairs(HACK_LOCATIONS) do
        local zoneId = "vault_hack_" .. i
        activeHackZones[zoneId] = true
        
        exports['qb-target']:AddBoxZone(zoneId, location.coords, 1.0, 1.0, {
            name = zoneId,
            heading = 0,
            debugPoly = false,
            minZ = location.coords.z - 1,
            maxZ = location.coords.z + 1,
        }, {
            options = {
                {
                    type = "client",
                    event = "vault:attemptHack",
                    icon = "fas fa-laptop-code",
                    label = location.label,
                    locationIndex = i
                }
            },
            distance = 0.73
        })
    end
end)

exports['qb-target']:AddTargetModel({`hei_prop_hei_cash_trolly_01`, `ch_prop_gold_trolly_01a`}, {
    options = {
        {
            type = 'client',
            event = 'vault:client:LootTrolly', -- Changed from bankrobbery:client:LootTrolly
            icon = 'fas fa-hand-holding',
            label = 'Loot Trolley',
            canInteract = function(entity)
                -- Add proper checks for trolley state
                local pos = GetEntityCoords(entity)
                for bank, data in pairs(Config.Vault) do
                    for k, v in pairs(data.trolly) do
                        if #(pos - v.coords.xyz) < 1.0 then
                            return not v.taken and not v.busy
                        end
                    end
                end
                return false
            end
        }
    },
    distance = 1.5
})

-- Export the Untangle function
exports("Untangle", function(iterations, config)
    return exports.bl_ui:Untangle(iterations, config)
end)