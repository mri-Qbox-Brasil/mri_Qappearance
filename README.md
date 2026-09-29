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

## Documentation

Read the docs here: https://docs.illenium.dev

## Credits
- Forked from: https://github.com/iLLeniumStudios/illenium-appearance
- Original Script: https://github.com/pedr0fontoura/fivem-appearance
- Tattoo's Support: https://github.com/franfdezmorales/fivem-appearance
- Last Maintained Fork for QB: https://github.com/mirrox1337/aj-fivem-appearance
