-- Lojas vindas do servidor (server/stores.lua, editadas pelo painel). Substituem
-- o Config.Stores e refazem zonas, blips e target na hora. Ver STORES.md.

local function toVectors(store)
    local out = {}
    for k, v in pairs(store) do out[k] = v end
    local c, s = store.coords, store.size
    out.coords = vector4(c.x, c.y, c.z, c.w)
    out.size = vector3(s.x, s.y, s.z)
    if store.points then
        out.points = {}
        for i, p in ipairs(store.points) do out.points[i] = vector3(p.x, p.y, p.z) end
    end
    return out
end

local raw = {} ---@type table[]

local function apply(list)
    if type(list) ~= 'table' then return end
    raw = list
    local converted = {}
    for i, store in ipairs(list) do converted[i] = toVectors(store) end

    -- Zonas/target removem pelos índices da lista velha: tira antes de trocar.
    if RemoveStoreZones then RemoveStoreZones() end
    if RemoveStoreTargets then RemoveStoreTargets() end

    Config.Stores = converted

    if SetupStoreZonesNow then SetupStoreZonesNow() end
    if SetupStoreTargetsNow then SetupStoreTargetsNow() end
    if ResetBlips then ResetBlips() end
end

RegisterNetEvent('mri_Qappearance:stores:changed', apply)

CreateThread(function()
    apply(lib.callback.await('mri_Qappearance:stores:get', false))
end)

--------------------------------------------------------------------------------
-- Painel (aba Lojas)
--------------------------------------------------------------------------------

RegisterNUICallback('stores_list', function(_, cb)
    cb({ ok = true, stores = raw, groups = lib.callback.await('mri_Qappearance:stores:groups', false) })
end)

RegisterNUICallback('stores_save', function(data, cb)
    local ok, result = lib.callback.await('mri_Qappearance:stores:save', false, type(data) == 'table' and data.store)
    cb(ok and { ok = true, store = result } or { err = result or 'não foi possível salvar' })
end)

RegisterNUICallback('stores_delete', function(data, cb)
    local ok = lib.callback.await('mri_Qappearance:stores:delete', false, type(data) == 'table' and data.id)
    cb(ok and { ok = true } or { err = 'não foi possível apagar' })
end)

RegisterNUICallback('stores_teleport', function(data, cb)
    local ok = lib.callback.await('mri_Qappearance:stores:teleport', false, type(data) == 'table' and data.id)
    cb(ok and { ok = true } or { err = 'não foi possível teleportar' })
end)

---Posição e direção do jogador, pra criar/mover uma loja onde ele está.
RegisterNUICallback('stores_here', function(_, cb)
    local coords = GetEntityCoords(cache.ped)
    cb({ ok = true, coords = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(cache.ped) } })
end)
