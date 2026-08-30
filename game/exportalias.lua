-- Compatibilidade de nome. O fxmanifest declara `provides` pros nomes antigos
-- (illenium-appearance, fivem-appearance), mas `provides` só resolve dependência:
-- os exports continuam registrados sob o nome real do resource, então
-- exports['illenium-appearance']:setPedAppearance() falha com "No such export".
--
-- Export em Lua é um evento `__cfx_export_<resource>_<nome>` que devolve a função
-- pelo setCB. Aqui a chamada de exports() é envelopada pra registrar também os
-- handlers dos aliases — vale pra todo export, inclusive os que o upstream
-- adicionar depois. Precisa carregar ANTES de qualquer arquivo que chame exports().

local resourceName = GetCurrentResourceName()
local aliases = {}

for _, key in ipairs({ 'provide', 'provides' }) do
    for i = 0, (GetNumResourceMetadata(resourceName, key) or 0) - 1 do
        local name = GetResourceMetadata(resourceName, key, i)
        if name and name ~= resourceName then
            aliases[#aliases + 1] = name
        end
    end
end

if #aliases > 0 and type(exports) == 'table' then
    local realExports = exports

    exports = setmetatable({}, {
        __call = function(_, name, fn)
            realExports(name, fn)
            for _, alias in ipairs(aliases) do
                AddEventHandler(('__cfx_export_%s_%s'):format(alias, name), function(setCB)
                    setCB(fn)
                end)
            end
        end,
        __index = function(_, key)
            return realExports[key]
        end,
    })
end
