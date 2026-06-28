## Paleta limitada (§2.4 Fase 5.4). Um único lugar para as cores do jogo, dando coesão
## retrô. As views referenciam estas constantes em vez de cores soltas. Inspirada numa
## paleta de 16 cores (estilo Sweetie-16). Trocar a estética = editar aqui.
class_name Palette
extends RefCounted

const BG := Color("1a1c2c")          # fundo (azul-noite escuro)
const BG_EDGE := Color("141520")     # bordas/vinheta

const PLAYER := Color("41a6f6")      # jogador (azul)
const ENEMY := Color("d9575b")       # inimigo comum (vermelho)
const BOSS := Color("a868d6")        # boss (roxo)
const GHOST := Color("73eff7")       # eco/fantasma (ciano)

const HP_FILL := Color("6abe30")     # barra de HP (verde)
const HP_BACK := Color(0, 0, 0, 0.6) # fundo da barra
const PLAYER_HP := Color("d9575b")   # barra de HP do jogador (vermelho)

const ACCENT := Color("f6d143")      # destaque/ouro (vitória, artefato)
const TEXT := Color("f4f4f4")        # texto claro

const SLASH := Color("fff7c2")       # arco de corte (branco-amarelado)
const HIT_SPARK := Color("ffcd75")   # partículas de impacto
