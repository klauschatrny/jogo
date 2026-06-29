# Migração: top-down → side-scroller estilo Dead Cells

Plano de migração da apresentação de *A Torre da Vingança*, de **top-down ("birds-eye")**
para **plataforma de rolagem lateral** estilo Dead Cells, com **chão contínuo e plano**
(sem plataformas em alturas diferentes).

## Visão de design (definida com o autor)

- O nível é um **corredor horizontal plano**, percorrido **da esquerda para a direita**.
- Os inimigos **sempre vêm da direita** e avançam para a esquerda.
- Após limpar as waves de inimigos comuns, uma **porta no fim do corredor abre** e dá
  acesso à **sala do boss / mega boss**.
- Vencer o boss libera a **porta de saída**, levando ao **nível superior** da torre
  (o `_next_floor()` atual — a torre "sobe").
- Movimento do player: **esquiva (dodge-roll) + pulo** (pulo é evasivo, não de plataforma —
  não há nada para subir, mas serve para escapar de ataques/inimigos).
- A **sala do boss é uma cena separada** com transição em **fade**.

## Princípio arquitetural

**Nada em `src/core/` muda.** A migração vive inteira em `src/presentation/`. O split rígido
Core ↔ Presentation (ver `CLAUDE.md` / §2.3) garante que combate, progressão, augments,
balanceamento e todo o **sistema Nemesis/Ghost** migram intactos. Top-down vs lateral é uma
decisão puramente de apresentação.

### Decisão importante sobre a sala do boss

A transição para a sala do boss **NÃO** pode usar `change_scene_to_file` — isso destruiria o
`RunState`, `TowerManager` e `GhostRepository`, que vivem no `floor_scene` e precisam
sobreviver à run inteira. Padrão correto:

- `floor_scene` continua sendo o **orquestrador persistente** (segura o estado da run).
- Corredor e arena do boss viram **sub-cenas filhas**, instanciadas/liberadas por baixo de um
  **overlay de fade**. O estado da run nunca é recriado.
- Isso encaixa no `_phase` (`waves`/`boss`/`reward`) que já funciona como FSM provisório.

## Mapeamento design → código atual

| Design lateral                              | Onde já existe hoje                      |
|---------------------------------------------|-----------------------------------------|
| Percorrer dungeon esq→dir matando inimigos  | fase `"waves"` do `floor_scene`         |
| Inimigos sempre vêm da direita              | `_random_spawn_pos()` → spawn à direita |
| Porta abre após limpar os normais           | transição `waves` → `boss`              |
| Sala do boss / mega boss                    | fase `"boss"` (vira cena separada)      |
| Porta → nível superior                      | `_next_floor()` (torre sobe)            |
| Card de augment entre andares               | fase `"reward"` (intacta)               |

## Roadmap (Levas)

### Leva 0 — Fundação física (corredor plano lateral) — CONCLUÍDA
Objetivo: combate lateral funcionando, ainda como "arena", para validar o feel.
- `PlayerView`: movimento A/D + **gravidade + pulo + esquiva (i-frames)**, facing
  esquerda/direita, ataque horizontal (`attack_range` vira alcance lateral). Mantém slash/juice.
- `EnemyView`: gravidade + andar no chão **em direção horizontal** ao player (IA quase 1D).
- Chão = um único `StaticBody2D` (faixa sólida). `BossView`/`GhostView` herdam de graça.
- Inputs novos: `jump` (W/Espaço/seta-cima), `dodge` (Shift). Ataque migra para outra tecla
  para não colidir com pulo, se necessário.

### Leva 1 — Corredor + spawn lateral + câmera — CONCLUÍDA
- Corredor horizontal de **comprimento configurável** (vai para `floor_*.json`).
- Player começa na esquerda; câmera segue X com limites (não passa das bordas).
- Spawn **fora da tela à direita**; inimigos avançam para a esquerda.

### Leva 2 — Porta + sala do boss (cena separada com fade) — CONCLUÍDA
- Limpou as waves → **porta no fim do corredor abre**. Player anda até ela → fade →
  **sala do boss** (sub-cena dedicada). Fluxo nemesis/catarse idêntico.
- Boss caiu → porta de saída → `_next_floor()` (nível superior).

### Leva 3 — Feel Dead Cells
- Polimento de esquiva (i-frames, cooldown), combo de ataque, knockback lateral, hit-stop.
  Reaproveita o `Juice`.

### Leva 4 — Arte & ambientação — EM ANDAMENTO

**Resolução interna hi-fi (decidido):** o viewport subiu de 640×360 para **1920×1080**
(`stretch=canvas_items`, `aspect=keep`). Motivo: personagens detalhados/reconhecíveis
(few-pixel ficava ilegível). É 1:1 em monitores 1080p. Toda a apresentação foi reescalada
×3 via uma constante central `ViewScale.WORLD = 3.0`:
- Constantes de apresentação (física, layout, fontes, HUD) já estão nos valores ×3.
- Valores que vêm dos **dados do Core** (`move_speed`, `attack_range`) são multiplicados por
  `ViewScale.WORLD` em runtime — o Core e o balanceamento ficam intactos no espaço lógico.
- A arte deve ser autorada **nesse espaço** (ex.: personagem comum ~144px, base do bestiário ×3).

**Spritesheets** (`SpriteLoader` + manifesto, com fallback `ColorRect`):
- Arte: `res://assets/sprites/<subdir>/<id>.png` — grade de células quadradas, **1 linha por
  animação** (colunas = frames).
- Manifesto: `res://data/sprites/<id>.json` com `cell` e `animations`
  (`{ "row", "frames", "fps", "loop" }`). Sem PNG/manifesto → mantém o placeholder.
- Falta: integrar o `SpriteLoader` nas views (player/inimigos/boss) trocando o `ColorRect`.

**Ambientação (feito — placeholder procedural):** fundo com parallax por **bioma** (5 zonas do
bestiário, `data/biomes.json`): céu em gradiente + 2 camadas de silhuetas com scroll horizontal
manual (`BiomeBackground`, CanvasLayer atrás do mundo). O chão é tingido pela paleta do bioma; a
sala do boss usa a mesma paleta escurecida. Mapeamento: 10 andares por zona. Pronto para trocar as
silhuetas/gradiente por arte de parallax real depois.
