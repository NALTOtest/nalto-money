Config = {}

Config.Doorlock = 'ox_doorlock' -- or 'ox_doorlock'

Config.VaultDoors = {
    ['Vault bank door 1'] = 'Vault bank door 1', -- Door IDs should match your doorlock config
    ['Vault bank door 2'] = 'Vault bank door 2',
    ['Vault bank door 3'] = 'Vault bank door 3',
    ['Vault bank vault 1'] = 'Vault bank vault 1',
    ['Vault bank vault 2'] = 'Vault bank vault 2',
    ['Vault bank vault 3'] = 'Vault bank vault 3'
}

-- Police Configuration
Config.Police = {
    required = true,
    minimumCount = 0,
    jobs = {
        ["police"] = true,
        ["sheriff"] = true
    }
}

-- Vault Hack Configuration
Config.Vaulthack = {
    iterations = 1,
    numberOfNodes = 11,
    duration = 13,
    wordWizDuration = 30
}

-- Banks Configuration
Config.Banks = {
    ['vault'] = {
        type = 'vault',
        trolly = {
            [1] = {
                coords = vector4(242.76, -1106.15, 27.49, 278.38),
                type = 'money',
                taken = false,
                busy = false
            },
            [2] = {
                coords = vector4(237.41, -1105.98, 27.49, 261.67),
                type = 'money',
                taken = false,
                busy = false
            },
            [3] = {
                coords = vector4(248.17, -1104.12, 28.49, 317.02),
                type = 'money',
                taken = false,
                busy = false
            },
            [4] = {
                coords = vector4(242.77, -1106.07, 28.49, 278.38),
                type = 'money',
                taken = false,
                busy = false
            },
            [5] = {
                coords = vector4(237.62, -1105.68, 28.49, 219.06),
                type = 'money',
                taken = false,
                busy = false
            }
        }
    }
}

-- Rewards Configuration
Config.Rewards = {
    Trollys = {
        ['money'] = {
            vault = {
                loosenotes = {
                    minAmount = 500,
                    maxAmount = 700
                }
            }
        },
        ['gold'] = {
            vault = {
                minAmount = 1,
                maxAmount = 5,
                itemName = 'goldbar'
            }
        }
    }
}

-- Laptop Configuration
Config.LaptopDurability = {
    vaultlaptop = 3,  -- Number of uses before breaking
    green_laptop = 3
}

-- Hack Items Configuration
Config.HackItems = {
    -- First 3 hacks require trojan_usb - removed on success
    [1] = { item = "trojan_usb", removeOnSuccess = true },
    [2] = { item = "trojan_usb", removeOnSuccess = true },
    [3] = { item = "trojan_usb", removeOnSuccess = true },
    -- Last 2 hacks require vaultlaptop - uses durability system
    [4] = { item = "vaultlaptop", usesDurability = true },
    [5] = { item = "vaultlaptop", usesDurability = true }
}

