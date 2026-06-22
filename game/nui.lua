local client = client

RegisterNUICallback("appearance_get_locales", function(_, cb)
    cb(Locales[GetConvar("illenium-appearance:locale", "en")].UI)
end)

RegisterNUICallback("appearance_get_settings", function(_, cb)
    cb({ appearanceSettings = client.getAppearanceSettings() })
end)

RegisterNUICallback("appearance_get_data", function(_, cb)
    Wait(250)
    local appearanceData = client.getAppearance()
    if appearanceData.tattoos then
        client.setPedTattoos(cache.ped, appearanceData.tattoos)
    end
    cb({ config = client.getConfig(), appearanceData = appearanceData })
end)

RegisterNUICallback("appearance_set_camera", function(camera, cb)
    cb(1)
    client.setCamera(camera)
end)

RegisterNUICallback("appearance_turn_around", function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, 180.0)
end)

local targetHeading = nil
local rotThreadActive = false

RegisterNUICallback("appearance_rotate_ped", function(headingDelta, cb)
    cb(1)
    if type(headingDelta) == "number" then
        local cam = client.getCameraHandle()
        if cam then
            local currentFov = GetCamFov(cam)
            local fovScale = currentFov / 50.0
            headingDelta = headingDelta * fovScale
        end

        if not targetHeading then
            targetHeading = GetEntityHeading(cache.ped)
        end
        targetHeading = targetHeading + headingDelta
        
        if not rotThreadActive then
            rotThreadActive = true
            CreateThread(function()
                while rotThreadActive do
                    local currentHeading = GetEntityHeading(cache.ped)
                    
                    -- Normalize angles to handle 360 wrap around
                    local diff = targetHeading - currentHeading
                    while diff > 180.0 do diff = diff - 360.0 end
                    while diff < -180.0 do diff = diff + 360.0 end
                    
                    if math.abs(diff) < 0.1 then
                        SetEntityHeading(cache.ped, targetHeading)
                        rotThreadActive = false
                    else
                        local newHeading = currentHeading + (diff * 0.15)
                        SetEntityHeading(cache.ped, newHeading)
                    end
                    Wait(0)
                end
                rotThreadActive = false
                targetHeading = nil
            end)
        end
    end
end)

local targetZ = nil
local zThreadActive = false

RegisterNUICallback("appearance_pan_camera", function(data, cb)
    cb(1)
    if not client.isCameraInterpolating() then
        local cam = client.getCameraHandle()
        if cam then
            local vDelta = tonumber(data.verticalDelta) or 0
            
            local currentFov = GetCamFov(cam)
            local fovScale = currentFov / 50.0
            vDelta = vDelta * fovScale
            
            local camCoords = GetCamCoord(cam)
            local pedCoords = GetEntityCoords(cache.ped)
            local pedZ = pedCoords.z

            if not targetZ then
                targetZ = camCoords.z
            end
            
            targetZ = targetZ - (vDelta * 0.006)
            targetZ = math.max(pedZ - 0.5, math.min(pedZ + 1.2, targetZ))

            if not zThreadActive then
                zThreadActive = true
                CreateThread(function()
                    while zThreadActive and client.getCameraHandle() and not client.isCameraInterpolating() do
                        local cx, cy
                        if client.currentCamPoint then
                            cx, cy = client.currentCamPoint.x, client.currentCamPoint.y
                        else
                            cx, cy = pedCoords.x, pedCoords.y
                        end

                        local currentCamCoords = GetCamCoord(cam)
                        local currentZ = currentCamCoords.z
                        
                        if math.abs(currentZ - targetZ) < 0.005 then
                            currentZ = targetZ
                            zThreadActive = false
                        end

                        local newZ = currentZ + (targetZ - currentZ) * 0.15
                        if not zThreadActive then newZ = targetZ end

                        local ox = currentCamCoords.x - cx
                        local oy = currentCamCoords.y - cy
                        local rot = GetCamRot(cam, 2)
                        local pitchRad = math.rad(rot.x)
                        local distBase = math.sqrt(ox^2 + oy^2)
                        local dz_focus = math.tan(pitchRad) * distBase
                        local lookAtZ = newZ + dz_focus

                        SetCamCoord(cam, currentCamCoords.x, currentCamCoords.y, newZ)
                        PointCamAtCoord(cam, cx, cy, lookAtZ)
                        
                        if not zThreadActive then break end
                        Wait(0)
                    end
                    zThreadActive = false
                    targetZ = nil
                end)
            end
        end
    end
end)

RegisterNUICallback("appearance_pan_camera_to_mouse", function(data, cb)
    cb(1)
    if not client.isCameraInterpolating() then
        local cam = client.getCameraHandle()
        if cam then
            local relativeY = tonumber(data.relativeY) or 0
            local zoomDelta = tonumber(data.zoomAmount) or 0
            
            -- Se for zoom delta muito pequeno, consideramos apenas o pan normal.
            -- O relativeY vai de -1 (baixo) a 1 (cima).
            -- Multiplicamos por um fator de movimento para que conforme ele de zoom in/out a câmera acompanhe pra onde o mouse tava.
            local moveFactor = zoomDelta * 0.05
            
            local camCoords = GetCamCoord(cam)
            local pedCoords = GetEntityCoords(cache.ped)
            local pedZ = pedCoords.z

            if not targetZ then
                targetZ = camCoords.z
            end
            
            -- Desloca a câmera no eixo Z na direção em que o mouse está na tela
            targetZ = targetZ + (relativeY * moveFactor)
            targetZ = math.max(pedZ - 0.5, math.min(pedZ + 1.2, targetZ))

            if not zThreadActive then
                zThreadActive = true
                CreateThread(function()
                    while zThreadActive and client.getCameraHandle() and not client.isCameraInterpolating() do
                        local cx, cy
                        if client.currentCamPoint then
                            cx, cy = client.currentCamPoint.x, client.currentCamPoint.y
                        else
                            cx, cy = pedCoords.x, pedCoords.y
                        end

                        local currentCamCoords = GetCamCoord(cam)
                        local currentZ = currentCamCoords.z
                        
                        if math.abs(currentZ - targetZ) < 0.005 then
                            currentZ = targetZ
                            zThreadActive = false
                        end

                        local newZ = currentZ + (targetZ - currentZ) * 0.15
                        if not zThreadActive then newZ = targetZ end

                        local ox = currentCamCoords.x - cx
                        local oy = currentCamCoords.y - cy
                        local rot = GetCamRot(cam, 2)
                        local pitchRad = math.rad(rot.x)
                        local distBase = math.sqrt(ox^2 + oy^2)
                        local dz_focus = math.tan(pitchRad) * distBase
                        local lookAtZ = newZ + dz_focus

                        SetCamCoord(cam, currentCamCoords.x, currentCamCoords.y, newZ)
                        PointCamAtCoord(cam, cx, cy, lookAtZ)
                        
                        if not zThreadActive then break end
                        Wait(0)
                    end
                    zThreadActive = false
                    targetZ = nil
                end)
            end
        end
    end
end)

local targetFov = nil
local fovThreadActive = false

RegisterNUICallback("appearance_zoom_absolute", function(zoomValue, cb)
    cb(1)
    if not client.isCameraInterpolating() then
        local cam = client.getCameraHandle()
        if cam then
            local val = tonumber(zoomValue) or 0.0
            local fov = 40.0 - (val * 3.0)
            targetFov = math.max(10.0, math.min(70.0, fov))
            
            if not fovThreadActive then
                fovThreadActive = true
                CreateThread(function()
                    while fovThreadActive and client.getCameraHandle() and not client.isCameraInterpolating() do
                        local currentFov = GetCamFov(cam)
                        if math.abs(currentFov - targetFov) < 0.1 then
                            SetCamFov(cam, targetFov)
                            fovThreadActive = false
                            break
                        end
                        local newFov = currentFov + (targetFov - currentFov) * 0.1
                        SetCamFov(cam, newFov)
                        Wait(0)
                    end
                    fovThreadActive = false
                end)
            end
        end
    end
end)

RegisterNUICallback("appearance_change_model", function(model, cb)
    local playerPed = client.setPlayerModel(model)

    SetEntityHeading(cache.ped, client.getHeading())
    SetEntityInvincible(playerPed, true)
    -- TaskStandStill(playerPed, -1)

    cb({
        appearanceSettings = client.getAppearanceSettings(),
        appearanceData = client.getPedAppearance(playerPed)
    })
end)

RegisterNUICallback("appearance_change_component", function(component, cb)
    client.setPedComponent(cache.ped, component)
    cb(client.getComponentSettings(cache.ped, component.component_id))
end)

RegisterNUICallback("appearance_change_prop", function(prop, cb)
    client.setPedProp(cache.ped, prop)
    cb(client.getPropSettings(cache.ped, prop.prop_id))
end)

RegisterNUICallback("appearance_change_head_blend", function(headBlend, cb)
    cb(1)
    client.setPedHeadBlend(cache.ped, headBlend)
end)

RegisterNUICallback("appearance_change_face_feature", function(faceFeatures, cb)
    cb(1)
    client.setPedFaceFeatures(cache.ped, faceFeatures)
end)

RegisterNUICallback("appearance_change_head_overlay", function(headOverlays, cb)
    cb(1)
    client.setPedHeadOverlays(cache.ped, headOverlays)
end)

RegisterNUICallback("appearance_change_hair", function(hair, cb)
    client.setPedHair(cache.ped, hair)
    cb(client.getHairSettings(cache.ped))
end)

RegisterNUICallback("appearance_change_eye_color", function(eyeColor, cb)
    cb(1)
    client.setPedEyeColor(cache.ped, eyeColor)
end)

RegisterNUICallback("appearance_apply_tattoo", function(data, cb)
    local paid = not data.tattoo or not Config.ChargePerTattoo or lib.callback.await("illenium-appearance:server:payForTattoo", false, data.tattoo)
    if paid then
        client.addPedTattoo(cache.ped, data.updatedTattoos or data)
    end
    cb(paid)
end)

RegisterNUICallback("appearance_preview_tattoo", function(previewTattoo, cb)
    cb(1)
    client.setPreviewTattoo(cache.ped, previewTattoo.data, previewTattoo.tattoo)
end)

RegisterNUICallback("appearance_delete_tattoo", function(data, cb)
    cb(1)
    client.removePedTattoo(cache.ped, data)
end)

RegisterNUICallback("appearance_wear_clothes", function(dataWearClothes, cb)
    cb(1)
    client.wearClothes(dataWearClothes.data, dataWearClothes.key)
end)

RegisterNUICallback("appearance_remove_clothes", function(clothes, cb)
    cb(1)
    client.removeClothes(clothes)
end)

RegisterNUICallback("appearance_save", function(appearance, cb)
    cb(1)
    client.wearClothes(appearance, "head")
    client.wearClothes(appearance, "body")
    client.wearClothes(appearance, "bottom")
    client.exitPlayerCustomization(appearance)
end)

RegisterNUICallback("appearance_exit", function(_, cb)
    cb(1)
    client.exitPlayerCustomization()
end)

RegisterNUICallback("rotate_left", function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, 10.0)
end)

RegisterNUICallback("rotate_right", function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, -10.0)
end)

-- Cor de destaque da suite MRI (compartilhada com a suite inteira). Definida via
-- `setr mri:color "#hex"` no server.cfg ou pelo painel admin do mri_Qadmin.
RegisterNUICallback("getConfig", function(_, cb)
    cb({ accentColor = GetConvar('mri:color', '#00E699') })
end)

-- Broadcast: convar `mri:color` mudou no server, propaga pra NUI ja aberta.
-- Convencao deste script e `{ type, payload }` (ver customization.lua), nao
-- `{ action, data }` da suite — o EventListener em web/src/Nui.ts le
-- `e.data.type` / `e.data.payload`.
RegisterNetEvent('mri_Qappearance:accentColorChanged', function(newColor)
    SendNuiMessage(json.encode({
        type = 'updateAccentColor',
        payload = { accentColor = newColor }
    }))
end)
