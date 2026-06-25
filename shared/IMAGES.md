# Sistema de Fotos — mri_Qappearance

Como a NUI monta o endereço das imagens de roupas/props e como configurar a fonte
(CDN, pasta local ou compatibilidade com `uz_AutoShot`).

---

## 1. Onde se configura

Tudo vive em **`shared/images.json`**. Esse arquivo é lido pela NUI em runtime
(`fetch('https://<resource>/shared/images.json')`), então ele **precisa estar
exposto no `files{}`** do `fxmanifest.lua`:

```lua
files {
  "html/**/*",
  "shared/images.json"
}
```

> Se o arquivo não existir ou não estiver no `files{}`, a NUI cai nos defaults
> embutidos no bundle (CDN MRI) e **nada do que você editar aqui terá efeito**.

Editou o `images.json`? Basta dar **restart no resource** — não precisa rebuildar a NUI.

---

## 2. Campos do `images.json`

```json
{
  "ImageLocal": "url",
  "ImageUrl": "https://assets.mriqbox.com.br/",
  "Layout": "default",
  "ImageExt": "",
  "ImageSources": {
    "peds": "peds/",
    "heritage": "parents/",
    "appearance": "peds/",
    "clothes": "clothing/",
    "accessories": "clothing/",
    "tattoos": "peds/tattoos/"
  }
}
```

| Campo | Valores | O que faz |
|---|---|---|
| `ImageUrl` | URL com `/` no final | Endereço base de onde as imagens são carregadas (CDN, host próprio ou `cfx-nui-...`). |
| `ImageLocal` | `url` \| `pasta` | `url` = imagens remotas (ext `webp`). `pasta` = imagens locais (ext `png`). Só afeta a extensão quando `ImageExt` está vazio. |
| `Layout` | `default` \| `autoshot` | Formato do nome do arquivo. Veja seção 3. |
| `ImageExt` | `""` \| `png` \| `webp` \| `jpg` | Força a extensão. Vazio = resolve sozinho (`autoshot`→`png`, senão depende de `ImageLocal`). |
| `ImageSources` | mapa de subpastas | Subpasta por categoria. **Só usado no layout `default`** (no `autoshot` a pasta é o próprio `componentId`). |

Chaves de `ImageSources` realmente consumidas: `clothes` (roupas), `accessories`
(props), `heritage`/`appearance` (herança), `tattoos`, `peds`.

---

## 3. Layouts e padrão de nomenclatura

A "cauda" do nome é sempre `{drawable}` (peça) ou `{drawable}_{texture}` (variação de
cor). O que muda entre os layouts é o **prefixo**.

### `default` — arquivos achatados numa pasta (CDN MRI)

```
{ImageUrl}{pasta}/{genero}_{componentId}_{drawable}[_{texture}].{ext}
```

| Tipo | Exemplo |
|---|---|
| Roupa (drawable) | `https://assets.mriqbox.com.br/clothing/male_11_5.webp` |
| Roupa (textura)  | `https://assets.mriqbox.com.br/clothing/male_11_5_0.webp` |
| Prop (drawable)  | `https://assets.mriqbox.com.br/clothing/male_prop_0_12.webp` |
| Prop (textura)   | `https://assets.mriqbox.com.br/clothing/male_prop_0_12_0.webp` |

### `autoshot` — pastas aninhadas (compatível com `uz_AutoShot`)

```
{ImageUrl}{genero}/{componentId|prop_propId}/{drawable}[_{texture}].{ext}
```

| Tipo | Exemplo |
|---|---|
| Roupa (drawable) | `https://cfx-nui-uz_AutoShot/shots/male/11/5.png` |
| Roupa (textura)  | `https://cfx-nui-uz_AutoShot/shots/male/11/5_0.png` |
| Prop (drawable)  | `https://cfx-nui-uz_AutoShot/shots/male/prop_0/12.png` |
| Prop (textura)   | `https://cfx-nui-uz_AutoShot/shots/male/prop_0/12_0.png` |

> `genero` = `male` / `female`. `componentId` é o slot nativo do GTA
> (2=cabelo, 3=braços, 4=pernas, 6=sapatos, 8=camiseta, 11=torso/jaqueta, etc).

---

## 4. Receitas prontas

**CDN MRI (padrão):**
```json
{ "ImageLocal": "url", "ImageUrl": "https://assets.mriqbox.com.br/", "Layout": "default" }
```

**uz_AutoShot (fotos geradas localmente):**
```json
{ "ImageLocal": "url", "ImageUrl": "https://cfx-nui-uz_AutoShot/shots/", "Layout": "autoshot" }
```

**Seu próprio host:**
```json
{ "ImageLocal": "url", "ImageUrl": "https://cdn.seuservidor.com/roupas/", "Layout": "default" }
```

---

## 5. Avisos importantes

- **Compatibilidade `autoshot` cobre roupas + props.** Tatuagem, herança (pais) e
  head overlays continuam usando o layout/CDN configurado em `ImageSources` — o
  `uz_AutoShot` não gera essas categorias no mesmo esquema.
- **`uz_AutoShot` precisa estar rodando** no server pra `cfx-nui-uz_AutoShot/`
  resolver, e as fotos já devem ter sido geradas (`/shotmaker`).
- **Texturas no `uz_AutoShot`:** por padrão ele gera com `CaptureAllTextures = false`
  (só a textura 0). Nesse caso o grid de *drawables* funciona, mas o grid de
  *texturas* fica sem imagem. Para ter todas as variações de cor, gere com
  `CaptureAllTextures = true` no `Customize.lua` do uz_AutoShot.
- **Modo `pasta` (imagens locais):** as imagens precisam estar acessíveis pela NUI,
  ou seja, dentro do resource e adicionadas ao `files{}` do `fxmanifest.lua`.

---

## 6. Onde isso vive no código (referência)

- Leitura da config: `web/src/components/Appearance/utils/SettingsBuilder.ts`
- Fetch do json: `web/src/components/Appearance/utils/ConfigFactory.ts`
- Montagem da URL (fonte única): `web/src/components/Appearance/utils/imageUrl.ts`
- Uso: `Components.tsx` (roupas) e `Props.tsx` (props)

Mexeu em qualquer um desses `.ts/.tsx`? Aí sim precisa rebuildar a NUI
(`cd web && npm run build-game`). Mexeu só no `images.json`? Só restart.
