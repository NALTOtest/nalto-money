local QBCore = exports['qb-core']:GetCoreObject()

local drilledSpots = {}
local completedHacks = {}
local hackCooldowns = {}

local function getCops(callback)
    local cops = 0
    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Config.Police.jobs[Player.PlayerData.job.name] and Player.PlayerData.job.onduty then
            cops = cops + 1
        end
    end
    callback(cops)
end

RegisterServerEvent('vault:server:getCops')
AddEventHandler('vault:server:getCops', function(cb)
    getCops(function(cops)
        cb(cops)
    end)
end)

QBCore.Functions.CreateCallback('vault:server:getCops', function(source, cb)
    getCops(cb)
end)

local function updateDoorState(doorId, state, source)
    if Config.Doorlock == 'ox_doorlock' then
        state = state and 1 or 0
        exports['ox_doorlock']:setDoorState(exports['ox_doorlock']:getDoorFromName(doorId).id, state)
    elseif Config.Doorlock == 'qb-doorlock' then
        TriggerEvent('qb-doorlock:server:updateState', doorId, false, false, false, true, false, false, source)
    end
end

RegisterNetEvent('vault:syncDoorState', function(state, hackIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    -- Count cops synchronously
    local cops = 0
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if Config.Police.jobs[v.PlayerData.job.name] and v.PlayerData.job.onduty then
            cops = cops + 1
        end
    end

    -- Check police requirements
    if Config.Police.required and cops < Config.Police.minimumCount then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough police in the city!', 'error')
        return
    end

    -- Define which doors should open for each hack
    local doorMapping = {
        [1] = {'Vault bank door 1'}, -- First hack opens first door
        [2] = {'Vault bank door 2'}, -- Second hack opens second door
        [3] = {'Vault bank door 3'}, -- Third hack opens third door
        [4] = {'Vault bank vault 1'}, -- First laptop hack opens doors 4 and 5
        [5] = {'Vault bank vault 2', 'Vault bank vault 3'} -- Second laptop hack opens door 6
    }

    local doorsToUpdate = doorMapping[hackIndex]
    if not doorsToUpdate then 
        print("[DEBUG] No doors mapped for hackIndex:", hackIndex)
        return 
    end

    -- Update only the specific doors for this hack
    for _, doorId in ipairs(doorsToUpdate) do
        if Config.Doorlock == 'ox_doorlock' then
            local doorData = exports.ox_doorlock:getDoorFromName(doorId)
            if doorData then
                local newState = state == "open" and 0 or 1
                exports.ox_doorlock:setDoorState(doorData.id, newState)
                print("[DEBUG] Door updated via ox_doorlock:", doorId, "State:", newState)
            else
                print("[ERROR] Door not found in ox_doorlock:", doorId)
            end
        elseif Config.Doorlock == 'qb-doorlock' then
            TriggerEvent('qb-doorlock:server:updateState', doorId, false, false, false, true, false, false, src)
            print("[DEBUG] Door updated via qb-doorlock:", doorId)
        end

        -- Broadcast the state change to all clients
        TriggerClientEvent('vault:client:UpdateDoorState', -1, doorId, state)
    end
end)

-- Optional: Add interaction to close the door
RegisterNetEvent('vault:closeVaultDoor', function()
    if QBCore.Functions.GetPlayerData().job.name == 'police' or 
       QBCore.Functions.GetPlayerData().job.name == 'admin' then
        ManageVaultDoor("close")
        QBCore.Functions.Notify("Vault door secured", "primary")
    else
        QBCore.Functions.Notify("You're not authorized", "error")
    end
end)

RegisterNetEvent('vault:giveReward', function(type, value, quantity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- Check police count before giving rewards
    if Config.Police.required then
        local cops = 0
        for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
            if Config.Police.jobs[v.PlayerData.job.name] then
                cops = cops + 1
            end
        end
        
        if cops < Config.Police.minimumCount then
            TriggerClientEvent('QBCore:Notify', src, 'Not enough police in the city!', 'error')
            return
        end
    end
    
    if type == 'item' and value then
        if QBCore.Shared.Items[value] then
            Player.Functions.AddItem(value, quantity)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[value], 'add')
        else
            TriggerClientEvent('QBCore:Notify', src, "Item not found: " .. value, "error", 5000)
        end
    elseif type == 'money' and value then
        Player.Functions.AddMoney('cash', value)
    end
end)

RegisterNetEvent('vault:updateLaptopDurability', function(laptopItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Get the laptop item with metadata
    local laptop = Player.Functions.GetItemByName(laptopItem)
    if laptop then
        -- Get current durability or set default
        local durability = laptop.info.durability or Config.LaptopDurability[laptopItem]
        durability = durability - 1

        if durability <= 0 then
            -- Remove broken laptop
            Player.Functions.RemoveItem(laptopItem, 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[laptopItem], "remove")
            TriggerClientEvent('QBCore:Notify', src, "Your laptop has broken!", "error")
        else
            -- Update durability
            laptop.info.durability = durability
            Player.Functions.UpdateItemInfo(laptop.slot, laptop.info)
            TriggerClientEvent('QBCore:Notify', src, string.format("Laptop durability: %d uses remaining", durability), "primary")
        end
    end
end)

RegisterNetEvent('vault:removeHackItem', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        Player.Functions.RemoveItem(item, amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove")
    end
end)

QBCore.Functions.CreateUseableItem("drill", function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    TriggerClientEvent("QBCore:Notify", source, "Find a drilling spot to use this", "primary")
end)

QBCore.Functions.CreateCallback('QBCore:HasItem', function(source, cb, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local hasItem = Player.Functions.GetItemByName(item)
    cb(hasItem ~= nil)
end)

RegisterNetEvent('vault:giveLaptop', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local info = {
            durability = Config.LaptopDurability.green_laptop
        }
        Player.Functions.AddItem('green_laptop', 1, false, info)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['green_laptop'], "add")
    end
end)

RegisterNetEvent('QBCore:Server:AddItem', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        -- Add the item to the player's inventory
        Player.Functions.AddItem(item, amount)
        -- Notify the client-side inventory to show the item box
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', amount)
    else
        print("Player not found!")
    end
end)

RegisterNetEvent('vault:server:SetSpotDrilled', function(spotId)
    drilledSpots[spotId] = true
    -- Broadcast to all clients that this spot has been drilled
    TriggerClientEvent('vault:client:UpdateDrilledSpots', -1, spotId)
end)

-- Reset drilled spots (you can call this when resetting the vault)
RegisterNetEvent('vault:server:ResetDrilledSpots', function()
    drilledSpots = {}
    TriggerClientEvent('vault:client:ResetDrilledSpots', -1)
end)

-- Callback to check drill spots status
QBCore.Functions.CreateCallback('vault:server:GetDrilledSpots', function(source, cb)
    cb(drilledSpots)
end)

RegisterNetEvent('vault:AddLoosenotes', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        Player.Functions.AddItem('loosenotes', amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['loosenotes'], "add", amount)
    end
end)

RegisterNetEvent('vault:server:SetTrollyBusy', function(bank, index)
    Config.Vault[bank].trolly[index].busy = true
    TriggerClientEvent('vault:client:SetTrollyBusy', -1, bank, index)
end)

RegisterNetEvent('vault:server:SetTrollyTaken', function(bank, index)
    Config.Vault[bank].trolly[index].taken = true
    TriggerClientEvent('vault:client:SetTrollyTaken', -1, bank, index)
end)

RegisterCommand('resetTrolleys', function(source)
    for bank, data in pairs(Config.Vault) do
        for index, trolly in pairs(data.trolly) do
            trolly.taken = false
            trolly.busy = false
        end
    end
    TriggerClientEvent('vault:client:ResetTrolleys', -1)
    print('All trolleys have been reset.')
end, true)


-- Function to check if a hack is completed
local function isHackCompleted(locationIndex)
    return completedHacks[locationIndex] == true
end

-- Function to mark a hack as completed
local function markHackCompleted(locationIndex)
    completedHacks[locationIndex] = true
    -- Broadcast the completion to all clients
    TriggerClientEvent('vault:client:DisableHackLocation', -1, locationIndex)
end

-- Function to reset all hacks (useful for server restarts or resets)
local function resetAllHacks()
    completedHacks = {}
    hackCooldowns = {}
    TriggerClientEvent('vault:client:ResetAllHacks', -1)
end

-- Register server events
RegisterServerEvent('vault:server:CheckHackState')
AddEventHandler('vault:server:CheckHackState', function(locationIndex)
    local src = source
    if isHackCompleted(locationIndex) then
        TriggerClientEvent('QBCore:Notify', src, 'This system has already been breached.', 'error')
        TriggerClientEvent('vault:client:DisableHackLocation', src, locationIndex)
        return false
    end
    return true
end)

RegisterServerEvent('vault:server:CompleteHack')
AddEventHandler('vault:server:CompleteHack', function(locationIndex)
    markHackCompleted(locationIndex)
end)

-- Add callback to get initial hack states when player loads in
QBCore.Functions.CreateCallback('vault:server:GetHackStates', function(source, cb)
    cb(completedHacks)
end)