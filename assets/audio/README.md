# Áudio

## Volume (o que o jogador controla)

**ESC** abre as **Opções** — no menu principal e no meio da run (aí ele também pausa). Dois
controles: **MÚSICA** e **EFEITOS**, de 0% (mudo) a 100%. Muda na hora e é gravado em
`user://settings.json`, então volta assim no próximo jogo.

Por baixo (`src/autoload/audio_settings.gd`) são dois **buses de áudio** (`Music` e `SFX`) sob o
Master: `Music` toca no primeiro, `Sfx` no segundo, e o slider mexe no volume do bus. Não confunda
com os `volume_db` de cada som no `audio.json` — **aqueles são a mixagem** (a relação entre os sons,
que é decisão de design) e **este é a torneira geral** (preferência do jogador). Mexer num não
estraga o outro.

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
Sfx.play("skeleton_attack")         # rodízio: alterna as variações a cada toque
Sfx.play("player_attack", 1)        # variação fixa: quem chama escolhe o índice
Sfx.sustain("ogre_steps", andando)  # ciclo de passadas; nunca corta uma no meio (ver abaixo)
Sfx.play("")                        # id vazio = silêncio (é uma configuração válida)
```

Sons curtos tocam em 8 vozes reutilizáveis, então golpes simultâneos não se cortam.

Uma variação **não precisa de um arquivo novo**: a chave opcional `"pitch"` dá tons diferentes à
mesma amostra (`"pitch": [1.0, 0.92]` = duas variações, a 2ª mais grave). O número de variações é o
maior entre `streams` e `pitch`, e as duas listas são percorridas em ciclo — dá para combinar
vários arquivos com vários tons.

| id | variações | quando | quem dispara |
|---|---|---|---|
| `player_attack` | 2 (**um arquivo, dois tons** — ver `pitch`) | cada golpe do player | `PlayerView._attack()` — a variação é o **passo do combo**: sai tom normal, grave, normal; parar deixa o combo expirar e o próximo golpe volta ao 1º |
| `player_dodge` | 1 (há uma 2ª desenhada, ainda fora do jogo) | cada rolamento | `PlayerView._start_dodge()` |
| `player_footsteps` | 1 (ciclo na grama: 0,76 s, 3 passadas) | correndo no chão | `PlayerView._update_footsteps()` via `Sfx.sustain` — cessa ao parar, pular, rolar ou travar no ataque |
| `skeleton_attack` | 2 | cada golpe de esqueleto | `EnemyView._resolve_attack()` — rodízio automático |
| `skeleton_hurt` | 3 (**um arquivo, três tons**) | esqueleto levando dano e sobrevivendo | `EnemyView.apply_damage()` — rodízio: apanhar em sequência não repete o mesmo tom |
| `skeleton_death` | 1 | esqueleto levando o golpe **fatal** | `EnemyView.apply_damage()` — no lugar do som de dano |
| `ogre_steps` | 1 (ciclo de 5 passadas, 1/s) | o ogro **andando** | `OgreView._process()` via `Sfx.sustain` |
| `ogre_charge_steps` | — (2 batidas recortadas do arquivo da **aterrissagem**) | o ogro **correndo** (investida) | `OgreView._tick_charge_steps()` via `Sfx.play_step` — alterna as duas, uma a cada 0,26 s |
| `ogre_hurt` | 3 (**um arquivo, três tons**) | o ogro levando dano | `EnemyView.apply_damage()` — o mesmo caminho dos esqueletos (`hurt_sfx` no JSON do boss) |
| `ogre_rage` | 1 | o ogro entrando em fúria (50/35/15% de vida), no windup da investida | `OgreView._start_special()` |
| `ogre_wall_hit` | 1 | o ogro se espatifando na **parede** ao fim da investida (não toca se ela acabar por tempo, sem bater em nada) | `OgreView._tick_charge()` |
| `ogre_tired` | 1 (3,0 s — a duração exata do stun) | o ogro ofegante no stun que segue a investida | `OgreView._begin_tired()` |
| `ogre_landing` | 1 | o ogro caindo na arena, na cutscene de entrada | `floor_scene._boss_intro()` — tocado **adiantado** para o baque do clipe (`impact_at`) cair no instante do pouso |

### `sustain` — ciclos que não podem ser picotados

Passos são **ciclos**: o do ogro tem 5 passadas em 4,97 s (uma a cada 1,00 s); o do player, 3 em
0,76 s (uma a cada ~0,25 s). Cortar o loop no instante em que ele para de andar picotaria uma
passada pela metade. `Sfx.sustain(id, ativo)` resolve: enquanto `ativo`, roda em loop; quando deixa
de ser, segue tocando até o próximo **ponto de silêncio** — um triz antes da passada seguinte, ou a
emenda do loop se não houver outra — e só então cala. A espera é de no máximo um `step_every`.

A grade vem do JSON (`step_every`, `first_step`, `step_dur`), **medida no arquivo**. Reexportou o
som com outra cadência? Corrija esses números, senão o corte cai no lugar errado.

### `play_step` — recortar batidas de um arquivo e remontar a cadência

`Sfx.play_step(id, i)` toca **uma batida isolada** do arquivo (a i-ésima, em rodízio), cortando-a
depois de `step_dur`. Quem chama decide o ritmo, então dá para reaproveitar um som numa cadência
completamente diferente — sem acelerar por `pitch`, que subiria o tom junto. Aqui muda **só o
ritmo**.

As batidas vêm de um destes dois jeitos:

- **grade uniforme** (`first_step` + `step_every`), quando são igualmente espaçadas — o ciclo de
  caminhada do ogro;
- **`steps: [t1, t2, …]`**, quando não são — a **investida** do ogro recorta as duas batidas do
  começo do som de *aterrissagem* (0,21 s e 0,80 s), que são mais definidas que as da caminhada.

Um mesmo arquivo pode servir a vários ids assim, cada um recortando um pedaço diferente.

Quem usa `sustain` chama a função **todo frame**, e o silêncio é o padrão: um estado que não afirme
"estou andando" naquele frame fica mudo por omissão (foi assim que a baderna do ogro deixou de
prender o som dos passos).


Quem tem som é **data-driven**, não está no código:

- inimigo → `"attack_sfx"` (golpe), `"hurt_sfx"` (levou dano) e `"death_sfx"` (golpe fatal) em
  `data/enemies/*.json` (sem a chave, fica mudo — é o caso do Necromante e do ogro);
- boss → `"landing_sfx"` (impacto da entrada), `"steps_sfx"` / `"charge_steps_sfx"` (andando /
  correndo), `"rage_sfx"` (fúria), `"wall_hit_sfx"` (bateu na parede) e `"tired_sfx"` (stun) em
  `data/bosses/*.json` (cada boss ganha os seus; sem a chave, fica mudo).
