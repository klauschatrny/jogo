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
Sfx.loop("player_footsteps")    # som contínuo; loop_stop() corta
Sfx.play("")                    # id vazio = silêncio (é uma configuração válida)
```

Sons curtos tocam em 8 vozes reutilizáveis, então golpes simultâneos não se cortam.

| id | variações | quando | quem dispara |
|---|---|---|---|
| `player_dodge` | 1 (há uma 2ª desenhada, ainda fora do jogo) | cada rolamento | `PlayerView._start_dodge()` |
| `player_footsteps` | 1 (ciclo de 1,3 s, em loop) | correndo no chão | `PlayerView._update_footsteps()` — corta ao parar, pular, rolar ou travar no ataque |
| `skeleton_attack` | 2 | cada golpe de esqueleto | `EnemyView._resolve_attack()` — rodízio automático |
| `ogre_landing` | 1 | o ogro caindo na arena, na cutscene de entrada | `floor_scene._boss_intro()` — tocado **adiantado** para o baque do clipe (`impact_at`) cair no instante do pouso |

O **golpe do player não tem som** por ora (a arte de áudio foi descartada).

Quem tem som é **data-driven**, não está no código:

- inimigo → `"attack_sfx": "skeleton_attack"` em `data/enemies/*.json` (sem a chave, o golpe é mudo —
  é o caso do Necromante e do ogro, que têm ataques próprios);
- boss → `"landing_sfx": "ogre_landing"` em `data/bosses/*.json` (cada boss ganha o seu; sem a
  chave, o impacto da entrada é mudo).
