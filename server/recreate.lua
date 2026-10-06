-- Recriar personagem: um admin manda o jogador de volta pro criador, onde ele
-- estiver (painel /adminappearance, aba Jogadores). O que ele montar é salvo
-- como num personagem novo.

---@return boolean ok, string nameOrError
local function recreate(admin, target)
    target = math.tointeger(tonumber(target))
    if not target or not GetPlayerName(target) then return false, 'jogador não está online' end
    if not Framework.GetPlayerID(target) then return false, 'jogador ainda não escolheu o personagem' end

    local ok, err = lib.callback.await('mri_Qappearance:recreateCharacter', target)
    if not ok then return false, ('%s %s'):format(GetPlayerName(target), err or 'não pôde abrir o criador') end

    print(('[mri_Qappearance] %s mandou %s (id %d) recriar o personagem'):format(GetPlayerName(admin), GetPlayerName(target), target))
    return true, GetPlayerName(target)
end

lib.callback.register('mri_Qappearance:recreate', function(source, target)
    if not StudioIsAllowed(source) then return false, 'sem permissão' end
    return recreate(source, target)
end)
