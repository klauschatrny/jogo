# Cenário — fundo (parallax) + terreno por bioma

Arte de ambiente por bioma. **Sem o PNG, a camada cai no placeholder procedural** (gradiente +
silhuetas de `ColorRect` / chão de cor sólida) — nada quebra. Solte os arquivos e eles aparecem.

## Onde fica (um conjunto por bioma)

```
assets/bg/<bioma>/sky.png       ← céu / fundo distante
assets/bg/<bioma>/far.png       ← silhueta distante (parallax lento)
assets/bg/<bioma>/mid.png       ← silhueta média   (parallax mais rápido)
assets/bg/<bioma>/ground.png    ← terreno (tile horizontal)
```

Biomas (`<bioma>` = id, 10 andares cada): `ossuary`, `swamp`, `forge`, `crypt`, `shadow`.
Pode começar com **um** bioma (ex.: `ossuary`) e só ele usa arte; o resto segue procedural.

## Dimensões (texel 2 — mesmo "tamanho de pixel" dos personagens)

Desenhe no tamanho **nativo**; o jogo amplia **×2** com filtro nearest (pixel nítido).

| Arquivo | Nativo (desenhe) | No jogo (×2) | Repetição | Observações |
|---|---|---|---|---|
| `sky.png`    | **320 × 180** | 640 × 360 | estático (sem scroll) | cobre a tela inteira; pode ser gradiente/paisagem |
| `far.png`    | **320 × 120** | 640 × 240 | horizontal **sem emenda** | **fundo transparente**; base encosta no horizonte |
| `mid.png`    | **320 × 120** | 640 × 240 | horizontal **sem emenda** | **fundo transparente**; mais perto que `far` |
| `ground.png` | **64 × 32**   | 128 × 64 | horizontal **sem emenda** | topo = linha do chão; ~30px de arte ficam visíveis |

## Regras

- **Sem emenda (seamless):** a coluna de pixels da **borda esquerda** tem que casar com a da
  **borda direita** — senão aparece uma costura quando o tile repete.
- **`far`/`mid` transparentes:** desenhe só a silhueta; o que ficar transparente deixa o céu
  aparecer. A **base do desenho** (parte de baixo do canvas) é encostada na linha do chão.
- **Largura das silhuetas = 320 nativo** (vira 640 = um "padrão" de parallax). Se fugir disso,
  a largura é esticada para 640 e pode distorcer um pouco.
- **`ground` repete na horizontal** ao longo do corredor (que é longo); a altura é 1 tile só.
  Abaixo dele há um chão de cor sólida de reserva, então nunca sobra buraco.
- **Tom por andar:** a sala do boss escurece tudo automaticamente (não precisa de arte separada).
- O **céu** é opcional: sem `sky.png`, fica o gradiente procedural por bioma (cores no
  `data/biomes.json`).
