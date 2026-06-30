# Sprites — convenção (Leva 4)

Como ligar a arte de uma entidade ao jogo. Sem PNG **ou** sem manifesto, a view mantém o
placeholder `ColorRect` (nada quebra).

## Onde fica a arte

```
assets/sprites/player/<id>.png      ← player  (id = "player")
assets/sprites/enemies/<id>.png     ← inimigos (id = ex. "enm_skeleton")
assets/sprites/bosses/<id>.png      ← bosses   (id = ex. "bss_guardian")
```

O `<id>` é o mesmo `id` do JSON da entidade (`data/enemies/…`, `data/bosses/…`); o do player
é fixo: `player`.

## Formato do spritesheet

- Grade de **células retangulares** `cell_w` × `cell_h` px (use `cell` sozinho p/ quadrada).
- **1 linha por animação** (cada `row`), frames nas colunas, da esquerda para a direita.
- **Resolução base 640×360** (retrô/8-bit; a janela faz upscale integer). O sprite é desenhado
  **1:1, sem reescala** (1 px da arte = 1 px lógico, filtro nearest).
- **Âncora nos pés**: desenhe a sola dos pés **colada na borda INFERIOR** do canvas,
  **centralizado na horizontal**, **virado para a direita** (o jogo espelha com `flip_h`). O
  engine alinha a base do canvas com a base da hitbox (o chão) — sem vão, sem cálculo de offset.
- A **hitbox** (footprint, quadrada) é independente do canvas e serve só para colisão/dano;
  pode ser menor que o desenho (partes decorativas podem transbordar).

  | Entidade | footprint (hitbox) | célula sugerida `cell_w × cell_h` | folha completa (L×A) |
  |---|---|---|---|
  | Player | 20 × 20 | **32 × 48** | 192 × 240 (6 col × 5 lin) |
  | Inimigo comum | 18 × 18 | **32 × 48** | 192 × 144 (6 × 3) |
  | Eco/elite | 22 × 22 | **40 × 56** | 240 × 168 (6 × 3) |
  | Boss normal | 34 × 34 | **64 × 80** | 384 × 240 (6 × 3) |
  | Great boss | 34 × 34 | **96 × 128** | 576 × 384 (6 × 3) |
  | Rei | 34 × 34 | **128 × 160** | 768 × 480 (6 × 3) |

  Todos os bosses compartilham a hitbox de 34 × 34; great bosses/Rei só usam canvas maior
  (overhang visual é ok). O canvas é flexível — desde que os pés fiquem na base, qualquer
  `cell_w × cell_h` funciona. Se um inimigo precisar de hitbox maior, ajuste o `box_size` na view.

## Manifesto: `data/sprites/<id>.json`

```json
{
  "cell_w": 32, "cell_h": 48,
  "animations": {
    "idle":   { "row": 0, "frames": 4, "fps": 6 },
    "run":    { "row": 1, "frames": 6, "fps": 10 },
    "attack": { "row": 2, "frames": 4, "fps": 12, "loop": false },
    "jump":   { "row": 3, "frames": 2, "fps": 8 },
    "dodge":  { "row": 4, "frames": 2, "fps": 12, "loop": false }
  }
}
```

`loop` é opcional (padrão `true`). `fps` é a velocidade da animação.

## Animações usadas por cada view

- **Player** (`PlayerView`): `idle`, `run`, `jump`, `dodge`, `attack`.
- **Inimigo / boss** (`EnemyView`/`BossView`): `idle`, `walk`, `attack`.

Animação ausente cai para `idle` (e, sem `idle`, a view simplesmente não troca). Então você pode
começar só com `idle` para ver a arte em jogo e ir adicionando as outras linhas depois.
O sprite é virado por `flip_h` conforme a direção — desenhe virado para a **direita**.
