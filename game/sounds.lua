-- Sons de interface do menu de aparência (PlaySoundFrontend, sons nativos do GTA).
-- A NUI pede pelo nome (web/src/components/Appearance/sounds.ts); desliga com
-- Config.UISounds = false.

local SOUNDS = {
    change  = { "NAV_LEFT_RIGHT", "HUD_FRONTEND_DEFAULT_SOUNDSET" },
    select  = { "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET" },
    back    = { "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET" },
    tab     = { "Highlight_Move", "DLC_HEIST_PLANNING_BOARD_SOUNDS" },
    toggle  = { "TOGGLE_ON", "HUD_FRONTEND_DEFAULT_SOUNDSET" },
    camera  = { "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET" },
    tattoo  = { "PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET" },
    save    = { "WEAPON_PURCHASE", "HUD_AMMO_SHOP_SOUNDSET" },
    success = { "CHALLENGE_UNLOCKED", "HUD_AWARDS" },
    error   = { "ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET" },
}

local function play(name)
    local sound = SOUNDS[name]
    if Config.UISounds == false or not sound then return end
    PlaySoundFrontend(-1, sound[1], sound[2], true)
end

RegisterNUICallback("appearance_sound", function(name, cb)
    cb(1)
    play(name)
end)
