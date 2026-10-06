-- Criador de personagem: vida no ped enquanto a pessoa edita.
-- Parado respirando, olhando pra câmera, reagindo à roupa nova e, ao confirmar,
-- a câmera dá uma volta em torno dele. Só roda no criador (client.isNewCharacter);
-- loja, barbearia e tatuagem seguem com o ped parado como antes.

-- GTA Online lobby stance: arms down, breathing only, head stays still so the look-at owns it.
local IDLE = {
    male = { dict = "mp_corona_idles@male_a@base", anim = "base" },
    female = { dict = "mp_corona_idles@female_a@base", anim = "base" },
}

-- Reação ao vestir, por componente (animações das lojas de roupa do GTA).
local SHIRT = { dict = "clothingshirt", anim = "try_shirt_positive_d" }
local REACTIONS = {
    [11] = SHIRT,
    [8] = SHIRT,
    [3] = SHIRT,
    [4] = { dict = "clothingtrousers", anim = "try_trousers_positive_d" },
    [6] = { dict = "clothingshoes", anim = "try_shoes_positive_d" },
}
local FINALE_POSE = SHIRT

local FINALE_MS = 4200
local REACTION_GAP_MS = 1200

local warned = {}

--- Carrega a animação; se o dicionário ou a animação não existir, avisa uma vez no F8.
local function load(entry)
    if not DoesAnimDictExist(entry.dict) then
        if not warned[entry.dict] then
            warned[entry.dict] = true
            print(("^3[mri_Qappearance] criador: dicionário de animação não existe: %s^7"):format(entry.dict))
        end
        return false
    end
    if not lib.requestAnimDict(entry.dict, 3000) then return false end
    if GetAnimDuration(entry.dict, entry.anim) <= 0.0 then
        local key = entry.dict .. "/" .. entry.anim
        if not warned[key] then
            warned[key] = true
            print(("^3[mri_Qappearance] criador: animação não existe: %s^7"):format(key))
        end
        return false
    end
    return true
end

local function gender()
    return GetEntityModel(cache.ped) == `mp_f_freemode_01` and "female" or "male"
end

-- Cursor in screen space (0..1), nil when it left the window: then the ped looks at the camera.
local cursor
local CURSOR_DEPTH = 0.5 -- fraction of the camera-to-head distance along the cursor ray (face cams are under 1 m)
local LOOK_FLAGS = 2 | 4 | 8 -- fast turn, extended yaw and pitch limits
local HEAD_BONE = 31086

local function cursorTarget(cam)
    local rot = GetFinalRenderedCamRot(2)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    local forward = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
    local up = vector3(right.y * forward.z - right.z * forward.y, right.z * forward.x - right.x * forward.z, right.x * forward.y - right.y * forward.x)
    local half = math.tan(math.rad(GetFinalRenderedCamFov()) / 2.0)
    local dir = forward + right * ((cursor.x * 2.0 - 1.0) * half * GetAspectRatio(false)) + up * ((1.0 - cursor.y * 2.0) * half)
    local depth = #(GetPedBoneCoords(cache.ped, HEAD_BONE, 0.0, 0.0, 0.0) - cam) * CURSOR_DEPTH
    return cam + dir / #dir * depth
end

--- Olhar do ped segue o cursor do mouse (ou a câmera, sem cursor na tela).
local lookThread = false
local function startLook()
    if lookThread then return end
    lookThread = true
    CreateThread(function()
        local last
        while lookThread and client.isNewCharacter() do
            local cam = GetFinalRenderedCamCoord()
            local target = cursor and cursorTarget(cam) or cam
            if not last or #(target - last) > 0.01 then
                TaskLookAtCoord(cache.ped, target.x, target.y, target.z, -1, LOOK_FLAGS, 2)
                last = target
            end
            Wait(100)
        end
        lookThread = false
    end)
end

RegisterNUICallback("creator_look", function(data, cb)
    cb(1)
    local x, y = type(data) == "table" and tonumber(data.x), type(data) == "table" and tonumber(data.y)
    cursor = x and y and { x = math.min(math.max(x, 0.0), 1.0), y = math.min(math.max(y, 0.0), 1.0) } or nil
end)

local function stopLook()
    lookThread = false
    cursor = nil
    TaskClearLookAt(cache.ped)
end

--- Parado respirando (loop no corpo inteiro). Chamado ao abrir e sempre que algo limpa as tarefas do ped.
function client.creatorIdle()
    if not client.isNewCharacter() then return end
    local idle = IDLE[gender()]
    if load(idle) then
        TaskPlayAnim(cache.ped, idle.dict, idle.anim, 2.0, 2.0, -1, 1, 0.0, false, false, false)
    end
    startLook()
    client.creatorCameraStart()
end

local lastReaction = 0
--- Reação só no tronco, por cima do idle, sem interromper a respiração.
local function react(entry)
    if not load(entry) then return end
    TaskPlayAnim(cache.ped, entry.dict, entry.anim, 4.0, -4.0, -1, 48, 0.0, false, false, false)
end

RegisterNUICallback("creator_react", function(data, cb)
    cb(1)
    if not client.isNewCharacter() or type(data) ~= "table" then return end
    local now = GetGameTimer()
    if now - lastReaction < REACTION_GAP_MS then return end
    local entry = REACTIONS[tonumber(data.component_id)]
    if not entry then return end
    lastReaction = now
    react(entry)
end)

local function smooth(t)
    return t * t * (3.0 - 2.0 * t)
end

--- Volta completa da câmera em torno do ped, partindo de onde a câmera está e
--- terminando no mesmo lugar (a troca de volta pra câmera do menu não aparece).
RegisterNUICallback("creator_finale", function(_, cb)
    if not client.isNewCharacter() then return cb(1) end

    local startedAt = GetGameTimer()
    while client.isCameraInterpolating() and GetGameTimer() - startedAt < 2000 do Wait(0) end

    local menuCam = client.getCameraHandle()
    if not menuCam then return cb(1) end

    local ped = cache.ped
    -- starts where the player left the camera (zoom included) and eases back to the step framing while orbiting
    local current, framing = client.creatorCameraPoses()
    local fallback = { coords = GetCamCoord(menuCam), point = client.currentCamPoint or GetEntityCoords(ped) }
    current, framing = current or fallback, framing or fallback
    local fromOffset = GetOffsetFromEntityGivenWorldCoords(ped, current.coords)
    local toOffset = GetOffsetFromEntityGivenWorldCoords(ped, framing.coords)
    local fov = GetCamFov(menuCam)

    local cam = CreateCameraWithParams("DEFAULT_SCRIPTED_CAMERA", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, fov, false, 0)
    client.applyDof(cam)
    SetCamCoord(cam, current.coords.x, current.coords.y, current.coords.z)
    PointCamAtCoord(cam, current.point.x, current.point.y, current.point.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    PlaySoundFrontend(-1, "CHALLENGE_UNLOCKED", "HUD_AWARDS", true)
    stopLook()
    client.creatorCameraStop()
    react(FINALE_POSE)

    local start = GetGameTimer()
    while true do
        local t = math.min((GetGameTimer() - start) / FINALE_MS, 1.0)
        local angle = smooth(t) * 2.0 * math.pi
        local back = smooth(math.min(t / 0.45, 1.0))
        local origin = fromOffset + (toOffset - fromOffset) * back
        local point = current.point + (framing.point - current.point) * back
        local s, c = math.sin(angle), math.cos(angle)
        local x = origin.x * c - origin.y * s
        local y = origin.x * s + origin.y * c
        local pos = GetOffsetFromEntityInWorldCoords(ped, x, y, origin.z)
        SetCamCoord(cam, pos.x, pos.y, pos.z)
        PointCamAtCoord(cam, point.x, point.y, point.z)
        if t >= 1.0 then break end
        Wait(0)
    end

    -- the menu camera may still hold the zoomed pose: park it on the framing the orbit ended at
    SetCamCoord(menuCam, framing.coords.x, framing.coords.y, framing.coords.z)
    PointCamAtCoord(menuCam, framing.point.x, framing.point.y, framing.point.z)
    SetCamActive(menuCam, true)
    RenderScriptCams(true, false, 0, true, true)
    DestroyCam(cam, false)
    cb(1)
end)

--- Chamado pela customização ao sair: solta o olhar e a animação.
function client.creatorStop()
    stopLook()
    client.creatorCameraStop()
end
