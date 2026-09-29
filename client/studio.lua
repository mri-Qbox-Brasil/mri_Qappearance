-- Estúdio de fotos de roupa — lado client. Ver STUDIO.md.
--
-- Monta um ped isolado dentro de um green screen embaixo do mapa e deixa o NUI
-- (web/src/studio) dirigir: vestir, fotografar, recortar e mandar pro servidor.
-- A cena é o esquema do uz_AutoShot; o porte é o do photobooth do
-- tetris_oxinventory, com o pré-carregamento de peça do uz_AutoShot.

local STUDIO_CFG = Config.Studio

local STUDIO = vector3(0.0, 0.0, -150.0)
--- Ped encarando +Y, que é o lado onde os presets de CAMERAS põem a câmera.
local STUDIO_HEADING = 0.0
local SHOOT_TIMEOUT = 60 * 60 * 1000
local UPLOAD_TIMEOUT = 60 * 1000

local CHROMA_COLORS = {
    green = { r = 0, g = 177, b = 64 },
    magenta = { r = 255, g = 0, b = 255 },
}
local CHROMA = CHROMA_COLORS[STUDIO_CFG.ChromaKey] or CHROMA_COLORS.green

local SCREEN = { width = 8.0, depth = 8.0, height = 8.5, floorOffset = -3.0 }

local LIGHTS = {
    { offset = vector3(0.0, 2.5, 1.0),  range = 8.0, intensity = 3.0 },
    { offset = vector3(-2.5, 0.0, 1.0), range = 5.0, intensity = 2.0 },
    { offset = vector3(2.5, 0.0, 1.0),  range = 5.0, intensity = 2.0 },
    { offset = vector3(0.0, -1.5, 1.0), range = 4.0, intensity = 1.5 },
    { offset = vector3(0.0, 0.0, 3.0),  range = 6.0, intensity = 2.5 },
}

local HEAD_MASK = { offsetZ = 0.136, sizeX = 0.12, sizeY = 0.15, sizeZ = 0.315 }
local HEAD_BONE = 31086

local MODELS = {
    male = `mp_m_freemode_01`,
    female = `mp_f_freemode_01`,
}

---Presets de câmera do uz_AutoShot (Customize.lua): `angleH` em graus,
---`zPos`/`camZ` em metros a partir do pé do ped. Peça mal enquadrada se ajusta
---aqui, não no código.
local CAMERAS = {
    hair        = { fov = 25.0, zPos = 0.72,  dist = 1.2, angleH = 180.0,  camZ = 0.0,  roll = 0.0 },
    mask        = { fov = 25.1, zPos = 0.66,  dist = 1.2, angleH = 180.6,  camZ = 0.0,  roll = 0.0 },
    arms_gloves = { fov = 89.4, zPos = 0.07,  dist = 0.6, angleH = 180.6,  camZ = 0.09, roll = 0.0 },
    legs        = { fov = 60.0, zPos = -0.46, dist = 1.2, angleH = 179.9,  camZ = 0.1,  roll = 0.0 },
    shoes       = { fov = 19.0, zPos = -0.96, dist = 1.3, angleH = 180.3,  camZ = 0.77, roll = 0.0 },
    accessories = { fov = 24.0, zPos = 0.3,   dist = 1.2, angleH = 180.0,  camZ = 0.0,  roll = 0.0 },
    body        = { fov = 37.7, zPos = 0.31,  dist = 1.3, angleH = 180.0,  camZ = 0.0,  roll = 0.0 },
    decals      = { fov = 56.4, zPos = 0.27,  dist = 0.9, angleH = 0.0,    camZ = 0.0,  roll = 0.0 },
    tops        = { fov = 34.7, zPos = 0.22,  dist = 1.4, angleH = 180.0,  camZ = 0.0,  roll = 0.0 },
    hats        = { fov = 21.2, zPos = 0.72,  dist = 1.2, angleH = 180.0,  camZ = 0.0,  roll = 0.0 },
    glasses     = { fov = 5.0,  zPos = 0.7,   dist = 2.5, angleH = 180.0,  camZ = 0.0,  roll = 0.0 },
    ears        = { fov = 20.0, zPos = 0.68,  dist = 1.0, angleH = 180.9,  camZ = 0.0,  roll = 0.0 },
    watches     = { fov = 17.8, zPos = -0.19, dist = 1.0, angleH = -85.0,  camZ = 0.45, roll = 0.0 },
    bracelets   = { fov = 21.7, zPos = -0.19, dist = 1.0, angleH = -275.6, camZ = 0.5,  roll = 0.0 },
}

---Por parte do corpo: câmera, quais componentes continuam visíveis (o resto vai
---pra -1, que os REMOVE — não é "peça 0") e se a cabeça leva máscara de chroma.
---A cabeça (0) fica sempre, mesmo fora de visible: o FiveM não aceita cabeça
---vazia. Nas partes com hideHead a esfera de chroma a apaga do recorte; em
---máscara e óculos o rosto aparece por baixo, como no uz_AutoShot.
local PARTS = {
    ['component:1']  = { camera = 'mask',        visible = {} },
    ['component:2']  = { camera = 'hair',        visible = { 0 } },
    ['component:3']  = { camera = 'arms_gloves', visible = {}, hideHead = true },
    ['component:4']  = { camera = 'legs',        visible = {} },
    ['component:5']  = { camera = 'decals',      visible = {}, hideHead = true },
    ['component:6']  = { camera = 'shoes',       visible = {} },
    ['component:7']  = { camera = 'accessories', visible = { 0, 3 }, overrides = { [3] = 15 }, hideHead = true },
    ['component:8']  = { camera = 'tops',        visible = {}, hideHead = true },
    ['component:9']  = { camera = 'body',        visible = {}, hideHead = true },
    ['component:10'] = { camera = 'decals',      visible = { 3 }, overrides = { [3] = 15 }, hideHead = true },
    ['component:11'] = { camera = 'tops',        visible = {}, hideHead = true },
    ['prop:0']       = { camera = 'hats',        visible = { 0, 2 } },
    ['prop:1']       = { camera = 'glasses',     visible = {} },
    ['prop:2']       = { camera = 'ears',        visible = { 0, 2 } },
    ['prop:6']       = { camera = 'watches',     visible = { 3 } },
    ['prop:7']       = { camera = 'bracelets',   visible = { 3 } },
}

local DEFAULT_PART = { camera = 'body', visible = {} }

local booth ---@type table?
local adminOpen = false

--------------------------------------------------------------------------------
-- Cena
--------------------------------------------------------------------------------

---Quad de face dupla: DrawPoly é face única, então cada face vai nas duas ordens.
local function drawQuad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, r, g, b)
    DrawPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, 255)
    DrawPoly(x3, y3, z3, x4, y4, z4, x1, y1, z1, r, g, b, 255)
    DrawPoly(x3, y3, z3, x2, y2, z2, x1, y1, z1, r, g, b, 255)
    DrawPoly(x1, y1, z1, x4, y4, z4, x3, y3, z3, r, g, b, 255)
end

---Caixa de chroma em volta do ped + luzes de estúdio. Precisa rodar TODO frame.
local function drawStudio(ped, chroma)
    local pos = GetEntityCoords(ped)
    local r, g, b = chroma.r, chroma.g, chroma.b

    local hw, hd = SCREEN.width * 0.5, SCREEN.depth * 0.5
    local fz = pos.z + SCREEN.floorOffset
    local cz = fz + SCREEN.height

    local x1, y1 = pos.x - hw, pos.y - hd
    local x2, y2 = pos.x + hw, pos.y - hd
    local x3, y3 = pos.x - hw, pos.y + hd
    local x4, y4 = pos.x + hw, pos.y + hd

    drawQuad(x1, y1, fz, x2, y2, fz, x2, y2, cz, x1, y1, cz, r, g, b)
    drawQuad(x4, y4, fz, x3, y3, fz, x3, y3, cz, x4, y4, cz, r, g, b)
    drawQuad(x3, y3, fz, x1, y1, fz, x1, y1, cz, x3, y3, cz, r, g, b)
    drawQuad(x2, y2, fz, x4, y4, fz, x4, y4, cz, x2, y2, cz, r, g, b)
    drawQuad(x1, y1, fz, x2, y2, fz, x4, y4, fz, x3, y3, fz, r, g, b)
    drawQuad(x3, y3, cz, x4, y4, cz, x2, y2, cz, x1, y1, cz, r, g, b)

    for i = 1, #LIGHTS do
        local light = LIGHTS[i]
        DrawLightWithRange(
            pos.x + light.offset.x, pos.y + light.offset.y, pos.z + light.offset.z,
            255, 255, 255, light.range, light.intensity)
    end
end

---Esfera de chroma sobre a cabeça: foto de torso não pode sair com cabeça.
local function drawHeadMask(ped, chroma)
    local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)

    DrawMarker(28,
        head.x, head.y, head.z + HEAD_MASK.offsetZ,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        HEAD_MASK.sizeX, HEAD_MASK.sizeY, HEAD_MASK.sizeZ,
        chroma.r, chroma.g, chroma.b, 255,
        false, false, 2, false, nil, nil, false)
end

local function suppressWorld()
    SetVehicleDensityMultiplierThisFrame(0.0)
    SetPedDensityMultiplierThisFrame(0.0)
    SetRandomVehicleDensityMultiplierThisFrame(0.0)
    SetParkedVehicleDensityMultiplierThisFrame(0.0)
    SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
    SetGarbageTrucks(false)
    SetRandomBoats(false)
    SetRandomTrains(false)
end

---Tira o desfoque da tela: o blur genérico de UI e a transição do pause menu.
---Qualquer um sozinho já borra toda foto.
local function clearBlur()
    TriggerScreenblurFadeOut(0.0)
    TransitionFromBlurred(0.0)
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
end

local function setOtherHudsHidden(hidden)
    -- Contrato de estado que o mri_Qhud e afins escutam (mesmo do mri_Qspawn).
    LocalPlayer.state:set('hideHud', hidden, true)
end

local function setPlayerParked(parked)
    FreezeEntityPosition(cache.ped, parked)
    SetEntityInvincible(cache.ped, parked)
end

local function release(scene)
    if scene.cam then
        RenderScriptCams(false, false, 0, true, true)
        SetCamActive(scene.cam, false)
        DestroyCam(scene.cam, true)
    end

    if scene.ped and DoesEntityExist(scene.ped) then DeleteEntity(scene.ped) end
end

local function teardown()
    if not booth then return end
    local scene = booth
    booth = nil

    release(scene)
    ClearFocus()
    ClearHdArea()
    NetworkClearClockTimeOverride()
    DisplayHud(true)
    DisplayRadar(true)
    setPlayerParked(false)
    TriggerServerEvent('mri_Qappearance:studio:bucket', false)
end

local CODE_BITS = 20 -- 4 de token (qual parte) + 16 de índice (qual peça)

---Células do código de frame: início (1, 0), os bits e a paridade.
---@param value integer
---@return integer[]
local function frameCodeCells(value)
    local cells = { 1, 0 }
    local ones = 0
    for bit = CODE_BITS - 1, 0, -1 do
        local v = (value >> bit) & 1
        cells[#cells + 1] = v
        ones = ones + v
    end
    cells[#cells + 1] = ones % 2
    return cells
end

---Desenha o código da peça atual. Sai no frame do jogo (DrawRect), então o NUI
---sabe qual peça está em cada frame capturado sem esperar resposta do Lua.
local function drawFrameCode(cells)
    local c = STUDIO_CFG.FrameCode
    for i = 1, #cells do
        local v = cells[i] == 1 and 255 or 0
        DrawRect(c.x + (i - 1) * c.step, c.y, c.w, c.h, v, v, v, 255)
    end
end

---Thread do estúdio: green screen, máscara e código são DrawPoly/DrawMarker/
---DrawRect, que só existem no frame em que são chamados.
local function render(scene)
    CreateThread(function()
        while booth == scene do
            HideHudAndRadarThisFrame()
            suppressWorld()

            if scene.ped and DoesEntityExist(scene.ped) then
                local chroma = scene.chroma or CHROMA
                drawStudio(scene.ped, chroma)
                if scene.hideHead then drawHeadMask(scene.ped, chroma) end
            end

            if scene.codeCells then drawFrameCode(scene.codeCells) end

            -- Guarda: um erro no JS não pode deixar o admin preso numa câmera
            -- scriptada sem HUD.
            if GetGameTimer() > scene.deadline then
                print('[mri_Qappearance] estúdio: timeout — desmontando')
                teardown()
                setOtherHudsHidden(false)
                SetNuiFocus(false, false)
                return
            end

            Wait(0)
        end
    end)
end

local EYE_L, EYE_R = 25260, 27474 -- FB_L_Eye_000 / FB_R_Eye_000

---Plano de simetria da cabeça: passa no meio dos olhos, normal na linha entre
---eles. Pega cabeça virada ou inclinada na pose.
---@return vector3? origin, vector3? normal nil se o ped não tem os ossos dos olhos
local function headPlane(ped)
    local l = GetPedBoneCoords(ped, EYE_L, 0.0, 0.0, 0.0)
    local r = GetPedBoneCoords(ped, EYE_R, 0.0, 0.0, 0.0)
    local axis = r - l
    if #axis < 0.01 then return nil end
    return (l + r) / 2, axis / #axis
end

local function reflect(p, origin, normal)
    local d = (p.x - origin.x) * normal.x + (p.y - origin.y) * normal.y + (p.z - origin.z) * normal.z
    return p - normal * (2 * d)
end

---Câmera em órbita em volta do ped; a rotação sai por trigonometria.
---@param mirrored boolean? preset espelhado (mirrorCamera): reflete no plano da cabeça
local function aimCamera(cam, ped, preset, mirrored)
    local pos = GetEntityCoords(ped)

    -- Espelhada: o preset vem com ângulo e inclinação invertidos (mirrorCamera),
    -- o que reflete no eixo do corpo. Com zoom alto, milímetros de cabeça fora
    -- desse eixo já tiram a orelha do quadro fixo: monta a câmera original e
    -- reflete no plano da cabeça.
    local origin, normal
    if mirrored then origin, normal = headPlane(ped) end
    local angle = math.rad(origin and -preset.angleH or preset.angleH)

    local camPos = vector3(pos.x + preset.dist * math.sin(angle), pos.y - preset.dist * math.cos(angle), pos.z + preset.zPos + preset.camZ)
    local look = vector3(pos.x, pos.y, pos.z + preset.zPos)
    if origin then
        camPos, look = reflect(camPos, origin, normal), reflect(look, origin, normal)
    end

    local d = look - camPos
    local pitch = math.deg(math.atan(d.z, math.sqrt(d.x * d.x + d.y * d.y)))
    local heading = -math.deg(math.atan(d.x, d.y))

    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    -- + 0.0: o JSON salvo devolve inteiro (fov 3) e native de float lê inteiro
    -- como outro número (a câmera ia pro zoom máximo ao reabrir e no lote).
    SetCamRot(cam, pitch, preset.roll + 0.0, heading, 2)
    SetCamFov(cam, preset.fov + 0.0)
end

local function placeCamera(ped, preset, mirrored)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    aimCamera(cam, ped, preset, mirrored)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    return cam
end

--------------------------------------------------------------------------------
-- Configurações do modo Estúdio (server/studio_settings.lua)
--------------------------------------------------------------------------------

local studioSettings = { parts = {} }

CreateThread(function()
    local data = lib.callback.await('mri_Qappearance:studio:getSettings', false)
    if type(data) == 'table' then studioSettings = data end
end)

---A mesma câmera do outro lado do ped (ele fica virado pro heading 0): pra peça
---de um lado só, como brinco numa orelha só. Espelho do mirrorCamera de settings.ts.
local function mirrorCamera(camera)
    return {
        fov = camera.fov,
        zPos = camera.zPos,
        dist = camera.dist,
        angleH = -camera.angleH,
        camZ = camera.camZ,
        roll = -camera.roll,
    }
end

---Câmera de uma peça: a da peça específica, a da parte ou o preset do uz
---(espelhada quando a peça está marcada como do outro lado, por gênero: o 57
---masculino e o 57 feminino são brincos diferentes).
---@return table camera, boolean mirrored
local function cameraFor(partKey, drawable, gender)
    local custom = studioSettings.parts and studioSettings.parts[partKey]
    local key = drawable and tostring(drawable)
    if custom and key and custom.pieces and custom.pieces[key] then return custom.pieces[key], false end
    local part = PARTS[partKey] or DEFAULT_PART
    local camera = custom and custom.camera or CAMERAS[part.camera] or CAMERAS.body
    if custom and key and custom.mirrored and custom.mirrored[('%s:%s'):format(gender, key)] then return mirrorCamera(camera), true end
    return camera, false
end

---Esvazia o ped deixando só o que a parte fotografada precisa mostrar.
local function dressBare(ped, part)
    local keep = {}
    for _, component in ipairs(part.visible or {}) do keep[component] = true end

    local overrides = part.overrides or {}

    for component = 0, 11 do
        if overrides[component] then
            SetPedComponentVariation(ped, component, overrides[component], 0, 0)
        elseif keep[component] or component == 0 then
            -- Cabeça (0) nunca vai pra -1: o FiveM recusa ("empty drawable on the
            -- head component"), o callback morre no meio e o lote trava. Onde ela
            -- não pode aparecer, a esfera de chroma (hideHead) cobre.
            SetPedComponentVariation(ped, component, 0, 0, 0)
        else
            SetPedComponentVariation(ped, component, -1, 0, 0)
        end
    end

    for prop = 0, 7 do ClearPedProp(ped, prop) end
end

-- Quanto tempo o pré-carregamento pode adiantar o download antes de aplicar.
-- É só adiantamento: quem diz se a roupa carregou é o ped (streamedLoaded).
local PREFETCH_MS = 150
-- Espera pelo índice global antes de tentar o chapéu pela coleção.
local PROP_COLLECTION_RETRY_MS = 300

---Mantém a área do estúdio em alta qualidade enquanto a peça carrega (igual ao
---ForceHighQuality do uz_AutoShot): o streaming prioriza o que está no foco.
local function forceHighQuality()
    -- Estúdio desmontado no meio da espera: não religar o foco lá embaixo, senão
    -- ele fica preso no estúdio e o mundo em volta do player sai sem textura.
    if not booth or not STUDIO_CFG.ForceHighQuality then return end
    OverrideLodscaleThisFrame(1.0)
    SetHdArea(STUDIO.x, STUDIO.y, STUDIO.z, 50.0)
    SetFocusPosAndVel(STUDIO.x, STUDIO.y, STUDIO.z, 0.0, 0.0, 0.0)
end

---A roupa que o ped está usando terminou de carregar? HAVE_ALL_STREAMING_
---REQUESTS_COMPLETED (antes _HAS_STREAMED_PED_ASSETS_LOADED) olha o próprio
---ped; o flag do pré-carregamento não confirma em todas as partes (máscara
---nunca confirmava e o lote não tirava foto). Sem a native, cai nesse flag.
local pedStreamingDone = HaveAllStreamingRequestsCompleted or HasStreamedPedAssetsLoaded

local function streamedLoaded(ped, preloaded)
    if pedStreamingDone then return pedStreamingDone(ped) end
    return preloaded
end

---Veste a peça e espera ela carregar de verdade (até PreloadTimeout).
---@return boolean loaded false = não carregou a tempo (a foto sairia com a peça anterior)
---@return string? reason por que não carregou (vai pro log do lote)
local function dressPiece(ped, kind, id, drawable, texture)
    local started = GetGameTimer()
    local prefetch = GetGameTimer() + PREFETCH_MS
    local deadline = GetGameTimer() + STUDIO_CFG.PreloadTimeout
    local preloaded

    if kind == 'prop' then
        -- Prop não passa pelo streaming do ped (HaveAllStreamingRequestsCompleted
        -- nunca confirmava chapéu): vale o pré-carregamento dele e o jogo
        -- confirmar o índice no ped (mesmo teste do uz_AutoShot).
        SetPedPreloadPropData(ped, id, drawable, texture)
        while not HasPedPreloadPropDataFinished(ped) and GetGameTimer() < deadline do forceHighQuality() Wait(0) end
        preloaded = HasPedPreloadPropDataFinished(ped)
        SetPedPropIndex(ped, id, drawable, texture, true)
        ReleasePedPreloadPropData(ped)

        local retry = GetGameTimer() + PROP_COLLECTION_RETRY_MS
        while GetPedPropIndex(ped, id) ~= drawable and GetGameTimer() < retry do forceHighQuality() Wait(0) end

        -- Pelo índice global o jogo recusa alguns chapéus (fica -1). Tenta pelo
        -- índice local da coleção (DLC) dele, que é como o FiveM recomenda.
        local collection = GetPedCollectionNameFromProp and GetPedCollectionNameFromProp(ped, id, drawable)
        local localIndex = GetPedCollectionLocalIndexFromProp and GetPedCollectionLocalIndexFromProp(ped, id, drawable) or -1
        local viaCollection = false
        if GetPedPropIndex(ped, id) ~= drawable and collection and localIndex >= 0 then
            viaCollection = true
            SetPedCollectionPropIndex(ped, id, collection, localIndex, texture, true)
        end

        while GetPedPropIndex(ped, id) ~= drawable and GetGameTimer() < deadline do forceHighQuality() Wait(0) end
        forceHighQuality()
        local index = GetPedPropIndex(ped, id)
        if index ~= drawable then
            return false, ('prop: jogo não aplicou (índice no ped ficou %d; coleção "%s" índice local %d%s; %d texturas; pré-carregamento %s)'):format(
                index, tostring(collection), localIndex, viaCollection and ', tentou pela coleção' or '',
                GetNumberOfPedPropTextureVariations(ped, id, drawable), preloaded and 'ok' or 'não terminou')
        end
        -- Aplicou: o pré-carregamento de prop não confirma em pack grande
        -- (citizenfx/fivem#3684), então vale o índice no ped.
        return true
    else
        SetPedPreloadVariationData(ped, id, drawable, texture)
        while not HasPedPreloadVariationDataFinished(ped) and GetGameTimer() < prefetch do forceHighQuality() Wait(0) end
        preloaded = HasPedPreloadVariationDataFinished(ped)
        SetPedComponentVariation(ped, id, drawable, texture, 0)
        ReleasePedPreloadVariationData(ped)
    end

    while not streamedLoaded(ped, preloaded) and GetGameTimer() < deadline do forceHighQuality() Wait(0) end
    forceHighQuality()
    if streamedLoaded(ped, preloaded) then return true end

    local current, currentTexture = GetPedDrawableVariation(ped, id), GetPedTextureVariation(ped, id)
    return false, ('roupa: streaming do ped não terminou em %dms (pré-carregamento %s; no ped: %d/%d; combinação %s)'):format(
        GetGameTimer() - started,
        preloaded and 'ok' or 'não terminou',
        current, currentTexture,
        IsPedComponentVariationValid(ped, id, drawable, texture) and 'válida' or 'INVÁLIDA')
end

local function allowed()
    return lib.callback.await('mri_Qappearance:studio:isAllowed', false) == true
end

--------------------------------------------------------------------------------
-- Índice de fotos e URL de onde elas são servidas
--------------------------------------------------------------------------------

local studioIndex = { version = 0, sets = {} }
local httpsBase = ''

CreateThread(function()
    local data, base = lib.callback.await('mri_Qappearance:studio:getIndex', false)
    if type(data) == 'table' then studioIndex = data end
    if type(base) == 'string' then httpsBase = base:gsub('^https?://', ''):gsub('/+$', '') end
end)

--------------------------------------------------------------------------------
-- Coleções: as fotos são nomeadas por coleção (DLC/pack) + número local, que
-- não muda quando entra pack novo. A NUI trabalha com o número global (o do
-- menu); o layout diz, pra cada parte, onde cada coleção começa na numeração
-- global de hoje: { m_c11 = { { 'base', 0, 392 }, { 'mp_m_x', 392, 12 } } }.
--------------------------------------------------------------------------------

local LAYOUT_PARTS = {
    { 'c', 1 }, { 'c', 2 }, { 'c', 3 }, { 'c', 4 }, { 'c', 5 }, { 'c', 6 }, { 'c', 7 }, { 'c', 8 }, { 'c', 9 }, { 'c', 10 }, { 'c', 11 },
    { 'p', 0 }, { 'p', 1 }, { 'p', 2 }, { 'p', 6 }, { 'p', 7 },
}

local layouts ---@type table?
local layoutsBusy = false

---Nome da coleção como pedaço do nome de arquivo ('base' = jogo base).
local function collectionToken(name)
    if not name or name == '' then return 'base' end
    return (name:gsub('[^%w_]', '_'))
end

local function layoutOf(ped, code, out)
    local count = GetPedCollectionsCount(ped)
    for _, part in ipairs(LAYOUT_PARTS) do
        local kind, id = part[1], part[2]
        local list = {}
        for i = 0, count - 1 do
            local name = GetPedCollectionName(ped, i) or ''
            local n, first
            if kind == 'p' then
                n = GetNumberOfPedCollectionPropDrawableVariations(ped, id, name)
                first = n > 0 and GetPedPropGlobalIndexFromCollection(ped, id, name, 0) or -1
            else
                n = GetNumberOfPedCollectionDrawableVariations(ped, id, name)
                first = n > 0 and GetPedDrawableGlobalIndexFromCollection(ped, id, name, 0) or -1
            end
            if n > 0 and first >= 0 then list[#list + 1] = { collectionToken(name), first, n } end
        end
        out[('%s_%s%d'):format(code, kind, id)] = list
    end
end

---Layout dos dois gêneros, calculado uma vez por sessão (os packs não mudam com
---o jogo aberto) com um ped local de cada modelo, criado e apagado na hora.
local function studioLayouts()
    if layouts then return layouts end
    if not GetPedCollectionsCount then return {} end
    while layoutsBusy do Wait(0) end
    if layouts then return layouts end
    layoutsBusy = true

    local out = {}
    local at = GetEntityCoords(cache.ped)
    for gender, code in pairs({ male = 'm', female = 'f' }) do
        local model = MODELS[gender]
        if pcall(lib.requestModel, model, 5000) then
            local ped = CreatePed(26, model, at.x, at.y, at.z - 50.0, 0.0, false, false)
            SetModelAsNoLongerNeeded(model)
            if ped and DoesEntityExist(ped) then
                layoutOf(ped, code, out)
                DeleteEntity(ped)
            end
        end
    end

    layouts = out
    layoutsBusy = false
    return layouts
end

---Quantas cores (texturas) cada peça tem no jogo, pra galeria mostrar as que
---faltam foto. Contado uma vez por sessão com um ped local do modelo, como o
---layout; fora do estúdio não tem o ped dele.
local textureCounts = {} ---@type table<string, integer[]>

RegisterNUICallback('studio_texture_counts', function(data, cb)
    if not allowed() then return cb({ err = 'sem permissão' }) end
    local gender = type(data) == 'table' and data.gender == 'female' and 'female' or 'male'
    local partKey = type(data) == 'table' and data.part
    local kind, id = type(partKey) == 'string' and partKey:match('^(%a+):(%d+)$')
    if not kind or not PARTS[partKey] then return cb({ err = 'parte inválida' }) end
    id = tonumber(id)

    local cacheKey = gender .. ':' .. partKey
    if not textureCounts[cacheKey] then
        local model = MODELS[gender]
        if not pcall(lib.requestModel, model, 5000) then return cb({ err = 'modelo do personagem não carregou' }) end
        local at = GetEntityCoords(cache.ped)
        local ped = CreatePed(26, model, at.x, at.y, at.z - 50.0, 0.0, false, false)
        SetModelAsNoLongerNeeded(model)
        if not ped or not DoesEntityExist(ped) then return cb({ err = 'não consegui criar o ped pra contar' }) end

        local counts = {}
        local drawables = kind == 'prop' and GetNumberOfPedPropDrawableVariations(ped, id) or GetNumberOfPedDrawableVariations(ped, id)
        for drawable = 0, drawables - 1 do
            counts[drawable + 1] = kind == 'prop'
                and GetNumberOfPedPropTextureVariations(ped, id, drawable)
                or GetNumberOfPedTextureVariations(ped, id, drawable)
        end
        DeleteEntity(ped)
        textureCounts[cacheKey] = counts
    end

    cb({ ok = true, textures = textureCounts[cacheKey] })
end)

---A NUI é https e não carrega imagem de http://ip:porta. Com o proxy da Cfx.re
---(web_baseUrl) a foto vem direto do servidor; sem ele, nil, e a NUI pede cada
---foto pelo callback studio_photo.
---Pra exibir as fotos, nil = pelo callback studio_photo (confiável). O proxy da
---Cfx.re (web_baseUrl) falha de vez em quando e deixava foto quebrada no menu e
---na galeria; servir por HTTPS próprio fica no StudioUrl do images.json.
local function studioBaseUrl()
    return nil
end

-- A NUI tenta os mesmos caminhos HTTP do upload antes do evento latente.
-- Loopback funciona quando jogo e servidor estão no mesmo PC; o proxy atende
-- clientes remotos. A NUI conserva o callback como alternativa se ambos falharem.
local function studioPhotoBases()
    local bases = {}
    local resource = GetCurrentResourceName()
    local port = (GetCurrentServerEndpoint() or ''):match(':(%d+)$')
    if port then bases[#bases + 1] = ('http://127.0.0.1:%s/%s/studio'):format(port, resource) end
    if httpsBase ~= '' then bases[#bases + 1] = ('https://%s/%s/studio'):format(httpsBase, resource) end
    return bases
end

-- Fotos chegam por evento latente para não disputar o canal de respostas
-- comuns do ox_lib. Cada pedido responde à NUI também em caso de erro.
local pendingPhotos = {}
local photoSequence = 0
local PHOTO_TIMEOUT = 12000 -- antes dos 15s de studioCall em images.ts

RegisterNetEvent('mri_Qappearance:studio:photo', function(requestId, photo, mime, err)
    if source ~= 65535 then return end
    local cb = pendingPhotos[requestId]
    if not cb then return end
    pendingPhotos[requestId] = nil
    cb({ data = photo, mime = mime, err = err })
end)

-- Sem cache aqui: quem guarda é a NUI (web/src/studio/images.ts).
RegisterNUICallback('studio_photo', function(data, cb)
    local name = type(data) == 'table' and data.name
    if type(name) ~= 'string' then return cb({ err = 'foto inválida' }) end
    photoSequence = photoSequence + 1
    local requestId = ('%d:%d'):format(GetGameTimer(), photoSequence)
    pendingPhotos[requestId] = cb
    TriggerServerEvent('mri_Qappearance:studio:requestPhoto', requestId, name)
    SetTimeout(PHOTO_TIMEOUT, function()
        if not pendingPhotos[requestId] then return end
        pendingPhotos[requestId] = nil
        cb({ err = 'tempo esgotado ao carregar a foto' })
    end)
end)

-- Convenção deste script é `{ type, payload }` (ver web/src/Nui.ts).
local function sendNui(event, payload)
    SendNuiMessage(json.encode({ type = event, payload = payload }))
end

RegisterNetEvent('mri_Qappearance:studio:indexChanged', function(data)
    if type(data) ~= 'table' then return end
    studioIndex = data
    sendNui('studio_index', { index = studioIndex, baseUrl = studioBaseUrl(), photoBases = studioPhotoBases(), layouts = layouts })
end)

RegisterNetEvent('mri_Qappearance:studio:settingsChanged', function(data)
    if type(data) ~= 'table' then return end
    studioSettings = data
    sendNui('studio_settings', studioSettings)
end)

---Menu do jogador e painel: de onde tirar as fotos, quais existem e o fundo.
RegisterNUICallback('studio_get_images', function(_, cb)
    cb({ index = studioIndex, baseUrl = studioBaseUrl(), photoBases = studioPhotoBases(), settings = studioSettings, layouts = studioLayouts() })
end)

--------------------------------------------------------------------------------
-- Painel (/adminappearance e plugin do Qadmin)
--------------------------------------------------------------------------------

local function publicConfig()
    return {
        captureMaxWidth = STUDIO_CFG.CaptureMaxWidth,
        captureMaxHeight = STUDIO_CFG.CaptureMaxHeight,
        iconSize = STUDIO_CFG.IconSize,
        iconFormat = STUDIO_CFG.IconFormat,
        iconQuality = STUDIO_CFG.IconQuality,
        maxPendingUploads = STUDIO_CFG.MaxPendingUploads,
        holdFrames = STUDIO_CFG.HoldFrames,
        frameCode = STUDIO_CFG.FrameCode,
        chromaKey = STUDIO_CFG.ChromaKey,
        forceHighQuality = STUDIO_CFG.ForceHighQuality == true,
        preloadTimeout = STUDIO_CFG.PreloadTimeout,
    }
end

local function openAdmin()
    adminOpen = true
    SetNuiFocus(true, true)
    sendNui('studio_admin', { open = true })
end

RegisterNetEvent('mri_Qappearance:studio:openAdmin', openAdmin)

RegisterNUICallback('studio_admin_close', function(_, cb)
    adminOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback('studio_get_state', function(_, cb)
    cb({
        allowed = allowed(),
        running = booth ~= nil,
        index = studioIndex,
        layouts = studioLayouts(),
        baseUrl = studioBaseUrl(),
        accentColor = GetConvar('mri:color', '#00E699'),
        config = publicConfig(),
        settings = studioSettings,
    })
end)

---Início do lote. Vem do painel (standalone ou dentro do Qadmin); a execução
---roda na página principal deste resource, que é pra onde o SendNUIMessage vai.
---Quem veio do Qadmin já pediu pro host fechar antes de chamar isto.
RegisterNUICallback('studio_start', function(data, cb)
    if booth then return cb({ err = 'já tem um lote rodando' }) end
    if not allowed() then return cb({ err = 'sem permissão' }) end
    if type(data) ~= 'table' then return cb({ err = 'payload inválido' }) end

    cb({ ok = true })

    -- Dá tempo do Qadmin soltar o foco dele antes de pegarmos o nosso.
    Wait(250)
    adminOpen = false
    SetNuiFocus(true, true)
    setOtherHudsHidden(true)

    -- Upload direto por HTTP (o evento latente não passa de ~300 KB/s). A NUI é
    -- https e o CEF só deixa o fetch sair pra https ou pra localhost: proxy da
    -- Cfx.re (web_baseUrl) ou servidor local. Senão, studio_save_batch por evento.
    local uploadToken, webBase = lib.callback.await('mri_Qappearance:studio:uploadToken', false)
    -- Candidatos em ordem de velocidade; a NUI testa (ping) e usa o primeiro que
    -- responder. Localhost primeiro: com o servidor no mesmo PC vai direto, sem
    -- a volta pela internet do proxy da Cfx.re.
    local uploadUrls = {}
    if uploadToken then
        local resource = GetCurrentResourceName()
        local port = (GetCurrentServerEndpoint() or ''):match(':(%d+)$')
        if port then
            uploadUrls[#uploadUrls + 1] = ('http://127.0.0.1:%s/%s'):format(port, resource)
        end
        webBase = type(webBase) == 'string' and webBase:gsub('^https?://', ''):gsub('/+$', '') or ''
        if webBase ~= '' then
            uploadUrls[#uploadUrls + 1] = ('https://%s/%s'):format(webBase, resource)
        end
    end

    sendNui('studio_run', {
        uploadUrls = uploadUrls,
        uploadToken = uploadToken,
        genders = data.genders,
        parts = data.parts,
        skipExisting = data.skipExisting == true,
        textures = data.textures == true,
        only = data.only,
        reopen = data.origin == 'standalone',
        index = studioIndex,
        layouts = studioLayouts(),
        config = publicConfig(),
        settings = studioSettings,
    })
end)

---Fim do lote (concluído, parado ou com erro).
RegisterNUICallback('studio_finish', function(data, cb)
    teardown()
    lib.callback.await('mri_Qappearance:studio:flush', false)
    setOtherHudsHidden(false)

    if type(data) == 'table' and data.reopen then
        openAdmin()
    else
        SetNuiFocus(false, false)
    end

    if type(data) == 'table' and data.summary then
        lib.notify({ type = data.error and 'error' or 'success', title = 'Estúdio', description = data.summary })
    end

    cb({ ok = true })
end)

--------------------------------------------------------------------------------
-- Callbacks que o lote (web/src/studio/batch.ts) usa pra dirigir a cena
--------------------------------------------------------------------------------

local freezePose

---Rosto do ped do estúdio (Config.Studio.Face): sem isso o freemode sai com o
---rosto padrão.
local function applyFace(ped, gender)
    local face = STUDIO_CFG.Face and STUDIO_CFG.Face[gender]
    if not face then return end

    SetPedHeadBlendData(ped, face.shapeFirst, face.shapeSecond, 0, face.skinFirst, face.skinSecond, 0,
        face.shapeMix + 0.0, face.skinMix + 0.0, 0.0, false)
    -- Sem marcas no rosto (idade, manchas, pele): o padrão envelhecia o ped.
    for overlay = 0, 12 do SetPedHeadOverlay(ped, overlay, 255, 0.0) end
    if face.eyebrows then
        SetPedHeadOverlay(ped, 2, face.eyebrows, 1.0)
        SetPedHeadOverlayColor(ped, 2, 1, face.eyebrowsColor or 0, face.eyebrowsColor or 0)
    end
    if face.eyeColor then SetPedEyeColor(ped, face.eyeColor) end
end

---Ped do estúdio já preparado (congelado, sem colisão, pose). nil se falhar.
local function spawnStudioPed(model, gender)
    local ped = CreatePed(26, model, STUDIO.x, STUDIO.y, STUDIO.z, STUDIO_HEADING, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or not DoesEntityExist(ped) then return nil end

    SetPedDefaultComponentVariation(ped)
    applyFace(ped, gender)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanPlayAmbientAnims(ped, false)
    SetEntityLodDist(ped, 10000)
    SetFocusEntity(ped)
    freezePose(ped, gender)
    return ped
end

local function loadDict(dict)
    local ok = pcall(lib.requestAnimDict, dict, 3000)
    return ok and HasAnimDictLoaded(dict)
end

---Pose congelada (Config.Studio.Pose): a anim toca com velocidade 0, então o
---ped não respira, não mexe a cabeça nem troca de idle. O rosto recebe uma
---expressão neutra congelada do mesmo jeito, pra não piscar.
function freezePose(ped, gender)
    local pose = STUDIO_CFG.Pose
    if not pose then return end

    local body = pose[gender]
    if body and loadDict(body.dict) then
        if GetAnimDuration(body.dict, body.anim) == 0 then
            print(('^3[mri_Qappearance] estúdio: a pose %s/%s não existe (Config.Studio.Pose)^0'):format(body.dict, body.anim))
        end
        TaskPlayAnim(ped, body.dict, body.anim, 1000.0, -1000.0, -1, 1, 0.0, false, false, false)
        local deadline = GetGameTimer() + 1000
        while not IsEntityPlayingAnim(ped, body.dict, body.anim, 3) and GetGameTimer() < deadline do Wait(0) end
        SetEntityAnimCurrentTime(ped, body.dict, body.anim, 0.0)
        SetEntityAnimSpeed(ped, body.dict, body.anim, 0.0)
    end

    local facial = pose.facial
    if facial and loadDict(facial.dict) then
        SetFacialIdleAnimOverride(ped, facial.anim, facial.dict)
        PlayFacialAnim(ped, facial.anim, facial.dict)
        SetEntityAnimSpeed(ped, facial.dict, facial.anim, 0.0)
    end
end

---Monta o estúdio (ped do gênero, green screen, câmera). Usado pelo lote e pelo
---editor de enquadramento.
---@return boolean ok, string? err
local function openBooth(gender)
    if booth then teardown() end

    gender = gender == 'female' and 'female' or 'male'
    local model = MODELS[gender]

    lib.requestModel(model, 10000)
    if not HasModelLoaded(model) then return false, 'modelo do personagem não carregou' end

    local scene = { gender = gender, deadline = GetGameTimer() + SHOOT_TIMEOUT }
    booth = scene

    TriggerServerEvent('mri_Qappearance:studio:bucket', true)
    setPlayerParked(true)
    DisplayHud(false)
    DisplayRadar(false)
    clearBlur()
    NetworkOverrideClockTime(STUDIO_CFG.ClockHour or 0, 0, 0)
    SetFocusPosAndVel(STUDIO.x, STUDIO.y, STUDIO.z, 0.0, 0.0, 0.0)
    render(scene)
    Wait(300)

    if booth ~= scene then return false, 'estúdio cancelado' end

    local ped = spawnStudioPed(model, gender)
    if not ped then
        teardown()
        return false, 'não consegui criar o ped do estúdio'
    end

    scene.ped = ped
    scene.cam = placeCamera(ped, CAMERAS.body)

    Wait(400)

    if booth ~= scene then
        release(scene)
        return false, 'estúdio cancelado'
    end

    return true
end

RegisterNUICallback('studio_open', function(data, cb)
    if not allowed() then return cb({ err = 'sem permissão' }) end
    local ok, err = openBooth(type(data) == 'table' and data.gender)
    cb(ok and { ok = true } or { err = err })
end)

RegisterNUICallback('studio_count', function(data, cb)
    if not booth or not booth.ped then return cb({ err = 'sem estúdio ativo' }) end

    local kind = type(data) == 'table' and data.kind or 'component'
    local id = math.floor(tonumber(type(data) == 'table' and data.id) or -1)
    if id < 0 then return cb({ err = 'parte inválida' }) end

    local count = kind == 'prop'
        and GetNumberOfPedPropDrawableVariations(booth.ped, id)
        or GetNumberOfPedDrawableVariations(booth.ped, id)

    local textures
    if type(data) == 'table' and data.textures then
        textures = {}
        for drawable = 0, count - 1 do
            textures[drawable + 1] = kind == 'prop'
                and GetNumberOfPedPropTextureVariations(booth.ped, id, drawable)
                or GetNumberOfPedTextureVariations(booth.ped, id, drawable)
        end
    end

    cb({ ok = true, count = math.max(0, count), textures = textures })
end)

---Prepara o estúdio pra uma parte do corpo: base, câmera e máscara de cabeça.
---Prepara o estúdio pra uma parte do corpo: base, câmera e máscara de cabeça.
local function framePart(key, drawable)
    local part = PARTS[key] or DEFAULT_PART

    dressBare(booth.ped, part)
    booth.hideHead = part.hideHead and true or false

    if booth.cam then
        SetCamActive(booth.cam, false)
        DestroyCam(booth.cam, true)
    end

    booth.partKey = key
    -- Cor do fundo da parte (modo Estúdio): magenta pra cabelo/roupa verde.
    local custom = studioSettings.parts and studioSettings.parts[key]
    booth.chroma = CHROMA_COLORS[custom and custom.chroma or STUDIO_CFG.ChromaKey] or CHROMA
    booth.camPreset, booth.camMirrored = cameraFor(key, drawable, booth.gender)
    booth.cam = placeCamera(booth.ped, booth.camPreset, booth.camMirrored)
    clearBlur()
    Wait(150)
end

RegisterNUICallback('studio_frame', function(data, cb)
    if not booth or not booth.ped then return cb({ err = 'sem estúdio ativo' }) end
    framePart(type(data) == 'table' and data.part or nil)
    cb({ ok = true })
end)

local STATUS_EVERY_MS = 250
local STATS_EVERY = 200

---Veste a lista de peças de uma parte no ritmo do jogo, sem esperar o NUI:
---cada peça fica SettleFrames sem código (aparecendo) e HoldFrames com o
---código dela na tela. O NUI captura todo frame e usa o código pra saber qual
---peça é. Responde na hora; o fim vai pelo evento studio_part_done.
RegisterNUICallback('studio_run_part', function(data, cb)
    if not booth or not booth.ped then return cb({ err = 'sem estúdio ativo' }) end
    if type(data) ~= 'table' or type(data.targets) ~= 'table' then return cb({ err = 'payload inválido' }) end
    cb({ ok = true })

    local scene = booth
    local run = {}
    scene.run = run

    local kind = data.kind == 'prop' and 'prop' or 'component'
    local id = math.floor(tonumber(data.id) or 0)
    local token = math.floor(tonumber(data.token) or 0) & 15
    local hold = math.max(1, math.floor(tonumber(data.hold) or STUDIO_CFG.HoldFrames))
    local lastStatus = 0
    -- Passada com outra cor de fundo (a NUI refaz com magenta o que o verde comeu).
    local partChroma = scene.chroma
    if CHROMA_COLORS[data.chroma] then scene.chroma = CHROMA_COLORS[data.chroma] end
    scene.unloaded = scene.unloaded or 0
    -- Pro log do lote: { índice (0-based), motivo } de cada peça que não carregou.
    local failures = {}
    -- Pro log: a cada STATS_EVERY peças, pedidos de streaming pendentes e
    -- tempo médio de carregar. Mostra a memória enchendo antes de travar.
    local stats = {}
    local windowMs, windowCount, windowUnloaded = 0, 0, 0

    local function status(i)
        lastStatus = GetGameTimer()
        sendNui('studio_part_status', {
            index = i, total = #data.targets,
            unloaded = scene.unloaded, paused = scene.paused == true,
        })
    end

    for i, target in ipairs(data.targets) do
        -- Freio: a NUI pausa quando a fila de recorte/envio enche. Segue mandando
        -- status, senão a NUI acharia que o Lua travou.
        while scene.paused and booth == scene and scene.run == run do
            if GetGameTimer() - lastStatus >= STATUS_EVERY_MS then status(i) end
            Wait(0)
        end
        if booth ~= scene or scene.run ~= run then break end

        scene.codeCells = nil
        local drawable = math.floor(tonumber(target[1]) or 0)

        -- Peça com enquadramento próprio (modo Estúdio) move a câmera só pra ela.
        local preset, mirrored = cameraFor(scene.partKey, drawable, scene.gender)
        if (preset ~= scene.camPreset or mirrored ~= scene.camMirrored) and scene.cam then
            aimCamera(scene.cam, scene.ped, preset, mirrored)
            scene.camPreset, scene.camMirrored = preset, mirrored
        end

        local texture = math.floor(tonumber(target[2]) or 0)
        local dressStart = GetGameTimer()
        local loaded, reason = dressPiece(scene.ped, kind, id, drawable, texture)
        windowMs = windowMs + (GetGameTimer() - dressStart)
        windowCount = windowCount + 1
        if not loaded then windowUnloaded = windowUnloaded + 1 end
        if windowCount >= STATS_EVERY or i == #data.targets then
            stats[#stats + 1] = { i, GetNumberOfStreamingRequests(), math.floor(windowMs / windowCount), windowUnloaded, windowCount }
            windowMs, windowCount, windowUnloaded = 0, 0, 0
        end

        if not loaded then
            scene.unloaded = scene.unloaded + 1
            failures[#failures + 1] = { i - 1, reason or 'não carregou' }
        end
        for _ = 1, STUDIO_CFG.SettleFrames do Wait(0) end

        -- Não carregou a tempo: sem código, a NUI não fotografa e a peça vai pra
        -- repassada, em vez de sair gravada com a roupa anterior.
        if loaded then
            scene.codeCells = frameCodeCells((token << 16) | (i - 1))
            for _ = 1, hold do Wait(0) end
        end

        -- Status pra barra da NUI: dá pra ver se o Lua está andando e por quê não.
        if GetGameTimer() - lastStatus >= STATUS_EVERY_MS then status(i) end
    end

    scene.codeCells = nil
    scene.chroma = partChroma
    if scene.run == run then scene.run = nil end
    sendNui('studio_part_done', { token = token, failures = failures, stats = stats })
end)

-- Com número de sequência: pausar/retomar são assíncronos e um 'pausar'
-- atrasado, chegando depois do 'retomar', deixava o lote parado pra sempre.
RegisterNUICallback('studio_pause', function(data, cb)
    local seq = type(data) == 'table' and tonumber(data.seq) or 0
    if booth and seq > (booth.pauseSeq or 0) then
        booth.pauseSeq = seq
        booth.paused = data.paused == true
    end
    cb({ ok = true })
end)

RegisterNUICallback('studio_stop_part', function(_, cb)
    if booth then
        booth.run = nil
        booth.codeCells = nil
    end
    cb({ ok = true })
end)

RegisterNUICallback('studio_stop', function(_, cb)
    teardown()
    cb({ ok = true })
end)

--------------------------------------------------------------------------------
-- Editor de enquadramento (modo Estúdio). Mesma cena do lote, com a câmera
-- mexida ao vivo pelo NUI (web/src/studio/StudioEditor.tsx).
--------------------------------------------------------------------------------

local CAMERA_LIMITS = { fov = { 1, 130 }, zPos = { -2, 2 }, dist = { 0.1, 10 }, angleH = { -720, 720 }, camZ = { -2, 2 }, roll = { -180, 180 } }

local function cleanCamera(camera)
    if type(camera) ~= 'table' then return nil end
    local out = {}
    for field, range in pairs(CAMERA_LIMITS) do
        local value = tonumber(camera[field])
        if not value then return nil end
        out[field] = math.max(range[1], math.min(range[2], value)) + 0.0
    end
    return out
end

---Preset do uz_AutoShot da parte (o "voltar ao padrão").
local function defaultCamera(key)
    local part = PARTS[key] or DEFAULT_PART
    return CAMERAS[part.camera] or CAMERAS.body
end

---Abre o editor. Vem do painel; roda na página principal do resource, como o lote.
RegisterNUICallback('studio_edit_start', function(data, cb)
    if booth then return cb({ err = 'já tem um lote rodando' }) end
    if not allowed() then return cb({ err = 'sem permissão' }) end
    if type(data) ~= 'table' then return cb({ err = 'payload inválido' }) end

    cb({ ok = true })

    Wait(250) -- o Qadmin solta o foco dele
    adminOpen = false
    SetNuiFocus(true, true)
    setOtherHudsHidden(true)

    sendNui('studio_edit', {
        gender = data.gender,
        part = data.part,
        drawable = data.drawable,
        texture = data.texture,
        reopen = data.origin == 'standalone',
        config = publicConfig(),
        settings = studioSettings,
        layouts = studioLayouts(),
    })
end)

RegisterNUICallback('studio_edit_open', function(data, cb)
    if not allowed() then return cb({ err = 'sem permissão' }) end
    if type(data) ~= 'table' or not PARTS[data.part] then return cb({ err = 'parte inválida' }) end

    local ok, err = openBooth(data.gender)
    if not ok then return cb({ err = err }) end

    local part = PARTS[data.part]
    local kind, id = data.part:match('^(%a+):(%d+)$')
    id = tonumber(id)
    local drawable = math.floor(tonumber(data.drawable) or 0)

    framePart(data.part, drawable)
    dressPiece(booth.ped, kind, id, drawable, math.floor(tonumber(data.texture) or 0))

    cb({
        ok = true,
        camera = booth.camPreset,
        defaultCamera = defaultCamera(data.part),
        hideHead = part.hideHead == true,
    })
end)

RegisterNUICallback('studio_edit_camera', function(data, cb)
    local camera = cleanCamera(type(data) == 'table' and data.camera)
    if booth and booth.cam and camera then
        aimCamera(booth.cam, booth.ped, camera, booth.camMirrored)
        booth.camPreset = camera
    end
    cb({ ok = true })
end)

RegisterNUICallback('studio_edit_chroma', function(data, cb)
    local color = CHROMA_COLORS[type(data) == 'table' and data.chroma]
    if booth and color then booth.chroma = color end
    cb({ ok = true })
end)

RegisterNUICallback('studio_edit_dress', function(data, cb)
    if not booth or not booth.ped or type(data) ~= 'table' then return cb({ err = 'sem estúdio ativo' }) end
    local kind, id = (booth.partKey or ''):match('^(%a+):(%d+)$')
    if not kind then return cb({ err = 'parte inválida' }) end

    local drawable = math.floor(tonumber(data.drawable) or 0)
    dressPiece(booth.ped, kind, tonumber(id), drawable, math.floor(tonumber(data.texture) or 0))

    -- Peça com enquadramento próprio já abre nele.
    local camera, mirrored = cameraFor(booth.partKey, drawable, booth.gender)
    aimCamera(booth.cam, booth.ped, camera, mirrored)
    booth.camPreset, booth.camMirrored = camera, mirrored
    cb({ ok = true, camera = camera })
end)

RegisterNUICallback('studio_edit_close', function(data, cb)
    teardown()
    setOtherHudsHidden(false)
    if type(data) == 'table' and data.reopen then
        openAdmin()
    else
        SetNuiFocus(false, false)
    end
    cb({ ok = true })
end)

RegisterNUICallback('studio_delete_photos', function(data, cb)
    local removed = lib.callback.await('mri_Qappearance:studio:deletePhotos', false, type(data) == 'table' and data.list)
    cb({ ok = type(removed) == 'number', removed = removed })
end)

RegisterNUICallback('studio_save_settings', function(data, cb)
    local ok, saved = lib.callback.await('mri_Qappearance:studio:saveSettings', false, type(data) == 'table' and data.settings)
    if ok and type(saved) == 'table' then studioSettings = saved end
    cb({ ok = ok == true, settings = saved })
end)

--------------------------------------------------------------------------------
-- Upload: o NUI junta várias fotos e manda num evento latente só (o custo é por
-- evento, não por byte). O callback responde quando o servidor confirma.
--------------------------------------------------------------------------------

local pendingUploads = {}
local uploadSeq = 0

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, #B64 do b64lookup[B64:byte(i)] = i - 1 end

local function b64decode(data)
    data = data:gsub('[^%w%+/]', '')
    local out = {}
    local n = 0

    for i = 1, #data, 4 do
        local a = b64lookup[data:byte(i)] or 0
        local b = b64lookup[data:byte(i + 1)] or 0
        local c = b64lookup[data:byte(i + 2)]
        local d = b64lookup[data:byte(i + 3)]
        local v = (a << 18) | (b << 12) | ((c or 0) << 6) | (d or 0)

        n = n + 1
        if d then
            out[n] = string.char((v >> 16) & 255, (v >> 8) & 255, v & 255)
        elseif c then
            out[n] = string.char((v >> 16) & 255, (v >> 8) & 255)
        else
            out[n] = string.char((v >> 16) & 255)
        end
    end

    return table.concat(out)
end

RegisterNetEvent('mri_Qappearance:studio:savedBatch', function(requestId, results)
    local pending = pendingUploads[requestId]
    if not pending then return end
    pendingUploads[requestId] = nil
    pending({ ok = true, results = results })
end)

RegisterNUICallback('studio_save_batch', function(data, cb)
    if type(data) ~= 'table' or type(data.items) ~= 'table' then return cb({ err = 'payload inválido' }) end

    uploadSeq = uploadSeq + 1
    local requestId = uploadSeq
    pendingUploads[requestId] = cb

    -- Vai em bytes crus: o evento é o gargalo e base64 é 33% maior.
    for i = 1, #data.items do
        local item = data.items[i]
        if type(item) == 'table' and type(item.data) == 'string' then
            item.bin = b64decode(item.data)
            item.data = nil
        end
    end

    TriggerLatentServerEvent('mri_Qappearance:studio:saveBatch', STUDIO_CFG.LatentRate, requestId, data.items)

    SetTimeout(UPLOAD_TIMEOUT, function()
        local pending = pendingUploads[requestId]
        if not pending then return end
        pendingUploads[requestId] = nil
        pending({ err = 'o servidor não confirmou a gravação' })
    end)
end)

-- Foto avulsa (editor de enquadramento): grava o índice e avisa os clients.
RegisterNUICallback('studio_flush', function(_, cb)
    cb({ ok = lib.callback.await('mri_Qappearance:studio:flush', false) == true })
end)

-- Log do último lote (motivo de cada falha) → studio/log.txt no servidor.
RegisterNUICallback('studio_save_log', function(data, cb)
    cb({ ok = true })
    if type(data) ~= 'table' or type(data.text) ~= 'string' then return end
    TriggerLatentServerEvent('mri_Qappearance:studio:saveLog', STUDIO_CFG.LatentRate, data.text)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local wasShooting = booth ~= nil
    teardown()
    if wasShooting then setOtherHudsHidden(false) end
    if adminOpen or wasShooting then SetNuiFocus(false, false) end
end)
