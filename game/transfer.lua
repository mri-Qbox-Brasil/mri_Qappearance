-- Importar/exportar a aparência como texto (botões no rodapé do menu).
--  * Exportar: copia o código do personagem (formato deste script, com coleção +
--    número local de cada peça, então funciona em outro servidor com outros packs).
--  * Importar: aceita esse código ou o JSON do personagem do nation_creator.
-- Só aplica as partes que o menu aberto permite (barbearia não troca roupa etc.);
-- o jogador ainda confirma no ✓ pra salvar. Ver TRANSFER.md.

local client = client

local FORMAT = "mri_appearance"

local function n(value, fallback)
    value = tonumber(value)
    if not value or value ~= value then return fallback end
    return value
end

---JSON do nation_creator -> formato deste script. O que não vier no JSON fica
---como está no ped (`current`). Mapeamento do snippet da comunidade (function.lua).
local function fromNation(data, current)
    local function overlay(name, key)
        local now = current.headOverlays[name] or {}
        return {
            style = n(data[key], now.style or 0),
            opacity = n(data[key .. "-opacity"], now.opacity or 0),
            color = n(data[key .. "-color"], now.color or 0),
            secondColor = now.secondColor or 0,
        }
    end

    local blend, features = current.headBlend, current.faceFeatures
    local function feature(name, key) return n(data[key], features[name] or 0) end

    return {
        model = data.gender == "female" and "mp_f_freemode_01" or data.gender == "male" and "mp_m_freemode_01" or current.model,
        hair = {
            style = n(data.hair, current.hair.style),
            color = n(data["hair-color"], current.hair.color),
            highlight = n(data["hair-highlightcolor"], current.hair.highlight),
            texture = 0,
        },
        headOverlays = {
            beard = overlay("beard", "facialHair"),
            makeUp = overlay("makeUp", "makeup"),
            bodyBlemishes = overlay("bodyBlemishes", "bodyBlemishes"),
            complexion = overlay("complexion", "complexion"),
            blush = overlay("blush", "blush"),
            blemishes = overlay("blemishes", "blemishes"),
            ageing = overlay("ageing", "ageing"),
            sunDamage = overlay("sunDamage", "sunDamage"),
            chestHair = overlay("chestHair", "chestHair"),
            moleAndFreckles = overlay("moleAndFreckles", "freckles"),
            eyebrows = overlay("eyebrows", "eyebrows"),
            lipstick = overlay("lipstick", "lipstick"),
        },
        headBlend = {
            shapeFirst = n(data.shapeFirst, blend.shapeFirst),
            shapeSecond = n(data.shapeSecond, blend.shapeSecond),
            shapeThird = n(data.shapeThird, 0),
            skinFirst = n(data.skinFirst, blend.skinFirst),
            skinSecond = n(data.skinSecond, blend.skinSecond),
            skinThird = n(data.skinThird, 0),
            shapeMix = n(data.shapeMix, blend.shapeMix),
            skinMix = n(data.skinMix, blend.skinMix),
            thirdMix = 0,
        },
        faceFeatures = {
            noseWidth = feature("noseWidth", "noseWidth"),
            nosePeakHigh = feature("nosePeakHigh", "nosePeakHeight"),
            nosePeakSize = feature("nosePeakSize", "nosePeakLength"),
            noseBoneHigh = feature("noseBoneHigh", "noseBoneHigh"),
            nosePeakLowering = feature("nosePeakLowering", "nosePeakLowering"),
            noseBoneTwist = feature("noseBoneTwist", "noseBoneTwist"),
            eyeBrownHigh = feature("eyeBrownHigh", "eyeBrownHigh"),
            eyeBrownForward = feature("eyeBrownForward", "eyeBrownForward"),
            cheeksBoneHigh = feature("cheeksBoneHigh", "cheeksBoneHigh"),
            cheeksBoneWidth = feature("cheeksBoneWidth", "cheeksBoneWidth"),
            cheeksWidth = feature("cheeksWidth", "cheeksWidth"),
            eyesOpening = feature("eyesOpening", "eyesOpenning"),
            lipsThickness = feature("lipsThickness", "lipsThickness"),
            jawBoneWidth = feature("jawBoneWidth", "jawBoneWidth"),
            jawBoneBackSize = feature("jawBoneBackSize", "jawBoneBackLength"),
            chinBoneLowering = feature("chinBoneLowering", "chinBoneLowering"),
            chinBoneLenght = feature("chinBoneLenght", "chinBoneLength"),
            chinBoneSize = feature("chinBoneSize", "chinBoneWidth"),
            chinHole = feature("chinHole", "chinHole"),
            neckThickness = features.neckThickness or 0,
        },
        eyeColor = n(data.eyes, current.eyeColor),
    }
end

local function isNation(data)
    return data.shapeMix ~= nil and data.components == nil and data.headBlend == nil
end

---Texto colado -> aparência. nil, motivo se não reconhecer.
local function parse(text, current)
    if type(text) ~= "string" then return nil, "código vazio" end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= "table" then return nil, "código inválido (não é JSON)" end
    -- Snippet da comunidade às vezes vem embrulhado: { skin = {...} } / { data = {...} }.
    if type(data.skin) == "table" then data = data.skin elseif type(data.data) == "table" then data = data.data end

    if isNation(data) then return fromNation(data, current), "nation" end
    if data.format == FORMAT or data.headBlend or data.components then return data, FORMAT end
    return nil, "formato não reconhecido"
end

RegisterNUICallback("appearance_export", function(_, cb)
    local appearance = client.getPedAppearance(cache.ped)
    appearance.format = FORMAT
    local code = json.encode(appearance)
    lib.setClipboard(code)
    cb({ ok = true, code = code })
end)

RegisterNUICallback("appearance_import", function(data, cb)
    local config = client.getConfig() or {}
    local current = client.getPedAppearance(cache.ped)
    local appearance, source = parse(type(data) == "table" and data.code, current)
    if not appearance then return cb({ err = source }) end

    local model = appearance.model and (type(appearance.model) == "string" and joaat(appearance.model) or appearance.model)
    if model and model ~= GetEntityModel(cache.ped) then
        if not config.ped then return cb({ err = "esse código é de outro sexo/modelo: troque no menu de personagem" }) end
        client.setPlayerModel(model)
        SetEntityHeading(cache.ped, client.getHeading())
        SetEntityInvincible(cache.ped, true)
    end

    -- Só o que o menu aberto deixa mexer.
    local apply = {}
    if config.headBlend then apply.headBlend = appearance.headBlend end
    if config.faceFeatures then apply.faceFeatures = appearance.faceFeatures end
    if config.headOverlays then
        apply.headOverlays = appearance.headOverlays
        apply.hair = appearance.hair
        apply.eyeColor = appearance.eyeColor
    end
    if config.components then apply.components = appearance.components end
    if config.props then apply.props = appearance.props end
    if config.tattoos and type(appearance.tattoos) == "table" then apply.tattoos = appearance.tattoos end

    client.setPedAppearance(cache.ped, apply)

    cb({
        ok = true,
        source = source,
        appearanceSettings = client.getAppearanceSettings(),
        appearanceData = client.getPedAppearance(cache.ped),
    })
end)
