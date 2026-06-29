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

- Grade de **células quadradas** de lado `cell` px.
- **1 linha por animação** (cada `row`), frames nas colunas, da esquerda para a direita.
- Resolução hi-fi (viewport 1920×1080): autore no espaço do jogo. Tamanhos sugeridos de célula:
  comum **144** (= 48 base × 3), elites 144–192, bosses 192–288, great bosses/Rei 288–384.

## Manifesto: `data/sprites/<id>.json`

```json
{
  "cell": 144,
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
