# Cenário — fundo (parallax) + terreno

Arte de ambiente. **Sem os PNGs, o fundo cai no placeholder procedural** (gradiente + silhuetas de
`ColorRect`) — nada quebra. Solte os arquivos e eles aparecem.

## Parallax: N camadas, definidas em `data/biomes.json`

O fundo é uma **lista ordenada de camadas** (de trás para a frente) declarada em
`parallax_default` (`data/biomes.json`). Cada entrada:

```json
{ "tex": "res://assets/bg/default/layer3.png", "speed": 0.28, "drift": 0.0 }
```

- **`speed`** — fração do movimento da câmera. `0` = fixa (céu), `1` = colada no mundo.
  Quanto **mais perto do player**, **maior** a speed. É isso que cria a sensação de profundidade.
- **`drift`** — px/s de deslocamento próprio, contínuo, mesmo com o player parado (vento nas nuvens).
  `0` = só se move com a câmera.

Um bioma pode ter seu **próprio** conjunto pondo uma chave `"parallax"` no seu objeto em
`biomes.json` (mesmo formato); sem ela, usa o `parallax_default`.

### Conjunto atual (`assets/bg/default/`, floresta — usado em todos os biomas por enquanto)

| Arquivo | Conteúdo | speed | drift |
|---|---|---|---|
| `layer6.png` | céu (opaco, estático) | 0.00 | — |
| `layer5.png` | nuvens distantes | 0.10 | 3 px/s |
| `layer4.png` | nuvens próximas | 0.16 | 6 px/s |
| `layer3.png` | árvores distantes | 0.28 | — |
| `layer2.png` | árvores médias | 0.40 | — |
| `layer1.png` | árvores próximas (a mais à frente) | 0.55 | — |

## Como desenhar uma camada

- **Tamanho:** altura **360** (a tela inteira); largura **≥ 640**, de preferência **1280**
  (= 2 telas, dá mais variedade antes de repetir). Desenhada **1:1** — o texel é o do seu arquivo,
  não há ampliação. O comprimento do nível é irrelevante: o tile repete sozinho.
- **Emendável (seamless):** a coluna de pixels da **borda esquerda** tem que casar com a da
  **borda direita**, senão aparece uma costura quando o tile repete.
- **Transparência:** só a camada mais ao fundo (o céu) é opaca. Todas as outras precisam de
  **fundo transparente** — o que ficar vazio deixa a camada de trás aparecer.
- Camadas da frente podem ir até a base do canvas: o terreno do nível é desenhado **por cima**
  (mundo), então não fica buraco.

## Terreno (separado do parallax)

```
assets/bg/<bioma>/ground.png    ← tile do chão, repetido na horizontal
```

Biomas: `ossuary`, `swamp`, `forge`, `crypt`, `shadow`. Nativo **64 × 32**, ampliado **×2** no jogo
(texel 2, igual aos personagens); topo = linha do chão. Precisa emendar na horizontal. Abaixo dele
há um chão de cor sólida de reserva, então nunca sobra buraco. A **colisão** do chão é um
`StaticBody2D` separado do desenho.

A sala do boss escurece tudo automaticamente (não precisa de arte separada).
