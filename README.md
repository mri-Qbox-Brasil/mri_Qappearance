# mri_Qappearance
Open source project by MRI QBOX BRASIL: 
A fork from illenium-appearance replacement for clothing resources for various frameworks

<div align='center'><h1><a href='https://docs.illenium.dev/free-resources/illenium-appearance/installation/'>Documentation</a></h3></div>
<br>

<img src="https://i.imgur.com/ltLSMmh.png" alt="illenium-appearance with Tattoos" />

Discord: https://discord.illenium.dev

**Note:** Do **NOT** use the `main` branch as it will most likely be broken for you. NO SUPPORT WILL BE PROVIDED IF YOU USE IT. Only use the [latest release](https://github.com/iLLeniumStudios/illenium-appearance/releases/latest)

## Supported Frameworks

- qb-core
- ESX
- ox_core

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core) (Latest) (Only for qb-core based servers)
- [es_extended](https://github.com/esx-framework/esx-legacy) (Latest) (Only for ESX based servers)
- [ox_core](https://github.com/overextended/ox_core) (experimental) (Only for ox_core based servers)
- [ox_lib](https://github.com/overextended/ox_lib)
- [qb-target](https://github.com/BerkieBb/qb-target) (Optional) (Only for qb-core based servers)

## Features

- Everything from standalone fivem-appearance
- UI from OX Lib
- Player outfits
- Rank based Clothing Rooms for Jobs / Gangs
- Job / Gang locked Stores
- Tattoo's Support
- Hair Textures
- Polyzone Support
- Ped Menu command (/pedmenu) (Configurable)
- Reload Skin command (/reloadskin)
- Improved code quality
- Plastic Surgeons
- qb-target Support
- Skin migration support (qb-clothing / old fivem-appearance / esx_skin)
- Player specific outfit locations (Restricted via CitizenID)
- Makeup Secondary Color
- Blacklist / Limit Components & Props to certain Jobs / Gangs / CitizenIDs / ACEs (Allows you to have VIP clothing on your Server)
- Blacklist / Limit Peds to certain Jobs / Gangs / CitizenIDs / ACEs
- Persist Job / Gang Clothes on reconnects / logout
- Themes Support (Default & QBCore provided out of the box)
- Disable Components / Props Entirely (Clothing as items support)

## New Preview (with Tattoos)

https://streamable.com/qev2h7

## Tema da suíte MRI

A NUI segue o tema da suíte pelo `@mriqbox/ui-kit` e muda ao vivo, sem restart:

| O que | De onde vem |
|---|---|
| Cor de destaque | convar `mri:color` (`getConfig` e `updateAccentColor`) |
| Cor de fundo | convar `mri:backgroundColor` (`getConfig` e `updateBackgroundColor`) |
| Tema dark/glass, opacidade, fonte, radius, cores de status | `/uiconfig` do ox_lib (`getUiConfig` e `ox_lib:uiConfigChanged`) |

Dentro do mri_Qadmin (estúdio como plugin), o Qadmin manda tudo isso pelo bridge.
A NUI só usa os tokens do kit (`primary`, `background`, `card`, `border`, `success`...)
e marca as superfícies com `mri-surface` / `mri-surface-card`. A fonte vem do kit; o
resource não hospeda fonte. Guia: `web/node_modules/@mriqbox/ui-kit/THEMING.md`.

## Câmera do criador

No criador de personagem a câmera é um rig próprio (`game/creator_camera.lua`, entrada em
`web/src/flows/creator/cameraRig.ts`). Cada etapa tem o seu enquadramento e o rig mexe a partir dele:

- **Arrastar na horizontal** gira o personagem. Soltando com velocidade, ele continua girando e para com atrito.
- **Arrastar na vertical** sobe e desce a câmera. A direção do arrasto trava nos primeiros pixels.
- **Roda do mouse** (ou arrastar com o botão direito) aproxima a câmera de verdade, em direção ao ponto sob o cursor.
- Passando do limite (rosto ao corpo inteiro, pés à cabeça), a câmera resiste e volta suave.
- **Duplo clique** volta ao enquadramento da etapa; trocar de etapa também.
- A/D giram com a mesma suavização.

Sensibilidade, limites e atrito ficam nas constantes do topo de `game/creator_camera.lua`.

## Rostos e looks prontos

O criador abre na etapa **Rosto** (gênero e rostos prontos) e a etapa **Roupa** começa na aba
**Looks**. Os prontos são montados por admins no próprio criador:

1. Abra o criador em você (painel, aba **Jogadores**, com o seu ID).
2. Monte o rosto (ou a roupa) e clique no marcador do rodapé: na etapa Roupa salva um look,
   nas outras salva um rosto (pais, traços, marcas, cabelo e cor dos olhos).
3. No painel, aba **Prontos**, dá pra renomear, apagar e tirar as fotos: **Tirar fotos que
   faltam** (ou **Refazer foto** num item) fecha o painel e o estúdio fotografa cada pronto no
   fundo verde, rosto em close com a roupa inicial e look de corpo inteiro com o rosto do estúdio.
   As fotos ficam em `studio/preset_face_<id>` e `studio/preset_look_<id>` e saem junto quando o
   pronto é apagado.

Ficam em `data/presets.json` (fora do git), por gênero. As peças são gravadas com coleção e
número local, então pack novo de roupa não embaralha os looks. Para jogador sem nenhum look
pronto, a aba Looks some e a etapa Roupa abre direto no guarda-roupa.

## Recriar personagem

Um admin pode mandar um jogador (ou ele mesmo) de volta pro criador de personagem, onde
ele estiver, pelo painel `/adminappearance`, aba **Jogadores** (com o próprio ID, abre
em você). Mesma permissão do painel (`mri_Qappearance.studio`, `command`
ou `qadmin.master`).

- O criador abre com o personagem como ele está; dá pra mudar tudo, inclusive o gênero.
- Ao segurar "Criar", a aparência nova é salva. "Sair" (ou Esc) pede confirmação e devolve o personagem como estava.
- Enquanto cria, o jogador fica numa dimensão só dele e volta pro mesmo lugar no fim.
- Não abre se ele estiver morto, num veículo ou com o menu de aparência aberto; o admin recebe o motivo.
- Cada uso fica no console do servidor: `[mri_Qappearance] <admin> mandou <jogador> (id N) recriar o personagem`.

## Documentation

Read the docs here: https://docs.illenium.dev

## Credits
- Forked from: https://github.com/iLLeniumStudios/illenium-appearance
- Original Script: https://github.com/pedr0fontoura/fivem-appearance
- Tattoo's Support: https://github.com/franfdezmorales/fivem-appearance
- Last Maintained Fork for QB: https://github.com/mirrox1337/aj-fivem-appearance
