Config = Config or {}

Config.Police = {
    required = true,
    minimumCount = 3, -- Set to your desired minimum cop count
    jobs = {
        ["police"] = true,
        ["sheriff"] = true
    }
}

local Config = {
    Vaulthack = {
        iterations = 1,      
        numberOfNodes = 11,  
        duration = 13        
    }
}

Config.Banks = Config.Banks or {}

Config.Banks['vault'] = {
    type = 'vault',
    trolly = {
        [1] = { coords = vector4(242.76, -1106.15, 27.49, 278.38), type = 'money', taken = false, busy = false },
        [2] = { coords = vector4(237.41, -1105.98, 27.49, 261.67), type = 'money', taken = false, busy = false }
    }
}

Rewards = {
    Trollys = {
        ['money'] = { 
            vault = { 
                loosenotes = {
                    minAmount = 500,      
                    maxAmount = 700       
                }
            },
        },
        ['gold'] = { 
            vault = { 
                minAmount = 1,            
                maxAmount = 5,            
                itemName = 'goldbar'      
            },
        }
    }
}