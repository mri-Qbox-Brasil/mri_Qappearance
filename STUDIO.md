# Estúdio de roupas — `/adminappearance`

Fotografa em lote **cada drawable de roupa** do servidor e usa as fotos no menu
de aparência. Abre de dois jeitos, com a mesma tela:

- **`/adminappearance`** — painel próprio do resource
- **mri_Qadmin → aba "Aparência"** — o mesmo painel como plugin (iframe)

Não depende de `screenshot-basic`, `screencapture` nem `uz_AutoShot`: a cena é o
esquema do uz_AutoShot e a captura é a técnica do screencapture, as duas
reimplementadas aqui (porte do photobooth do `tetris_oxinventory`).

## Permissão

ACE `mri_Qappearance.studio` (ou `command`, pra console/god). Com o mri_Qadmin
rodando, a permissão aparece no editor de grupos, na categoria "Aparência".
Todo callback de escrita confere a ACE **no servidor**.

```cfg
add_ace group.admin mri_Qappearance.studio allow
```

## Como usar

1. `/adminappearance` (ou a aba Aparência no Qadmin)
2. marque gênero e partes — pra testar, só **Jaquetas** e **Masculino**
3. **Gerar fotos**: o painel fecha, a tela mostra o green screen e a barra de
   progresso aparece no rodapé. **ESC** para o lote.
4. no fim o painel reabre com o resumo (no Qadmin, vem uma notificação)
5. abra uma loja de roupa: a peça fotografada já mostra a foto nova, **sem restart**

Com **Pular peças que já têm foto** ligado dá pra parar e retomar: o lote pula
tudo que já foi gravado. **Incluir texturas** fotografa também cada cor de cada
peça (o volume multiplica ~10x); a textura 0 é a própria foto do drawable.

## Modo Estúdio (aba **Estúdio** do painel)

### Enquadramento

**Enquadrar** numa parte abre o estúdio com a barra lateral do editor:

- **câmera ao vivo**: ângulo, distância, altura do alvo, altura da câmera, zoom (FOV)
  e inclinação. Na tela: arrastar gira (horizontal) e sobe/desce (vertical), a
  rodinha aproxima
- **peça e cor** de exemplo pra conferir que o enquadramento serve pra várias
- **prévia da foto final** (corte + fundo), pelo mesmo worker do lote
- **Tirar foto desta peça**: grava na hora a peça e a cor que estão na tela, com
  o enquadramento, corte e fundo atuais (não precisa salvar antes). Foto vazia
  ou comida pelo fundo não é gravada: a mensagem diz o motivo
- **Salvar pra parte inteira** ou **Salvar só pra esta peça** (peça estranha que
  não cabe no enquadramento da parte). "Voltar ao preset padrão" volta ao do uz
- **Espelhar esta peça**: pra peça de um lado só que ficou do outro (brinco
  numa orelha só). Salva na hora só a marca; a peça usa a câmera e o quadro
  fixo da parte espelhados, então acompanha quando a parte muda. O Resetar da
  parte mantém as marcas

### Fundo de recorte

Por parte, **Verde** ou **Magenta** (o padrão é o `ChromaKey` do config). Use
magenta em cabelo e roupas verdes, que o fundo verde apagaria; verde nas roupas
rosa/roxas. Troca ao vivo no editor e é salvo com a parte.

### Corte

- **Automático**: recorta em volta da peça, com margem e alinhamento (centro ou
  apoiado embaixo). Peça grande e pequena saem do mesmo tamanho
- **Quadro fixo**: um quadro arrastável na tela; todas as peças da parte saem na
  mesma escala e posição

### Fundo e tamanho

Transparente, cor sólida ou degradê, sombra embaixo da peça e tamanho (192–512).
Com **Gravar o fundo dentro da foto** desligado (padrão), a foto fica
transparente e o menu desenha o fundo: trocar vale na hora pra todas. Ligado, o
fundo vai no arquivo (pra usar a foto fora do menu) e só muda nas refeitas.

Tudo fica em `studio/settings.json`, validado e salvo pelo servidor.

### Galeria

Seleciona fotos de uma parte e: **Refazer** (com ou sem as cores), **Apagar** ou
**Enquadrar esta peça** (abre o editor nela). Enquadramento novo só aparece nas
fotos refeitas.

## Configuração — `shared/studio.lua`

| Campo | Padrão | O que faz |
|---|---|---|
| `Command` | `adminappearance` | Nome do comando |
| `Ace` | `mri_Qappearance.studio` | Permissão |
| `RoutingBucket` | `999` | Bucket isolado enquanto o lote roda |
| `CaptureMaxWidth/Height` | `960x540` | Tamanho em que o frame do jogo é capturado. Menor = mais rápido |
| `IconSize` | `256` | Lado do ícone gravado |
| `IconFormat` | `webp` | `webp` (~5x menor, envio mais rápido) ou `png`. O servidor serve os dois; foto png de lote antigo continua valendo |
| `IconQuality` | `0.9` | Qualidade do webp |
| `MaxPendingUploads` | `16` | Lotes de envio (até 8 fotos cada) em voo ao mesmo tempo |
| `LatentRate` | `24000000` | bytes/s do upload |
| `SettleFrames` | `1` | Frames depois de vestir, antes de mostrar o código da peça |
| `HoldFrames` | `1` | Frames com o código da peça na tela (a janela de captura). 1 + 1 = 2 frames por peça |
| `FrameCode` | canto sup. esq. | Posição e tamanho do código de frame (fração da tela) |
| `PreloadTimeout` | `1500` | ms máximos esperando a peça carregar. Estourou: não fotografa, vai pra repassada |
| `ForceHighQuality` | `false` | Força alta definição a cada frame da espera (como o uz_AutoShot). Suspeito de encher a memória de streaming; compare as linhas "streaming" do `studio/log.txt` com e sem |
| `ClockHour` | `0` | Hora do relógio no estúdio. De noite, senão o sol apaga as luzes do estúdio |
| `Pose` | idle em pé do personagem MP | Anim do ped, congelada (velocidade 0): não respira, não mexe a cabeça. `facial` congela o rosto pra não piscar. `false` = idle do jogo |
| `Face` | rosto neutro por gênero | Head blend (pais do criador), sobrancelha e cor dos olhos do ped do estúdio. `false` = rosto padrão do freemode |
| `ChromaKey` | `green` | Fundo padrão, `green` ou `magenta`. Cada parte pode ter o seu no editor (modo Estúdio) |

O enquadramento de cada parte fica em `CAMERAS` e `PARTS` no
`client/studio.lua` (presets do uz_AutoShot). Peça mal enquadrada se ajusta lá.

## Como funciona

### A cena (`client/studio.lua`)

- ped freemode do gênero pedido em `vector3(0, 0, -150)`, **embaixo do mapa** —
  não há cenário pra aparecer nem pra streamar. O player não é movido, só fica
  congelado e invencível
- **routing bucket 999** durante o lote
- **green screen** de 6 faces com `DrawPoly` (cada face nas duas ordens de
  winding, porque `DrawPoly` é face única) + **5 luzes** (`DrawLightWithRange`)
- **máscara de chroma na cabeça** (`DrawMarker` 28 sobre o `SKEL_Head`) nas partes
  com `hideHead`, senão a jaqueta sai com uma cabeça flutuando
- o que não está em `visible` recebe drawable **-1**, que remove o componente —
  menos a **cabeça**, que o FiveM não aceita vazia (o erro travava o lote)
- cada peça é **pré-carregada** (`SetPedPreloadVariationData` +
  `HasPedPreloadVariationDataFinished`, até `PreloadTimeout`) antes de aplicar —
  a técnica do uz_AutoShot que dispensa espera fixa
- tudo é redesenhado todo frame; uma guarda desmonta o estúdio depois de 1h

### A captura (`web/src/studio/gameCapture.ts`)

O CEF do FiveM entrega o frame do jogo pra um contexto WebGL do NUI. O gancho é
a sequência `CLAMP_TO_EDGE → MIRRORED_REPEAT → REPEAT` em `TEXTURE_WRAP_T` na
textura — **não é código morto**, é o handshake. Sem ela toda foto sai **azul**
(a cor da textura dummy, escolhida pra separar "handshake falhou" de "cena preta").

- o canvas fica **fora do DOM**, senão o CEF compositaria a captura sobre o jogo
- sem `preserveDrawingBuffer`: desenhar e ler no **mesmo** `requestAnimationFrame`
- `readPixels` devolve as linhas de baixo pra cima; o frame é invertido
- o frame é amostrado direto em `CaptureMaxWidth x CaptureMaxHeight` (é assim que o
  screencapture reduz): o chroma key roda em 960x540, não em 1920x1080

### O recorte

Porta do `removeChromaKey` do uz_AutoShot: alpha pela dominância da cor-chave com
rampa suave, **despill** (tira o reflexo verde da borda) e dois passes de
**feather** no alpha. Depois recorta o que sobrou opaco e centraliza num PNG
quadrado.

Antes do lote, o NUI espera o green screen ocupar **15% do quadro** (até ~10s): o
estúdio leva um tempo indeterminado pra streamar e disparar antes grava PNG preto.
O mesmo teste roda em cada foto — frame sem verde conta falha e não é gravado.

### A velocidade

O ritmo é do **Lua**, sem ida e volta com o NUI por peça:

1. `studio_run_part` recebe a lista de peças da parte (`[drawable, textura]`) e
   veste uma atrás da outra no ritmo do jogo: `SettleFrames` sem código (a peça
   aparecendo) e `HoldFrames` com o **código de frame** na tela
2. o código é uma fileira de `DrawRect` preto/branco no canto (4 bits de token da
   passada + 16 de índice da peça + paridade). Sai no frame do jogo, então cada
   captura diz sozinha qual peça fotografou (`web/src/studio/frameCode.ts`)
3. o NUI captura **todo frame**, lê o código e, se é uma peça nova, manda o frame
   pra um dos **Web Workers** (`process.worker.ts`, transferido sem cópia), que
   inverte as linhas, apaga o código, recorta e gera o webp
4. as fotos sobem **em lotes de 8, por HTTP** direto da NUI pro servidor
   (`POST /mri_Qappearance/upload/<token>`). O token sai só pra quem tem
   permissão, preso ao source. No início do lote a NUI testa (ping) e usa o
   primeiro que responder: **`http://127.0.0.1`** (servidor no mesmo PC — vai
   direto, sem a volta pela internet) e depois o proxy da Cfx.re. A NUI é https e o CEF só deixa o `fetch` sair pra
   **https** ou pra **localhost**, então o HTTP só vale com o proxy da Cfx.re
   (convar `web_baseUrl`, `*.users.cfx.re`) ou com o servidor na mesma máquina.
   Fora disso as fotos vão por evento latente (`studio_save_batch`, em bytes
   crus), que não passa de ~300 KB/s — a barra mostra "envio por evento". No
   start o servidor avisa no console qual dos dois vai usar
5. **freio de memória**: cada frame na fila ocupa ~2 MB. Com 64 na fila de
   recorte/envio a NUI pausa o Lua e retoma com 48 (a câmera acompanha o ritmo
   do envio). Recorte em 2 a 6 workers, conforme os núcleos da máquina. A barra
   mostra quantas fotos estão "recortando" e "enviando": é por ali que se acha
   o gargalo
6. peça que a captura perdeu (frame que o CEF pulou) é refeita no fim da parte,
   até 3 repassadas, cada uma segurando mais frames

Com 1 + 1 frames por peça, o teto é ~30 fotos/s a 60 FPS (~60/s a 120 FPS).
O limite real passa a ser o streaming das peças (`PreloadTimeout`).

### Onde a captura roda

Sempre na página principal do resource (a do `ui_page`), nos dois caminhos.
Pelo Qadmin, o painel pede pro host fechar antes de começar. A captura pega só o
frame do jogo (a NUI do CEF não entra), então a barra de progresso pode ficar
na tela o lote inteiro. HUD de outros resources é escondida pelo statebag `hideHud` (o mesmo que o mri_Qspawn usa).

### Gravação e entrega (`server/studio.lua`)

- PNG gravado em `studio/` dentro do resource
- o **nome sai dos campos validados no servidor**, nunca do client:

  ```
  cloth_m_c11-base-42           masculino, componente 11, peça 42 do jogo base (textura 0)
  cloth_m_c11-base-42-3         a mesma peça na textura 3
  cloth_f_p0-mp_f_xmas_01-7     feminino, prop 0, peça 7 da coleção mp_f_xmas_01
  (.webp ou .png)
  ```

- **por coleção, não pelo número global.** O número global de uma peça (o do
  menu) muda quando entra um pack ou DLC antes dela; coleção + número local
  não. O client calcula, com um ped local de cada gênero, onde cada coleção
  começa na numeração global de hoje (`studioLayouts` em `client/studio.lua`)
  e a NUI converte (`toCollection`/`toGlobal` em `web/src/studio/parts.ts`):
  o menu e o painel continuam falando o número global.
- a roupa salva do jogador segue o mesmo esquema: `drawable` (global) mais
  `collection`/`localDrawable` (`game/util.lua`); ao vestir, a coleção manda.
- `studio/index.json` guarda, por parte e coleção, uma máscara por número local
  (`sets.m_c11.base = "1111011..."`) e, pras texturas, uma por peça
  (`textures.m_c11.base["42"]`, 1 char por textura). Máscara e não contagem porque uma foto pode falhar no meio
- não entra no `files{}`: foto nova aparece na hora e nada pesa no download de
  quem conecta. A NUI é https e **não carrega imagem de `http://ip:porta`**
  (o CEF bloqueia como mixed content), então a foto chega de um destes jeitos:
  - servidor no proxy da Cfx.re (convar `web_baseUrl`, `*.users.cfx.re`): direto
    por HTTPS, `https://<servidor>.users.cfx.re/mri_Qappearance/studio/<nome>.png`
  - no caminho `studio_photo`, o client pede a foto ao servidor e recebe a imagem
    por evento latente (`studio:requestPhoto` → `studio:photo`), com identificador
    por pedido e timeout de 12s. Isso evita enviar imagens nas respostas comuns
    do ox_lib, que estavam expirando. A NUI guarda até 400 fotos em memória e
    limita a 6 pedidos simultâneos. A galeria mostra quando está carregando ou
    quando a foto falhou, em vez de deixar apenas o fundo vazio
- no fim do lote o índice vai pra todos os clients; o endereço da foto leva a
  versão do índice, então foto refeita não fica presa em cache

### No menu de roupa

A grade de drawables usa a foto do estúdio quando ela existe; se não carregar,
tenta a do CDN (`images.json`) e só então mostra o número. O grid de texturas
segue no CDN (as fotos são por drawable). `StudioUrl` no `images.json`: vazio =
servidor atual, `off` = desliga, URL = outro endereço. Ver `shared/IMAGES.md`.

## Se algo sair errado

Toda vez que o lote termina (ou é parado), o servidor acrescenta em `studio/log.txt` (os lotes se acumulam; passando de 8 MB os mais antigos saem)
com a configuração do lote, um resumo de cada passada e **cada falha com a
etapa e o motivo**:

- `carregar` — o Lua não conseguiu vestir a peça a tempo (streaming do ped,
  pré-carregamento ou índice do prop; diz o que ficou no ped e se a combinação
  é válida);
- `captura` — a peça apareceu com o código, mas nenhum frame capturado a pegou;
- `recorte` — o frame chegou, mas saiu sem fundo, sem nada da peça (só pontos soltos) ou semitransparente (o fundo comeu a peça). Essas não são gravadas: peça que o verde comer é refeita no fim da parte com fundo magenta;
- `gravação` — o servidor recusou ou o envio falhou.

| Sintoma | Provável causa |
|---|---|
| Toda foto azul | o handshake da textura não ligou — alguém "limpou" os `TEXTURE_WRAP_T` |
| "o estúdio não apareceu na tela" | a cena não renderizou em 10s; rode de novo |
| PNG todo transparente | o green screen cobriu o ped ou a câmera ficou dentro da caixa |
| Cabeça na foto de jaqueta | falta `hideHead` na parte ou a esfera de `HEAD_MASK` está pequena |
| Borda esverdeada / peça verde some | o lote já refaz com magenta o que o verde comer; se a parte inteira for verde, troque o fundo dela pra magenta no editor |
| Foto de cabeça pra baixo | orientação da textura nesse build: inverta o `UV` em `gameCapture.ts` |
| Peça sai igual à anterior | aumente `PreloadTimeout` ou `SettleFrames` |
| Barra mostra "envio por evento" | sem `web_baseUrl` (servidor fora do proxy HTTPS da Cfx.re) e sem ser localhost: o lote segue, limitado a ~300 KB/s. Baixar `IconQuality` ajuda |
| Muitas "refeitas" na barra | a captura está perdendo frames: suba `HoldFrames` pra 2 |
| Nenhuma foto sai, lote não anda | o código de frame não está sendo lido: algo desenha por cima do canto superior esquerdo |
| Menu não mostra a foto | com `StudioUrl` preenchido, o endereço tem que ser HTTPS e alcançável pelo client; vazio, confira o F8 por erro no callback `studio_photo` |
