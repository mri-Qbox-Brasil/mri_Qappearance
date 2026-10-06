-- NUI bridge for ready-made faces and looks (server/presets.lua).

RegisterNUICallback('presets_get', function(_, cb)
    local faces, looks = lib.callback.await('mri_Qappearance:presets:get', false)
    cb({
        faces = faces or {},
        looks = looks or {},
        canEdit = lib.callback.await('mri_Qappearance:studio:isAllowed', false) == true,
    })
end)

RegisterNUICallback('presets_save', function(data, cb)
    -- collection + local index keep the preset right after new clothing packs shift the global numbers
    if type(data) == 'table' and type(data.data) == 'table' then client.withCollections(cache.ped, data.data) end
    local ok, result = lib.callback.await('mri_Qappearance:presets:save', false, data)
    cb(ok and { ok = true, item = result } or { err = result or 'não foi possível salvar' })
end)

RegisterNUICallback('presets_rename', function(data, cb)
    local ok = type(data) == 'table' and lib.callback.await('mri_Qappearance:presets:rename', false, data.kind, data.id, data.name)
    cb(ok and { ok = true } or { err = 'não foi possível renomear' })
end)

RegisterNUICallback('presets_delete', function(data, cb)
    local ok = type(data) == 'table' and lib.callback.await('mri_Qappearance:presets:delete', false, data.kind, data.id)
    cb(ok and { ok = true } or { err = 'não foi possível apagar' })
end)

---Applies a preset to the creator ped and hands the NUI the resulting appearance.
RegisterNUICallback('creator_apply_preset', function(data, cb)
    local item = type(data) == 'table' and type(data.data) == 'table' and data.data
    if not item or not client.isNewCharacter() then return cb({ err = 'nada pra aplicar' }) end

    local ped = cache.ped
    if data.kind == 'face' then
        if item.headBlend then client.setPedHeadBlend(ped, item.headBlend) end
        if item.faceFeatures then client.setPedFaceFeatures(ped, item.faceFeatures) end
        if item.headOverlays then client.setPedHeadOverlays(ped, item.headOverlays) end
        if item.hair then client.setPedHair(ped, item.hair, client.getPedTattoos()) end
        if item.eyeColor then client.setPedEyeColor(ped, item.eyeColor) end
    else
        if item.components then client.setPedComponents(ped, item.components) end
        if item.props then client.setPedProps(ped, item.props) end
    end

    cb({ appearanceData = client.getPedAppearance(ped), appearanceSettings = client.getAppearanceSettings() })
end)
