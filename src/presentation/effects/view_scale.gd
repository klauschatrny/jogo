## Escala do mundo de apresentação (Leva 4). O jogo foi originalmente escrito em coordenadas
## 640×360; ao subir o viewport para 1920×1080 (hi-fi), tudo ficou 3× maior. As constantes de
## apresentação já estão nos valores finais (×3, com comentário "(= base × N)"); este fator é
## usado em RUNTIME para escalar valores que vêm dos DADOS do Core (move_speed, attack_range),
## mantendo o Core/balanceamento intactos no espaço lógico original.
class_name ViewScale
extends RefCounted

const WORLD := 3.0   # 1920×1080 / (640×360)
