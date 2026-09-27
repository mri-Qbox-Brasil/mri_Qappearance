# Importar / exportar personagem

Botão com as setas (⇄) no rodapé do menu de aparência. O código fica em
`game/transfer.lua`, e a janela em `web/src/components/Appearance/components/TransferModal.tsx`.

- **Exportar**: copia o código do personagem para a área de transferência.
  O código é um JSON com `format = "mri_appearance"`. Cada peça vai com a
  coleção e o número local dela, então o código funciona em outro servidor com
  o mri_Qappearance mesmo que ele tenha outros packs de roupa. Uma peça cuja
  coleção não existe lá cai no número global.
- **Importar**: cole um código exportado ou o JSON do personagem do
  `nation_creator` (chaves `shapeMix`, `hair-color`, `facialHair-opacity` etc.).
  O formato é reconhecido sozinho. Um JSON embrulhado em `{ "skin": ... }` ou
  `{ "data": ... }` também é aceito.

O import aplica no ped só as partes que o menu aberto permite. Por exemplo, a
barbearia não troca roupa, e trocar de sexo exige o menu de personagem. Depois
o jogador confirma no ✓, que salva normalmente, e o custo da loja continua
valendo.

Da Nation vêm rosto, herança, cabelo, pelos, maquiagem e olhos. Roupa,
acessórios e tatuagens continuam como estão no ped. O mapeamento de campos
segue o snippet da comunidade ("Função para transformar o appearance do
nation_creator para o illenium").
