# Cenário — fundo (parallax) + terreno

O jogo tem **um cenário só** (floresta). A ideia de vários biomas foi abandonada — não havia o que
os distinguisse. Tudo é declarado em **`data/environment.json`**; nada de caminho de arte no código.

**Sem os PNGs, o fundo cai no placeholder procedural** (gradiente + silhuetas de `ColorRect`) — nada
quebra. Solte os arquivos e eles aparecem.

## Parallax: N camadas (chave `parallax`)

Uma **lista ordenada de camadas**, de trás para a frente. Cada entrada:

```json
{ "tex": "res://assets/bg/default/layer3.png", "speed": 0.28, "drift": 0.0 }
```

- **`speed`** — fração do movimento da câmera. `0` = fixa (céu), `1` = colada no mundo.
  Quanto **mais perto do player**, **maior** a speed. É isso que cria a sensação de profundidade.
- **`drift`** — px/s de deslocamento próprio, contínuo, mesmo com o player parado (vento nas nuvens).
  `0` = só se move com a câmera.

### Conjunto atual (`assets/bg/default/`, floresta)

| Arquivo | Conteúdo | speed | drift |
|---|---|---|---|
| `layer6.png` | céu (opaco, estático) | 0.00 | — |
| `layer5.png` | nuvens distantes | 0.10 | 3 px/s |
| `layer4.png` | nuvens próximas | 0.16 | 6 px/s |
| `layer3.png` | árvores distantes | 0.28 | — |
| `layer2.png` | árvores médias | 0.40 | — |
| `layer1.png` | árvores próximas (a mais à frente) | 0.55 | — |

### Como desenhar uma camada

- **Tamanho:** altura **360** (a tela inteira); largura **≥ 640**, de preferência **1280**
  (= 2 telas, dá mais variedade antes de repetir). Desenhada **1:1** — o texel é o do seu arquivo,
  não há ampliação. O comprimento do nível é irrelevante: o tile repete sozinho.
- **Emendável (seamless):** a coluna de pixels da **borda esquerda** tem que casar com a da
  **borda direita**, senão aparece uma costura quando o tile repete.
- **Transparência:** só a camada mais ao fundo (o céu) é opaca. Todas as outras precisam de
  **fundo transparente** — o que ficar vazio deixa a camada de trás aparecer.
- Camadas da frente podem ir até a base do canvas: o terreno do nível é desenhado **por cima**
  (mundo), então não fica buraco.

## Terreno (chave `ground`)

```json
"ground": {
  "tex": "res://assets/bg/ground/grassground.png",
  "fill": "2e1f2c",
  "edge": "6bb053"
}
```

Tile de **64 × 32** nativo, ampliado **×2** no jogo (texel 2, igual aos personagens); o topo do PNG
é a linha do chão. Precisa emendar na horizontal. Desenhado **no mundo**, por cima do parallax.

- **`fill`** — cor sólida pintada **sob** o tile, como reserva (se a câmera tremer, nunca abre vão).
  Use a cor da **base** do tile (a terra) e a emenda some. Hoje é exatamente a cor da última linha
  do `grassground.png`.
- **`edge`** — linha fina desenhada **só se o PNG sumir**; é o fallback, não aparece normalmente.

A **colisão** do chão é um `StaticBody2D` separado do desenho. A sala do boss escurece tudo
automaticamente (não precisa de arte separada).
