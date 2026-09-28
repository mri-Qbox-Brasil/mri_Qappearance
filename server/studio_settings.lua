-- Configurações do estúdio editadas pelo painel (modo Estúdio): câmera por
-- parte e por peça, corte, tamanho e fundo. Ficam em studio/settings.json.
-- Ver STUDIO.md.
--
-- {
--   parts = {
--     ['component:11'] = {
--       camera = { fov, zPos, dist, angleH, camZ, roll },      -- sobrepõe o preset
--       pieces = { ['42'] = { fov, zPos, dist, angleH, camZ, roll } }, -- peça específica
--       mirrored = { ['male:57'] = true }, -- peça do outro lado (por gênero): câmera e quadro da parte espelhados
--       crop = { mode = 'auto'|'fixed', box = { x, y, w, h }, padding, align = 'center'|'bottom' },
--       chroma = 'green'|'magenta',                               -- cor do fundo
--     },
--   },
--   output = { size = 256 },
--   background = { type = 'none'|'solid'|'gradient', color1, color2, angle, shadow, bake },
-- }

local RESOURCE = GetCurrentResourceName()
local FILE = 'studio/settings.json'

local settings = { parts = {}, output = { size = Config.Studio.IconSize }, background = { type = 'none' } }

local HEX = '^#%x%x%x%x%x%x$'
local CAMERA_FIELDS = { fov = { 1, 130 }, zPos = { -2, 2 }, dist = { 0.1, 10 }, angleH = { -720, 720 }, camZ = { -2, 2 }, roll = { -180, 180 } }

local function num(value, min, max)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return math.max(min, math.min(max, value))
end

local function cleanCamera(camera)
    if type(camera) ~= 'table' then return nil end
    local out = {}
    for field, range in pairs(CAMERA_FIELDS) do
        out[field] = num(camera[field], range[1], range[2])
        if not out[field] then return nil end
    end
    return out
end

local function cleanCrop(crop)
    if type(crop) ~= 'table' then return nil end
    local out = {
        mode = crop.mode == 'fixed' and 'fixed' or 'auto',
        padding = num(crop.padding, 0, 0.4) or 0.06,
        align = crop.align == 'bottom' and 'bottom' or 'center',
    }
    if type(crop.box) == 'table' then
        local x, y = num(crop.box.x, 0, 1), num(crop.box.y, 0, 1)
        local w, h = num(crop.box.w, 0.01, 1), num(crop.box.h, 0.01, 1)
        if x and y and w and h then out.box = { x = x, y = y, w = w, h = h } end
    end
    if out.mode == 'fixed' and not out.box then out.mode = 'auto' end
    return out
end

local function cleanPart(part)
    if type(part) ~= 'table' then return nil end
    local out = {
        camera = cleanCamera(part.camera),
        crop = cleanCrop(part.crop),
        -- Cor do fundo da parte: magenta pra cabelo/roupa verde, que o verde comeria.
        chroma = (part.chroma == 'green' or part.chroma == 'magenta') and part.chroma or nil,
        pieces = {},
        mirrored = {},
    }
    if type(part.pieces) == 'table' then
        for drawable, camera in pairs(part.pieces) do
            local key = math.tointeger(tonumber(drawable))
            local clean = cleanCamera(camera)
            if key and key >= 0 and clean then out.pieces[tostring(key)] = clean end
        end
    end
    if type(part.mirrored) == 'table' then
        for piece, on in pairs(part.mirrored) do
            local gender, drawable = tostring(piece):match('^(%a+):(%d+)$')
            if (gender == 'male' or gender == 'female') and on == true then
                out.mirrored[('%s:%d'):format(gender, tonumber(drawable))] = true
            end
        end
    end
    if not out.camera and not out.crop and not out.chroma and next(out.pieces) == nil and next(out.mirrored) == nil then return nil end
    return out
end

local function cleanBackground(bg)
    bg = type(bg) == 'table' and bg or {}
    local kind = (bg.type == 'solid' or bg.type == 'gradient') and bg.type or 'none'
    return {
        type = kind,
        color1 = type(bg.color1) == 'string' and bg.color1:match(HEX) and bg.color1 or '#1f1f23',
        color2 = type(bg.color2) == 'string' and bg.color2:match(HEX) and bg.color2 or '#0a0a0c',
        angle = num(bg.angle, 0, 360) or 180,
        shadow = bg.shadow == true,
        bake = bg.bake == true,
    }
end

local function clean(input)
    input = type(input) == 'table' and input or {}
    local out = { parts = {}, output = {}, background = cleanBackground(input.background) }

    if type(input.parts) == 'table' then
        for key, part in pairs(input.parts) do
            if type(key) == 'string' and (key:match('^component:%d+$') or key:match('^prop:%d+$')) then
                out.parts[key] = cleanPart(part)
            end
        end
    end

    local size = math.tointeger(tonumber(type(input.output) == 'table' and input.output.size))
    out.output.size = (size == 192 or size == 256 or size == 384 or size == 512) and size or Config.Studio.IconSize

    return out
end

local function load()
    local raw = LoadResourceFile(RESOURCE, FILE)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then settings = clean(data) end
end

load()

---Pro resto do servidor (e pro client, via callback).
function GetStudioSettings()
    return settings
end

-- Público: o menu precisa do fundo pra desenhar atrás das fotos.
lib.callback.register('mri_Qappearance:studio:getSettings', function()
    return settings
end)

lib.callback.register('mri_Qappearance:studio:saveSettings', function(source, input)
    if not StudioIsAllowed(source) then return false end
    settings = clean(input)
    SaveResourceFile(RESOURCE, FILE, json.encode(settings), -1)
    TriggerClientEvent('mri_Qappearance:studio:settingsChanged', -1, settings)
    return true, settings
end)
