local QBCore = exports['qb-core']:GetCoreObject()

local drilledSpots = {}

QBCore.Functions.CreateCallback('robbery:server:getCops', function(source, cb)
    local cops = 0
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if Config.Police.jobs[v.PlayerData.job.name] then
            cops = cops + 1
        end
    end
    cb(cops)
end)

RegisterNetEvent('vault:syncDoorState', function(state)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- Debug print
    print("Checking police count for vault sync...")
    
    if Config.Police.required then
        local cops = 0
        for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
            if Config.Police.jobs[v.PlayerData.job.name] and v.PlayerData.job.onduty then
                cops = cops + 1
                -- Debug print
                print("Found officer in sync check: " .. v.PlayerData.job.name)
            end
        end
        
        print("Required cops: " .. Config.Police.minimumCount .. " | Current cops: " .. cops)
        
        if cops < Config.Police.minimumCount then
            TriggerClientEvent('QBCore:Notify', src, 'Not enough police in the city! (' .. cops .. '/' .. Config.Police.minimumCount .. ')', 'error')
            return
        end
    end
    
    ManageVaultDoor(state)
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

RegisterNetEvent('bankrobbery:server:SetTrollyBusy', function(bank, index)
    Config.Banks[bank].trolly[index].busy = true
    TriggerClientEvent('bankrobbery:client:SetTrollyBusy', -1, bank, index)
end)

RegisterNetEvent('bankrobbery:server:SetTrollyTaken', function(bank, index)
    Config.Banks[bank].trolly[index].taken = true
    TriggerClientEvent('bankrobbery:client:SetTrollyTaken', -1, bank, index)
end)

RegisterCommand('resetTrolleys', function(source)
    for bank, data in pairs(Config.Banks) do
        for index, trolly in pairs(data.trolly) do
            trolly.taken = false
            trolly.busy = false
        end
    end
    TriggerClientEvent('bankrobbery:client:ResetTrolleys', -1)
    print('All trolleys have been reset.')
end, true)
