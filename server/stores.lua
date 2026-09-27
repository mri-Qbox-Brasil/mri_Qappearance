-- Lojas de roupa, barbearias, tatuagem e cirurgia gerenciadas pelo painel
-- (/adminappearance e plugin do mri_Qadmin, aba Lojas). Ficam em stores.json;
-- na primeira vez o arquivo sai do Config.Stores. Depois disso o Config.Stores
-- não é mais lido. Ver STORES.md.

local RESOURCE = GetCurrentResourceName()
local FILE = 'stores.json'

local TYPES = { clothing = true, barber = true, tattoo = true, surgeon = true }

local stores = {} ---@type table[]
local nextId = 1

local function num(value, min, max)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return math.max(min, math.min(max, value))
end

local function vec(value, fields, min, max)
    if type(value) ~= 'table' and type(value) ~= 'vector3' and type(value) ~= 'vector4' then return nil end
    local out = {}
    for _, field in ipairs(fields) do
        out[field] = num(value[field], min, max)
        if not out[field] then return nil end
    end
    return out
end

local function text(value, max)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    return value:sub(1, max)
end

---Loja validada. nil = inválida.
local function clean(input, id)
    if type(input) ~= 'table' or not TYPES[input.type] then return nil end

    local coords = vec(input.coords, { 'x', 'y', 'z', 'w' }, -100000, 100000)
    if not coords then return nil end

    local out = {
        id = id,
        type = input.type,
        label = text(input.label, 40),
        coords = coords,
        size = vec(input.size, { 'x', 'y', 'z' }, 0.5, 100) or { x = 4, y = 4, z = 4 },
        rotation = num(input.rotation, -360, 360) or 0,
        -- nil = segue o Config.Blips do tipo; true/false força.
        showBlip = (input.showBlip == true or input.showBlip == false) and input.showBlip or nil,
        job = text(input.job, 50),
        gang = text(input.gang, 50),
        targetModel = text(input.targetModel, 60),
        targetScenario = text(input.targetScenario, 60),
    }

    -- Zona por pontos (lojas antigas do config): mantém enquanto usePoly.
    if input.usePoly == true and type(input.points) == 'table' and #input.points >= 3 then
        local points = {}
        for i = 1, math.min(#input.points, 32) do
            local point = vec(input.points[i], { 'x', 'y', 'z' }, -100000, 100000)
            if not point then return nil end
            points[i] = point
        end
        out.usePoly = true
        out.points = points
    else
        out.usePoly = false
    end

    if out.job and out.gang then out.gang = nil end
    return out
end

local function save()
    SaveResourceFile(RESOURCE, FILE, json.encode(stores, { indent = true }), -1)
end

local function broadcast()
    TriggerClientEvent('mri_Qappearance:stores:changed', -1, stores)
end

local function load()
    local raw = LoadResourceFile(RESOURCE, FILE)
    local ok, data = pcall(json.decode, raw or '')
    local list = ok and type(data) == 'table' and data or nil

    if not list then
        -- Primeira vez: as lojas do config viram o arquivo.
        list = {}
        for i, store in ipairs(Config.Stores or {}) do list[i] = store end
    end

    stores = {}
    for _, store in ipairs(list) do
        local id = math.tointeger(tonumber(store.id)) or nextId
        local cleaned = clean(store, id)
        if cleaned then
            stores[#stores + 1] = cleaned
            nextId = math.max(nextId, id + 1)
        end
    end

    if not raw then save() end
end

load()

local function indexOf(id)
    for i, store in ipairs(stores) do
        if store.id == id then return i end
    end
end

lib.callback.register('mri_Qappearance:stores:get', function()
    return stores
end)

---Cria (sem id) ou atualiza (com id).
---@return boolean ok, table|string storeOrError
lib.callback.register('mri_Qappearance:stores:save', function(source, input)
    if not StudioIsAllowed(source) then return false, 'sem permissão' end

    local id = type(input) == 'table' and math.tointeger(tonumber(input.id))
    local at = id and indexOf(id)
    if id and not at then return false, 'loja não existe mais' end

    local store = clean(input, id or nextId)
    if not store then return false, 'dados inválidos' end

    if at then
        stores[at] = store
    else
        nextId = nextId + 1
        stores[#stores + 1] = store
    end

    save()
    broadcast()
    return true, store
end)

lib.callback.register('mri_Qappearance:stores:delete', function(source, id)
    if not StudioIsAllowed(source) then return false end
    local at = indexOf(math.tointeger(tonumber(id)))
    if not at then return false end
    table.remove(stores, at)
    save()
    broadcast()
    return true
end)

lib.callback.register('mri_Qappearance:stores:teleport', function(source, id)
    if not StudioIsAllowed(source) then return false end
    local at = indexOf(math.tointeger(tonumber(id)))
    if not at then return false end
    local coords = stores[at].coords
    local ped = GetPlayerPed(source)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    return true
end)

---Empregos e gangues do qbx_core pra restringir uma loja.
lib.callback.register('mri_Qappearance:stores:groups', function(source)
    if not StudioIsAllowed(source) then return {} end
    local list = {}
    local okJobs, jobs = pcall(function() return exports.qbx_core:GetJobs() end)
    local okGangs, gangs = pcall(function() return exports.qbx_core:GetGangs() end)
    for name, data in pairs(okJobs and jobs or {}) do
        list[#list + 1] = { kind = 'job', name = name, label = data.label or name }
    end
    for name, data in pairs(okGangs and gangs or {}) do
        if name ~= 'none' then list[#list + 1] = { kind = 'gang', name = name, label = data.label or name } end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)
