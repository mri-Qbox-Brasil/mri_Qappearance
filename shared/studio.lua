-- Estúdio de fotos de roupa (/adminappearance e plugin do mri_Qadmin).
-- Ver STUDIO.md na raiz do resource.

Config.Studio = {
    Command = 'adminappearance',

    -- Quem pode abrir o painel e gravar fotos. `command` fica de fallback pra
    -- console/god, igual ao mri_Qspawn.
    Ace = 'mri_Qappearance.studio',

    -- Bucket isolado enquanto o lote roda: ninguém entra no green screen e o
    -- admin some do mundo dos outros players.
    RoutingBucket = 999,

    -- Tamanho da captura. O frame do jogo é amostrado direto nesse tamanho
    -- (mesmo truque do screencapture), então é aqui que se ganha velocidade:
    -- o chroma key roda em 960x540 em vez de 1920x1080.
    CaptureMaxWidth = 960,
    CaptureMaxHeight = 540,

    -- Lado do ícone quadrado gravado.
    IconSize = 256,

    -- 'webp' sai ~5x menor que 'png' com a mesma transparência, e o envio pro
    -- servidor era o gargalo do lote. Qualidade só vale pro webp (0.0–1.0).
    IconFormat = 'webp',
    IconQuality = 0.9,

    -- Quantas fotos podem estar subindo pro servidor ao mesmo tempo. O lote
    -- segue vestindo e fotografando a próxima peça enquanto as anteriores sobem.
    MaxPendingUploads = 16,

    -- bytes/s do evento latente de upload (uz_AutoShot usa 24 MB/s).
    LatentRate = 24000000,

    -- Ritmo do lote, em frames do jogo por peça: SettleFrames depois de vestir
    -- (a peça aparecer) + HoldFrames com o código da peça na tela (a janela em
    -- que o NUI captura). Peça que o NUI perder é refeita no fim da parte, com
    -- mais HoldFrames. Quem garante a foto certa é esperar a peça carregar
    -- (PreloadTimeout), não somar frames aqui.
    SettleFrames = 1,
    HoldFrames = 1,

    -- Código no canto superior esquerdo que diz ao NUI qual peça está no frame
    -- (DrawRect preto/branco, coordenadas de tela 0–1). O NUI pinta essa área
    -- de cor-chave antes do recorte.
    FrameCode = { x = 0.012, y = 0.016, step = 0.009, w = 0.008, h = 0.022 },

    -- Força alta definição a cada frame enquanto a peça carrega (OverrideLodscale
    -- + SetHdArea + foco no estúdio, como o uz_AutoShot). Suspeito de encher a
    -- memória de streaming mais rápido (a textura HD de cada peça). false = só
    -- aponta o foco uma vez, ao montar o estúdio. Compare no studio/log.txt
    -- (linhas "streaming").
    ForceHighQuality = false,

    -- ms máximos esperando a peça carregar. Peça já carregada termina na hora;
    -- a que estourar não é fotografada (vai pra repassada) em vez de sair com
    -- a roupa anterior.
    PreloadTimeout = 1500,

    -- Hora do relógio enquanto o estúdio está montado. As luzes do estúdio
    -- (DrawLightWithRange) só aparecem de noite: de dia o sol domina a
    -- iluminação e as fotos saem sem luz. Volta ao normal ao desmontar.
    ClockHour = 0,

    -- Pose do ped no estúdio, congelada (velocidade 0): sem respirar, mexer a
    -- cabeça nem trocar de idle entre uma foto e outra. Padrão: o idle em pé do
    -- personagem MP, braços soltos. (Não use mp_character_creation: é a pose
    -- segurando a placa do criador.) false = sem pose (idle do jogo).
    Pose = {
        male = { dict = 'move_m@multiplayer', anim = 'idle' },
        female = { dict = 'move_f@multiplayer', anim = 'idle' },
        -- Expressão neutra congelada no rosto, pra não piscar.
        facial = { dict = 'facials@gen_male@base', anim = 'mood_normal_1' },
    },

    -- Rosto do ped do estúdio (pais do criador de personagem: 0–20 e 42–44 são
    -- homens, 21–41 e 45 mulheres; mix 0.0 = só o primeiro, 1.0 = só o segundo).
    -- false = rosto padrão do freemode.
    Face = {
        male = { shapeFirst = 0, shapeSecond = 21, skinFirst = 0, skinSecond = 21, shapeMix = 0.2, skinMix = 0.2, eyebrows = 0, eyebrowsColor = 0, eyeColor = 3 },
        female = { shapeFirst = 21, shapeSecond = 25, skinFirst = 21, skinSecond = 25, shapeMix = 0.5, skinMix = 0.5, eyebrows = 1, eyebrowsColor = 0, eyeColor = 3 },
    },

    -- Cor do green screen: 'green' | 'magenta'. Troque pra magenta se alguma
    -- roupa verde-bandeira estiver sumindo na foto.
    ChromaKey = 'green',
}
