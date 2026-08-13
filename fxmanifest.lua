fx_version 'cerulean'
game       'gta5'
lua54      'yes'
author     'DPS Development'
description 'Police NPC Interaction System with Intel Trading and Jail System'
version    '2.1.1'

-- Dependencies
-- Required: qbx_core, ox_lib, ox_target, ox_inventory, oxmysql
-- Optional: dps-ainpcs (for AI dialogue), a dispatch/MDT resource (wasabi_mdt/ps-dispatch/cd_dispatch)
-- Run sql/jail_records.sql if using the jail system

shared_scripts {
    '@ox_lib/init.lua',
    'shared/characters.lua', -- Shared character pool (can be used by dps-ainpcs)
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- Required if jail system enabled
    'server.lua'
}

client_scripts {
    'client.lua'
}

files {
    'stream/idcard.ytd'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'oxmysql'
}
