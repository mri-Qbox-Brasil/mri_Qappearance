# Lojas pelo painel

Lojas de roupa, barbearias, estúdios de tatuagem e cirurgia plástica são
gerenciadas no painel (`/adminappearance` ou plugin **Aparência** do
mri_Qadmin), aba **Lojas**. Ideia do [lsk-illenium](https://github.com/luska1337/lsk-illenium),
feita dentro do nosso painel.

## Onde ficam

- `stores.json` na raiz do resource (fora do git). Na primeira vez que o
  servidor sobe sem ele, o arquivo é criado a partir do `Config.Stores`.
  **Depois disso o `Config.Stores` não é mais lido**: edite pelo painel.
- Quem valida e grava é o servidor (`server/stores.lua`). Cada alteração vai
  pra todos os clients na hora (`client/stores.lua`): zonas, blips e target são
  refeitos sem restart.
- Permissão: a mesma do estúdio (`mri_Qappearance.studio`, `command` ou master
  do mri_Qadmin).

## O que dá pra fazer

- **Nova loja aqui**: cria na posição e direção do seu personagem.
- **Editar**: tipo, nome (vira o nome do blip), posição (**Usar minha posição**),
  tamanho e rotação da zona, blip (padrão do tipo / mostrar / esconder),
  restrição a um emprego ou gangue do qbx_core e, opcional, o ped do target.
- **Ir**: teleporta pra loja e fecha o painel.
- **Apagar**.

Lojas antigas do config com zona por pontos (`usePoly`) continuam assim até
alguém usar "Usar minha posição", que troca por uma zona em caixa.

## Campos (`stores.json`)

| Campo | O que é |
|---|---|
| `id` | número da loja |
| `type` | `clothing`, `barber`, `tattoo` ou `surgeon` |
| `label` | nome no blip (vazio = nome do tipo em `Config.Blips`) |
| `coords` | `x, y, z, w` (w = direção) |
| `size`, `rotation` | zona em caixa |
| `usePoly`, `points` | zona por pontos (só lojas vindas do config) |
| `showBlip` | ausente = `Config.Blips[type].Show`; `true`/`false` força |
| `job` / `gang` | só esse emprego/gangue usa e vê o blip |
| `targetModel`, `targetScenario` | ped do target (com `Config.UseTarget` e peds ligados) |

Preço continua por tipo (`Config.ClothingCost`, `BarberCost`, `TattooCost`,
`SurgeonCost`).
