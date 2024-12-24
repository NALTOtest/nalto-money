fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'NALTO'
description 'Vault BANK Robbery For QBcore'
version '1.0.0'


server_scripts {
    'config.lua',
    'server.lua'
}


client_scripts {
    'config.lua',
    'client.lua'
}


dependencies {
    'qb-core',
    'qb-target'
}

shared_scripts {
    '@ox_lib/init.lua'
}



