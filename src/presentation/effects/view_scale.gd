## Escala do mundo de apresentação. O jogo roda em coordenadas lógicas 640×360 (retrô/8-bit,
## upscale integer para a janela). As constantes de apresentação estão no espaço base 640×360
## e os dados do Core (move_speed, attack_range) são usados diretamente — por isso WORLD = 1.0
## (no-op). A constante é mantida como ponto único caso a escala mude no futuro.
class_name ViewScale
extends RefCounted

const WORLD := 1.0   # logical space = base 640×360 (sem reescala)
