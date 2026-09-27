-- Estúdio de fotos de roupa — lado servidor. Ver STUDIO.md.
--
-- Guarda as fotos (webp ou png) em studio/ dentro do resource e entrega pelo
-- evento latente (requestPhoto) ou por HTTP (/mri_Qappearance/studio/<nome>), então foto
-- nova aparece na hora, sem restart e sem entrar no download de quem conecta.

local RESOURCE = GetCurrentResourceName()
local STUDIO = Config.Studio
local DIR = 'studio'
local INDEX_FILE = DIR .. '/index.json'
local MAX_ICON_BYTES = 2 * 1024 * 1024

local ALLOWED_NODES = { STUDIO.Ace, 'command', 'qadmin.master' }

-- Mesma checagem do HasPerms do mri_Qadmin.
local function isAllowed(source)
    local identifiers = GetPlayerIdentifiers(source)
    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player and player.PlayerData.citizenid

    for _, node in ipairs(ALLOWED_NODES) do
        if IsPlayerAceAllowed(source, node) then return true end

        for i = 1, #identifiers do
            local id = identifiers[i]
            if IsPrincipalAceAllowed('identifier.' .. id, node) or IsPrincipalAceAllowed(id, node) then return true end
        end

        if citizenid and IsPrincipalAceAllowed('char:' .. citizenid, node) then return true end
    end

    return false
end

StudioIsAllowed = isAllowed -- server/studio_settings.lua

lib.callback.register('mri_Qappearance:studio:isAllowed', function(source)
    return isAllowed(source)
end)

--------------------------------------------------------------------------------
-- Índice: quais peças têm foto, por coleção (DLC/pack) e número local dentro
-- dela. O número global da peça muda quando entra pack novo; coleção + local
-- não. A coleção vira um token de nome de arquivo ('base' = jogo base).
--
-- Máscaras de '0'/'1' (1 char por posição). Máscara em vez de contagem porque
-- uma foto pode falhar no meio do lote; com contagem o menu pediria a foto que
-- não existe.
--   sets     = { m_c11 = { base = "1111011..." } }              -- textura 0
--   textures = { m_c11 = { base = { ["42"] = "0110..." } } }    -- texturas >= 1
--------------------------------------------------------------------------------

local INDEX_FORMAT = 2
local index = { version = 0, format = INDEX_FORMAT, sets = {}, textures = {} }
local indexDirty = false

local function loadIndex()
    local raw = LoadResourceFile(RESOURCE, INDEX_FILE)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' or type(data.sets) ~= 'table' or data.format ~= INDEX_FORMAT then return end

    index.version = tonumber(data.version) or 0
    index.sets = data.sets
    index.textures = type(data.textures) == 'table' and data.textures or {}
end

local function saveIndex()
    if not indexDirty then return end
    indexDirty = false
    SaveResourceFile(RESOURCE, INDEX_FILE, json.encode(index), -1)
end

---@param mask string?
---@param pos integer 0-based
local function setBit(mask, pos)
    mask = mask or ''
    if #mask <= pos then mask = mask .. string.rep('0', pos - #mask + 1) end
    return mask:sub(1, pos) .. '1' .. mask:sub(pos + 2)
end

---@param mask string?
---@param pos integer 0-based
local function clearBit(mask, pos)
    if not mask or #mask <= pos then return mask end
    return mask:sub(1, pos) .. '0' .. mask:sub(pos + 2)
end

---@param key string ex: m_c11
---@param token string coleção ('base' = jogo base)
local function markRemoved(key, token, localIndex, texture)
    if texture == 0 then
        local byToken = index.sets[key]
        if byToken then byToken[token] = clearBit(byToken[token], localIndex) end
    else
        local byLocal = index.textures[key] and index.textures[key][token]
        if byLocal then byLocal[tostring(localIndex)] = clearBit(byLocal[tostring(localIndex)], texture) end
    end
    indexDirty = true
end

---@param key string ex: m_c11
---@param token string coleção ('base' = jogo base)
local function markSaved(key, token, localIndex, texture)
    if texture == 0 then
        index.sets[key] = index.sets[key] or {}
        index.sets[key][token] = setBit(index.sets[key][token], localIndex)
    else
        index.textures[key] = index.textures[key] or {}
        local byLocal = index.textures[key][token] or {}
        index.textures[key][token] = byLocal
        byLocal[tostring(localIndex)] = setBit(byLocal[tostring(localIndex)], texture)
    end
    indexDirty = true
end

local function broadcastIndex()
    index.version = os.time()
    indexDirty = true
    saveIndex()
    TriggerClientEvent('mri_Qappearance:studio:indexChanged', -1, index)
end

loadIndex()

-- Grava o índice de tempos em tempos durante o lote, pra um crash não perder
-- a lista de fotos que já estão no disco.
CreateThread(function()
    while true do
        Wait(5000)
        saveIndex()
    end
end)

-- Segundo retorno: endereço HTTPS do servidor pelo proxy da Cfx.re (vazio fora
-- dele). A NUI é https e não carrega imagem de http://ip:porta.
lib.callback.register('mri_Qappearance:studio:getIndex', function()
    return index, GetConvar('web_baseUrl', '')
end)

---Fim de um lote: grava e avisa todos os clients (o menu passa a mostrar as fotos).
lib.callback.register('mri_Qappearance:studio:flush', function(source)
    if not isAllowed(source) then return false end
    broadcastIndex()
    return true
end)

--------------------------------------------------------------------------------
-- Upload
--------------------------------------------------------------------------------

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

local b64chars = {}
for i = 1, #B64 do b64chars[i - 1] = B64:sub(i, i) end

local function b64encode(data)
    local out = {}
    local n = 0

    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local v = (a << 16) | ((b or 0) << 8) | (c or 0)

        n = n + 1
        out[n] = b64chars[v >> 18] .. b64chars[(v >> 12) & 63]
            .. (b and b64chars[(v >> 6) & 63] or '=')
            .. (c and b64chars[v & 63] or '=')
    end

    return table.concat(out)
end

local PNG_MAGIC = string.char(137) .. 'PNG'

---@return 'webp'|'png'|nil
local function iconFormat(bin)
    if bin:sub(1, 4) == 'RIFF' and bin:sub(9, 12) == 'WEBP' then return 'webp' end
    if bin:sub(1, 4) == PNG_MAGIC then return 'png' end
end

local MIME = { webp = 'image/webp', png = 'image/png' }

---A foto de um nome, na extensão que existir. webp primeiro: é o formato que o
---estúdio grava hoje, png é de lote antigo.
---@return string? data, string? mime
local function loadIcon(name)
    for _, ext in ipairs({ 'webp', 'png' }) do
        local data = LoadResourceFile(RESOURCE, ('%s/%s.%s'):format(DIR, name, ext))
        if data then return data, MIME[ext] end
    end
end

local GENDERS = { male = 'm', female = 'f' }
local MAX_ID = { component = 11, prop = 7 }

local function partKey(gender, kind, id)
    return ('%s_%s%d'):format(GENDERS[gender], kind == 'prop' and 'p' or 'c', id)
end

---O nome sai dos campos validados, nunca do client: é ele que liga a foto à peça.
---cloth_m_c11-base-42 = masculino, componente 11, peça 42 do jogo base (textura 0)
---cloth_m_c11-base-42-3 = a mesma peça na textura 3
---cloth_f_p0-mp_f_xmas_01-7 = prop 0, peça 7 da coleção mp_f_xmas_01
local function nameFor(key, token, localIndex, texture)
    local name = ('cloth_%s-%s-%d'):format(key, token, localIndex)
    return texture > 0 and ('%s-%d'):format(name, texture) or name
end

local function validToken(token)
    return type(token) == 'string' and #token <= 64 and token:match('^[%w_]+$') ~= nil
end

local function validName(name)
    return type(name) == 'string' and #name <= 128
        and (name:match('^cloth_[mf]_[cp]%d+%-[%w_]+%-%d+$') or name:match('^cloth_[mf]_[cp]%d+%-[%w_]+%-%d+%-%d+$')) ~= nil
end

---Identificação de uma foto vinda do client (upload/apagar), validada.
---@return string? key, string? token, integer? localIndex, integer? texture
local function photoTarget(item)
    if type(item) ~= 'table' then return end
    local gender, kind = item.gender, item.kind
    local id = math.tointeger(tonumber(item.id))
    local localIndex = math.tointeger(tonumber(item.localDrawable))
    local texture = math.tointeger(tonumber(item.texture or 0))
    if not GENDERS[gender] or not MAX_ID[kind] then return end
    if not id or id < 0 or id > MAX_ID[kind] then return end
    if not validToken(item.collection) then return end
    if not localIndex or localIndex < 0 or localIndex > 4095 then return end
    if not texture or texture < 0 or texture > 255 then return end
    return partKey(gender, kind, id), item.collection, localIndex, texture
end

---@return boolean ok, string? err
local function saveIcon(item)
    -- bin = bytes crus (evento, o client já decodificou); data = base64 (HTTP).
    if type(item) ~= 'table' or (type(item.bin) ~= 'string' and type(item.data) ~= 'string') then return false, 'payload inválido' end

    local key, token, localIndex, texture = photoTarget(item)
    if not key then return false, 'peça inválida (parte, coleção ou número)' end
    if #(item.bin or item.data) > MAX_ICON_BYTES * 4 / 3 + 64 then return false, 'imagem grande demais' end

    local bin = item.bin or b64decode(item.data)
    local ext = #bin >= 16 and iconFormat(bin)
    if not ext then return false, 'não é webp nem png' end

    local name = nameFor(key, token, localIndex, texture)
    if not SaveResourceFile(RESOURCE, ('%s/%s.%s'):format(DIR, name, ext), bin, #bin) then
        return false, 'falha ao gravar'
    end

    -- A foto no outro formato (de um lote anterior) passaria na frente desta.
    local other = ext == 'webp' and 'png' or 'webp'
    pcall(os.remove, ('%s/%s/%s.%s'):format(GetResourcePath(RESOURCE), DIR, name, other))

    markSaved(key, token, localIndex, texture)
    return true
end

---Várias fotos num evento latente só: o custo do evento é por envio, não por
---byte. Responde uma lista de { ok, err } na mesma ordem.
RegisterNetEvent('mri_Qappearance:studio:saveBatch', function(requestId, items)
    local src = source
    local results = {}

    if not isAllowed(src) or type(items) ~= 'table' then
        TriggerClientEvent('mri_Qappearance:studio:savedBatch', src, requestId, results)
        return
    end

    for i = 1, #items do
        local ok, err = saveIcon(items[i])
        results[i] = { ok = ok, err = err }
    end

    TriggerClientEvent('mri_Qappearance:studio:savedBatch', src, requestId, results)
end)

---Apaga fotos (galeria do painel). Recebe a mesma identificação do upload.
lib.callback.register('mri_Qappearance:studio:deletePhotos', function(source, list)
    if not isAllowed(source) or type(list) ~= 'table' then return false end
    local root = GetResourcePath(RESOURCE)
    local removed = 0

    for i = 1, #list do
        local key, token, localIndex, texture = photoTarget(list[i])
        if key then
            local name = nameFor(key, token, localIndex, texture)
            for _, ext in ipairs({ 'webp', 'png' }) do
                pcall(os.remove, ('%s/%s/%s.%s'):format(root, DIR, name, ext))
            end
            markRemoved(key, token, localIndex, texture)
            removed = removed + 1
        end
    end

    if removed > 0 then broadcastIndex() end
    return removed
end)

-- Foto em base64 + mime pro client repassar à NUI. O callback comum do ox_lib
-- usa TriggerClientEvent; imagens em várias respostas simultâneas estavam
-- expirando. O evento latente fragmenta a transferência sem bloquear o canal.
RegisterNetEvent('mri_Qappearance:studio:requestPhoto', function(requestId, name)
    local src = source
    if type(requestId) ~= 'string' or #requestId > 64 or not requestId:match('^%d+:%d+$') then return end
    if not validName(name) then
        return TriggerClientEvent('mri_Qappearance:studio:photo', src, requestId, nil, nil, 'foto inválida')
    end
    local data, mime = loadIcon(name)
    if not data then
        return TriggerClientEvent('mri_Qappearance:studio:photo', src, requestId, nil, nil, 'foto não encontrada')
    end
    TriggerLatentClientEvent('mri_Qappearance:studio:photo', src, 1000000, requestId, b64encode(data), mime)
end)

RegisterNetEvent('mri_Qappearance:studio:bucket', function(enter)
    local src = source
    if not isAllowed(src) then return end
    SetPlayerRoutingBucket(src, enter and STUDIO.RoutingBucket or 0)
end)

-- Log do último lote, escrito pela NUI (web/src/studio/batch.ts): cada falha
-- com a etapa (carregar, captura, recorte, gravação) e o motivo.
local MAX_LOG_BYTES = 8 * 1024 * 1024

RegisterNetEvent('mri_Qappearance:studio:saveLog', function(text)
    local src = source
    if not isAllowed(src) or type(text) ~= 'string' then return end
    if #text > MAX_LOG_BYTES then text = text:sub(1, MAX_LOG_BYTES) .. '\n[log cortado]\n' end
    local header = ('\n==== estúdio — %s — %s (%d) ====\n'):format(os.date('%Y-%m-%d %H:%M:%S'), GetPlayerName(src) or '?', src)

    -- Acumula os lotes (o novo no fim); passando do teto, corta os mais antigos.
    local log = (LoadResourceFile(RESOURCE, 'studio/log.txt') or '') .. header .. text
    if #log > MAX_LOG_BYTES then
        log = log:sub(#log - MAX_LOG_BYTES + 1)
        log = log:sub((log:find('\n==== ', 1, true) or 0) + 1)
    end
    SaveResourceFile(RESOURCE, 'studio/log.txt', log, -1)
    print(('[mri_Qappearance] estúdio: log do lote gravado em studio/log.txt (%s)'):format(text:match('[^\n]*fim[^\n]*') or 'sem resumo'))
end)

--------------------------------------------------------------------------------
-- Upload por HTTP: POST /mri_Qappearance/upload/<token>
--
-- O evento latente não passa de ~300 KB/s e virou o gargalo do lote. A NUI
-- manda os lotes direto por HTTP (como o screencapture faz). O token sai só pra
-- quem tem permissão, fica preso ao source e morre quando ele sai.
--------------------------------------------------------------------------------

local uploadTokens = {} ---@type table<string, integer>

local TOKEN_CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789'

local function newToken()
    local out = {}
    for i = 1, 40 do
        local n = math.random(1, #TOKEN_CHARS)
        out[i] = TOKEN_CHARS:sub(n, n)
    end
    return table.concat(out)
end

math.randomseed(os.time() + GetGameTimer())

-- A web_baseUrl só aparece depois que o servidor autentica na Cfx.re.
CreateThread(function()
    Wait(15000)
    local base = GetConvar('web_baseUrl', '')
    print(base ~= ''
        and ('[mri_Qappearance] estúdio: fotos sobem por HTTPS (%s)'):format(base)
        or '[mri_Qappearance] estúdio: sem web_baseUrl (proxy HTTPS da Cfx.re) — fotos sobem por evento, bem mais lento')
end)

-- Segundo retorno: web_baseUrl (proxy HTTPS da Cfx.re). A NUI é https e o CEF
-- bloqueia fetch pra http://ip:porta; só localhost passa.
lib.callback.register('mri_Qappearance:studio:uploadToken', function(source)
    if not isAllowed(source) then return nil end
    for token, owner in pairs(uploadTokens) do
        if owner == source then uploadTokens[token] = nil end
    end
    local token = newToken()
    uploadTokens[token] = source
    return token, GetConvar('web_baseUrl', '')
end)

AddEventHandler('playerDropped', function()
    local src = source
    for token, owner in pairs(uploadTokens) do
        if owner == src then uploadTokens[token] = nil end
    end
end)

---Pelo proxy da Cfx.re (*.users.cfx.re) o próprio proxy já põe o
---Access-Control-Allow-Origin; mandar o nosso também vira '*, *' e o navegador
---bloqueia. Só colocamos no acesso direto (localhost).
local function viaProxy(req)
    for name, value in pairs(req.headers or {}) do
        local key = tostring(name):lower()
        if key == 'host' and tostring(value):find('users%.cfx%.re') then return true end
        if key == 'x-forwarded-for' or key == 'x-cfx-source-ip' then return true end
    end
    return false
end

local function headers(req, extra)
    local out = {}
    for k, v in pairs(extra or {}) do out[k] = v end
    if not viaProxy(req) then out['Access-Control-Allow-Origin'] = '*' end
    return out
end

local function handleUpload(req, res, token)
    local src = uploadTokens[token]
    if not src or not isAllowed(src) then
        res.writeHead(403, headers(req))
        res.send('forbidden')
        return
    end

    req.setDataHandler(function(body)
        local ok, data = pcall(json.decode, body)
        local results = {}

        if ok and type(data) == 'table' and type(data.items) == 'table' then
            for i = 1, #data.items do
                local saved, err = saveIcon(data.items[i])
                results[i] = { ok = saved, err = err }
            end
        end

        res.writeHead(200, headers(req, { ['Content-Type'] = 'application/json' }))
        res.send(json.encode({ results = results }))
    end)
end

--------------------------------------------------------------------------------
-- HTTP: GET /mri_Qappearance/studio/cloth_m_c11_42 (extensão na URL é ignorada)
--------------------------------------------------------------------------------

SetHttpHandler(function(req, res)
    -- Ping: a NUI testa qual endereço de upload responde (localhost/proxy).
    if req.method == 'GET' and req.path == '/ping' then
        res.writeHead(200, headers(req, { ['Content-Type'] = 'text/plain' }))
        res.send('ok')
        return
    end

    if req.method == 'POST' then
        local token = req.path:match('^/upload/(%w+)$')
        if token then return handleUpload(req, res, token) end
        res.writeHead(404, headers(req))
        res.send('Not found')
        return
    end

    local name = req.method == 'GET' and req.path:match('^/studio/([%w_%-]+)') or nil

    -- O padrão fecha o nome: sem / \ ou .., nada fora de studio/ é alcançável.
    if not validName(name) then
        res.writeHead(404, headers(req, { ['Content-Type'] = 'text/plain' }))
        res.send('Not found')
        return
    end

    local data, mime = loadIcon(name)
    if not data then
        res.writeHead(404, headers(req, { ['Content-Type'] = 'text/plain' }))
        res.send('Not found')
        return
    end

    res.writeHead(200, headers(req, {
        ['Content-Type'] = mime,
        ['Content-Length'] = tostring(#data),
        -- A URL leva ?v=<versão do índice>: foto refeita muda a URL, então dá
        -- pra cachear sem medo.
        ['Cache-Control'] = 'public, max-age=604800',
    }))
    res.send(data)
end)

--------------------------------------------------------------------------------
-- Painel: /adminappearance e plugin do mri_Qadmin (mesma tela).
--------------------------------------------------------------------------------

lib.addCommand(STUDIO.Command, {
    help = 'Abre o painel de fotos de roupa do mri_Qappearance',
}, function(source)
    if not isAllowed(source) then
        return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Sem permissão pra abrir o painel.' })
    end
    TriggerClientEvent('mri_Qappearance:studio:openAdmin', source)
end)

-- Manifest espelha web/src/studio/plugin/types.ts (drift control manual, igual
-- ao mri_Qspawn). O pcall protege quando o Qadmin não está no servidor: o
-- painel continua acessível pelo comando.
local function registerPlugin()
    if GetResourceState('mri_Qadmin') ~= 'started' then return end
    pcall(function()
        exports['mri_Qadmin']:RegisterPlugin({
            id = 'appearance',
            label = 'Aparência',
            icon = 'shirt',
            resource = RESOURCE,
            htmlPath = 'html/index.html',
            requiredPerms = { STUDIO.Ace, 'command' },
            permDefs = {
                { id = STUDIO.Ace, label = 'Aparência', desc = 'Fotografar as roupas e gerenciar lojas, barbearias, tatuagem e cirurgia pelo painel do mri_Qappearance' },
            },
            description = 'Fotos das roupas e lojas de aparência',
        })
    end)
end

-- Os três caminhos do mri_Qspawn: sinal do registry do Qadmin, restart do
-- Qadmin e boot deste resource com o Qadmin já rodando. RegisterPlugin é
-- idempotente por id.
AddEventHandler('mri_Qadmin:server:pluginsReady', registerPlugin)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'mri_Qadmin' then registerPlugin() end
end)

CreateThread(function()
    Wait(0)
    registerPlugin()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == RESOURCE then saveIndex() end
end)
