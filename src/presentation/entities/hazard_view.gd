## Armadilha de cenário: um POÇO de espinhos aberto no chão. Fere por CONTATO — sem IA, sem
## combate, sem inimigo por trás. É a peça mais barata de conteúdo não-combativo: o que ela é
## (dano, largura, fundura, aparência) vem de data/hazards.json e ONDE ela fica, de levels.json.
##
## O buraco em si é TERRENO: quem recorta o chão e fecha o fundo é o floor_scene (_build_environment),
## que precisa dos poços antes de montar o cenário. Este nó desenha o interior + os espinhos e
## cuida do dano.
##
## Cair num poço MATA na hora (`instakill`). Não é um mordisco de vida que a esquiva evita: é um
## buraco. A morte instantânea ignora os i-frames do rolamento de propósito — o poço não se
## atravessa rolando, se atravessa PULANDO. Ela respeita o god mode (debug).
##
## Um hazard sem `instakill` cai no caminho de dano comum (apply_flat_damage, a cada `tick`) —
## a porta fica aberta para armadilhas não-letais.
class_name HazardView
extends Area2D

const PLAYER_LAYER := 1          # o player é a camada 1 (ver PlayerView._ready)
const SPIKE_H := 11.0            # altura dos espinhos no fundo do poço
const DANGER_TOP := 10.0         # a zona letal começa este tanto ABAIXO da borda: raspar no
                                 # lábio do buraco andando não mata — é preciso cair dentro.

var _instakill := true
var _damage := 0
var _tick := 0.8                 # (só para hazards não-letais) segundos entre um dano e o próximo
var _pop := 0.0
var _sfx := ""
var _cd := 0.0
var _half_w := 0.0               # meia-largura e fundura, guardadas para reconferir a posição
var _depth := 0.0                # do player por conta própria (ver _dentro_do_poco)

## `width` > 0 estica o poço (o nível alarga uma vala sem precisar de uma definição nova).
## A origem do nó fica na LINHA DO CHÃO; o poço desce a partir dela.
func setup(def: Dictionary, width := 0.0) -> void:
	_instakill = bool(def.get("instakill", false))
	_damage = int(def.get("damage", 0))
	_tick = float(def.get("tick", _tick))
	_pop = float(def.get("pop", 0.0))
	_sfx = String(def.get("sfx", ""))

	var w := width if width > 0.0 else float(def.get("width", 56.0))
	var d := float(def.get("depth", 40.0))
	_half_w = w * 0.5
	_depth = d

	monitoring = true
	collision_layer = 0                  # não é obstáculo: ninguém colide COM ela
	collision_mask = PLAYER_LAYER        # ela é que enxerga o player

	# Zona letal: o VÃO do buraco, da borda para baixo. Andar na beirada não mata; cair, sim.
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var zone_h := maxf(6.0, d - DANGER_TOP)
	rect.size = Vector2(w, zone_h)
	col.shape = rect
	col.position = Vector2(0.0, DANGER_TOP + zone_h * 0.5)
	add_child(col)

	_build_visual(def, w, d)

func _build_visual(def: Dictionary, w: float, d: float) -> void:
	var spike_col := Color(String(def.get("color", "9fb4c7")))
	var pit_col := Color(String(def.get("pit", "140d18")))

	# Interior do poço: escuro, cobrindo a terra do backing.
	var hole := ColorRect.new()
	hole.color = pit_col
	hole.position = Vector2(-w * 0.5, 0.0)
	hole.size = Vector2(w, d)
	hole.z_index = -6
	add_child(hole)

	# Sombra da borda: uma faixa mais escura logo abaixo do lábio, que dá profundidade ao buraco.
	var lip := ColorRect.new()
	lip.color = pit_col.darkened(0.5)
	lip.position = Vector2(-w * 0.5, 0.0)
	lip.size = Vector2(w, 4.0)
	lip.z_index = -5
	add_child(lip)

	# Arte no lugar dos espinhos placeholder, se houver (PNG lado a lado, colado no fundo).
	var tex_path := String(def.get("tex", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		var art := TextureRect.new()
		art.texture = tex
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.stretch_mode = TextureRect.STRETCH_TILE
		art.position = Vector2(-w * 0.5, d - tex.get_height())
		art.size = Vector2(w, tex.get_height())
		art.z_index = -4
		add_child(art)
		return

	# Placeholder: fileira de lâminas no fundo, alternando alto/baixo (silhueta menos monótona
	# que dentes iguais). Cada uma é um triângulo; a base fica na laje do fundo.
	var spike_w := maxf(4.0, float(def.get("spike_w", 7)))
	var count := maxi(1, int(w / spike_w))
	var step := w / float(count)
	var x0 := -w * 0.5
	for i in count:
		var h := SPIKE_H if i % 2 == 0 else SPIKE_H * 0.62
		var a := x0 + step * float(i)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(a, d),
			Vector2(a + step * 0.5, d - h),
			Vector2(a + step, d),
		])
		poly.color = spike_col
		poly.z_index = -4
		add_child(poly)

## O player está MESMO dentro deste buraco, agora?
##
## Não dá para confiar só na lista do Area2D: ela é montada no passo de FÍSICA, e um TELEPORTE
## (renascer) acontece no meio de um frame de idle — a lista continua dizendo o que era verdade
## antes. Foi assim que o poço matava o recém-ressuscitado do outro lado do mapa: a armadilha
## nascia sobreposta ao cadáver e, quando o corpo era levado embora, ela ainda o "via" ali.
## Reconferir a posição custa nada e fecha essa classe inteira de bug.
func _dentro_do_poco(p: PlayerView) -> bool:
	var local := to_local(p.global_position)
	return absf(local.x) <= _half_w + p.box_w * 0.5 and local.y > 0.0 and local.y < _depth + 40.0

func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	if _cd > 0.0:
		return
	for b in get_overlapping_bodies():
		if not (b is PlayerView):
			continue
		var p := b as PlayerView
		if not _dentro_do_poco(p):
			continue
		if _instakill:
			if p.kill():
				Sfx.play(_sfx)                # id vazio = silêncio (configuração válida)
			return
		# Hazard não-letal: dano comum. apply_flat_damage devolve false se foi ignorado
		# (esquiva/god mode) — e aí NÃO gastamos o cooldown.
		if _damage > 0 and p.apply_flat_damage(_damage):
			_cd = _tick
			Sfx.play(_sfx)
			if _pop > 0.0:
				p.velocity.y = -_pop
		return
