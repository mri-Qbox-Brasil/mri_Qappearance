-- Ready-made faces and looks for the character creator, curated by admins from the creator
-- itself and managed in the panel (aba Prontos). Stored in data/presets.json.

local RESOURCE = GetCurrentResourceName()
local FILE = 'data/presets.json'
local KINDS = { face = 'faces', look = 'looks' }
local GENDERS = { male = true, female = true }
local MAX_NAME = 32
local MAX_ITEMS = 60 -- per kind and gender
local MAX_BYTES = 24 * 1024

local presets = { nextId = 1, faces = {}, looks = {} }

local function save()
    SaveResourceFile(RESOURCE, FILE, json.encode(presets, { indent = true }), -1)
end

local function load()
    local raw = LoadResourceFile(RESOURCE, FILE)
    local ok, data = pcall(json.decode, raw or '')
    if not ok or type(data) ~= 'table' then return end
    presets.nextId = math.tointeger(tonumber(data.nextId)) or 1
    presets.faces = type(data.faces) == 'table' and data.faces or {}
    presets.looks = type(data.looks) == 'table' and data.looks or {}
end

load()

local function cleanName(name)
    if type(name) ~= 'string' then return end
    name = name:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #name == 0 then return end
    return name:sub(1, MAX_NAME)
end

local function isList(value)
    return type(value) == 'table' and (next(value) == nil or value[1] ~= nil)
end

---Keeps only the parts each kind is about, so a face never carries clothes and a look never a face.
local function cleanData(kind, data)
    if type(data) ~= 'table' then return end
    local out
    if kind == 'face' then
        if type(data.headBlend) ~= 'table' or type(data.faceFeatures) ~= 'table' or type(data.headOverlays) ~= 'table' or type(data.hair) ~= 'table' then return end
        out = {
            headBlend = data.headBlend,
            faceFeatures = data.faceFeatures,
            headOverlays = data.headOverlays,
            hair = data.hair,
            eyeColor = math.tointeger(tonumber(data.eyeColor)) or 0,
        }
    else
        if not isList(data.components) or not isList(data.props) then return end
        local components = {}
        for _, component in ipairs(data.components) do
            local id = type(component) == 'table' and math.tointeger(tonumber(component.component_id))
            -- face (0) and hair (2) belong to the face, not the look
            if id and id ~= 0 and id ~= 2 then components[#components + 1] = component end
        end
        out = { components = components, props = data.props }
    end
    if #json.encode(out) > MAX_BYTES then return end
    return out
end

local function find(list, id)
    for i, item in ipairs(list) do
        if item.id == id then return i, item end
    end
end

local function count(list, gender)
    local n = 0
    for _, item in ipairs(list) do
        if item.gender == gender then n = n + 1 end
    end
    return n
end

lib.callback.register('mri_Qappearance:presets:get', function()
    return presets.faces, presets.looks
end)

---@return boolean ok, table|string itemOrError
lib.callback.register('mri_Qappearance:presets:save', function(source, input)
    if not StudioIsAllowed(source) then return false, 'sem permissão' end
    if type(input) ~= 'table' or not KINDS[input.kind] or not GENDERS[input.gender] then return false, 'dados inválidos' end

    local list = presets[KINDS[input.kind]]
    if count(list, input.gender) >= MAX_ITEMS then return false, ('limite de %d por gênero'):format(MAX_ITEMS) end

    local name = cleanName(input.name)
    if not name then return false, 'dê um nome' end
    local data = cleanData(input.kind, input.data)
    if not data then return false, 'aparência inválida' end

    local item = { id = presets.nextId, name = name, gender = input.gender, photo = 0, data = data }
    presets.nextId = presets.nextId + 1
    list[#list + 1] = item
    save()
    return true, item
end)

lib.callback.register('mri_Qappearance:presets:rename', function(source, kind, id, name)
    if not StudioIsAllowed(source) or not KINDS[kind] then return false end
    local _, item = find(presets[KINDS[kind]], math.tointeger(tonumber(id)))
    name = cleanName(name)
    if not item or not name then return false end
    item.name = name
    save()
    return true
end)

lib.callback.register('mri_Qappearance:presets:delete', function(source, kind, id)
    if not StudioIsAllowed(source) or not KINDS[kind] then return false end
    local list = presets[KINDS[kind]]
    local at = find(list, math.tointeger(tonumber(id)))
    if not at then return false end
    table.remove(list, at)
    save()
    StudioRemovePresetPhoto(kind, math.tointeger(tonumber(id)))
    return true
end)

---Photo saved by the studio: bump its version so the creator stops showing the old one.
function PresetsPhotoSaved(kind, id)
    if not KINDS[kind] then return false end
    local _, item = find(presets[KINDS[kind]], id)
    if not item then return false end
    item.photo = os.time()
    save()
    return true
end
