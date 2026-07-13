# Áudio

## Trilha (música)

Data-driven, como todo o resto: as faixas são declaradas em **`data/audio.json`** e tocadas por
**id** pelo autoload `Music` (`src/autoload/music.gd`). Nenhum caminho de arquivo ou volume
aparece no código de jogo.

```json
"boss": {
  "stream": "res://assets/audio/music/boss_makai_symphony.mp3",
  "volume_db": -12.0,    // ganho da faixa (0 = original; negativo abaixa)
  "loop": true,          // repete ao chegar no fim (a luta pode durar mais que a música)
  "fade_in": 0.6,        // segundos de fade ao entrar
  "fade_out": 2.0        // segundos de fade ao sair (usado por Music.stop() sem argumento)
}
```

```gdscript
Music.play("boss")    # toca; se já for a faixa atual, não reinicia
Music.stop()          # fade-out com o tempo declarado na faixa
Music.stop(0.0)       # corta na hora
```

Toca **uma** faixa por vez. `Music` é presentation: o Core nunca fala com ele — quem decide o
que toca é a cena.

### Faixas atuais

| id | arquivo | quando |
|---|---|---|
| `boss` | `music/boss_makai_symphony.mp3` (Makai Symphony, versão *extended*) | entra ao pisar na sala do chefe (junto com a cutscene de entrada) e se cala quando a luta acaba — vitória ou morte |

Fora da sala do boss ainda não há trilha: `floor_scene` chama `Music.stop()` ao começar um nível
comum. Para acrescentar ambientação, basta declarar a faixa no `audio.json` e chamá-la de lá.

## Arquivos-fonte

Os originais (inclusive os que ainda não estão no jogo) ficam em `assets/Design/Audio/`, que tem
um `.gdignore` — o Godot não os importa. Para usar uma faixa, copie-a para `assets/audio/music/`
com um nome estável e declare-a no `audio.json`.

MP3 e OGG funcionam. Depois de soltar um arquivo novo fora do editor, rode
`godot --headless --import` para gerar o `.import` — sem ele, `ResourceLoader.exists()` falha e
a faixa é ignorada (com um aviso, sem quebrar).

## SFX

Mesma ideia, no bloco `"sfx"` do `audio.json`, tocados pelo autoload `Sfx`
(`src/autoload/sfx.gd`). Cada id tem uma **lista de variações** — é assim que o som não fica
repetitivo:

```gdscript
Sfx.play("skeleton_attack")     # rodízio: alterna as variações a cada toque
Sfx.play("player_attack", 1)    # variação fixa: quem chama escolhe o índice
Sfx.loop("player_footsteps")    # som contínuo, cortável; loop_stop() corta onde estiver
Sfx.sustain("ogre_steps", ativo)  # ciclo que NUNCA é cortado no meio de uma passada (ver abaixo)
Sfx.play("")                    # id vazio = silêncio (é uma configuração válida)
```

Sons curtos tocam em 8 vozes reutilizáveis, então golpes simultâneos não se cortam.

| id | variações | quando | quem dispara |
|---|---|---|---|
| `player_dodge` | 1 (há uma 2ª desenhada, ainda fora do jogo) | cada rolamento | `PlayerView._start_dodge()` |
| `player_footsteps` | 1 (ciclo de 1,3 s, em loop) | correndo no chão | `PlayerView._update_footsteps()` — corta ao parar, pular, rolar ou travar no ataque |
| `skeleton_attack` | 2 | cada golpe de esqueleto | `EnemyView._resolve_attack()` — rodízio automático |
| `ogre_steps` | 1 (ciclo de 5 passadas, 1/s) | o ogro **andando** (perseguindo ou avançando no windup do melee; a investida não conta) | `OgreView._process()` via `Sfx.sustain` |
| `ogre_rage` | 1 | o ogro entrando em fúria (50/35/15% de vida), no windup da investida | `OgreView._start_special()` |
| `ogre_tired` | 1 (3,0 s — a duração exata do stun) | o ogro ofegante no stun que segue a investida | `OgreView._begin_tired()` |
| `ogre_landing` | 1 | o ogro caindo na arena, na cutscene de entrada | `floor_scene._boss_intro()` — tocado **adiantado** para o baque do clipe (`impact_at`) cair no instante do pouso |

### `sustain` — ciclos que não podem ser picotados

Os passos do ogro são um **ciclo** (5 passadas em 4,97 s, uma a cada 1,00 s, a 1ª em 0,12 s — medido
no arquivo). Cortar o loop na hora em que ele para de andar picotaria uma passada pela metade.
`Sfx.sustain(id, ativo)` resolve isso: enquanto `ativo`, roda em loop; quando deixa de ser, segue
tocando até o próximo **ponto de silêncio** (um triz antes da passada seguinte) e só então cala.
A grade vem do JSON (`step_every`, `first_step`) — reexportou o som com outra cadência, corrija-os.

Quem usa `sustain` chama a função **todo frame**, e o silêncio é o padrão: um estado que não afirme
"estou andando" naquele frame fica mudo por omissão (foi assim que a baderna do ogro deixou de
prender o som dos passos).

O **golpe do player não tem som** por ora (a arte de áudio foi descartada).

Quem tem som é **data-driven**, não está no código:

- inimigo → `"attack_sfx": "skeleton_attack"` em `data/enemies/*.json` (sem a chave, o golpe é mudo —
  é o caso do Necromante e do ogro, que têm ataques próprios);
- boss → `"landing_sfx"` (impacto da entrada), `"rage_sfx"` (grito da fúria) e `"tired_sfx"`
  (stun pós-investida) em `data/bosses/*.json` (cada boss ganha os seus; sem a chave, fica mudo).
