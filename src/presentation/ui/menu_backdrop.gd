## Arte de fundo do menu principal — PLACEHOLDER procedural (sem asset de imagem), estilo Elden Ring:
## um GRANDE EMBLEMA central atrás do título, sobre o quase-preto. O símbolo é um anel dourado
## PARTIDO (a aliança quebrada = "Fair Despair"/desespero), envolto em filigrana rúnica e mostradores
## que giram devagar, com uma CHAMA de fogueira pulsando no coração — o brilho vem dela. Desenha em
## espaço 640×360 (base do viewport, stretch "viewport"): coordenadas em pixels diretos. Trocar a
## estética = mexer aqui ou plugar uma textura de verdade quando houver arte.
extends Control

const W := 640.0
const H := 360.0
const CENTER := Vector2(320.0, 178.0)   # coração do emblema (título fica por cima da metade de cima)

const R_OUT := 128.0    # anel externo (partido embaixo)
const R_IN := 108.0     # anel interno (partido em cima)
const R_MID := 74.0     # anel decorativo do miolo
const R_HEARTH := 18.0  # arinho ao redor da chama

const GOLD := Color(0.965, 0.820, 0.260)   # = Palette.ACCENT (ouro/destaque)
const AMBER := Color(1.0, 0.58, 0.20)      # brilho quente da chama
const BG := Color(0.040, 0.040, 0.058)     # quase-preto (fundo)
const GEM_R := 13.0                        # raio da gema no coração do emblema

const TICKS := 48
const EMBER_COUNT := 7

var _t := 0.0
var _embers: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # não rouba o clique dos botões
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260717
	for i in EMBER_COUNT:
		_embers.append({
			"x": rng.randf_range(-7.0, 7.0),
			"phase": rng.randf(),
			"speed": rng.randf_range(0.30, 0.6),
			"rise": rng.randf_range(40.0, 78.0),
			"size": rng.randf_range(0.8, 1.6),
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.55 + 0.22 * sin(_t * 1.05) + 0.06 * sin(_t * 2.7)
	draw_rect(Rect2(0, 0, W, H), BG)
	_draw_glow(pulse)
	_draw_filigree(pulse)
	_draw_emblem(pulse)
	_draw_gem()
	_draw_vignette()

## Auréola quente por trás do emblema: círculos concêntricos de alfa baixo, respirando com o pulse.
func _draw_glow(pulse: float) -> void:
	for i in range(12, 0, -1):
		var r := 20.0 + i * 18.0
		var a := 0.030 * (1.0 - i / 13.0) + 0.006
		draw_circle(CENTER, r * (0.9 + 0.1 * pulse), Color(AMBER.r, AMBER.g, AMBER.b, a * pulse))

## Filigrana: grandes arcos deslocados que cruzam o interior, tecendo o "veio" orgânico do emblema.
func _draw_filigree(pulse: float) -> void:
	var col := Color(GOLD.r, GOLD.g, GOLD.b, 0.10 * pulse + 0.04)
	var offs := [Vector2(0, -300), Vector2(0, 300), Vector2(-300, 0), Vector2(300, 0)]
	for o in offs:
		draw_arc(CENTER + o, 322.0, 0.0, TAU, 96, col, 1.0, true)
	# dois arcos diagonais, mais fechados, dão o cruzamento
	draw_arc(CENTER + Vector2(-210, -210), 250.0, 0.0, TAU, 96, col, 1.0, true)
	draw_arc(CENTER + Vector2(210, 210), 250.0, 0.0, TAU, 96, col, 1.0, true)

## O emblema em si: anel externo partido embaixo, interno partido em cima, mostrador de runas girando
## devagar, raios internos e o arinho do coração. Tudo em ouro esmaecido, brilho pelo pulse.
func _draw_emblem(pulse: float) -> void:
	var ring := Color(GOLD.r, GOLD.g, GOLD.b, 0.55 * pulse + 0.20)
	var faint := Color(GOLD.r, GOLD.g, GOLD.b, 0.30 * pulse + 0.10)
	var dim := Color(GOLD.r, GOLD.g, GOLD.b, 0.16)
	var down := PI * 0.5
	var up := -PI * 0.5
	# anel externo: círculo completo MENOS uma fenda embaixo (a quebra)
	draw_arc(CENTER, R_OUT, down + 0.24, down - 0.24 + TAU, 96, ring, 2.0, true)
	# anel interno: fenda em cima (partido do lado oposto — a aliança rompida)
	draw_arc(CENTER, R_IN, up + 0.16, up - 0.16 + TAU, 96, faint, 1.0, true)
	# anel decorativo do miolo (completo)
	draw_arc(CENTER, R_MID, 0.0, TAU, 72, dim, 1.0, true)
	# mostrador de runas: tracinhos radiais em volta do anel externo, girando devagar
	var rot := _t * 0.04
	for i in TICKS:
		var a := rot + float(i) * TAU / float(TICKS)
		var dir := Vector2(cos(a), sin(a))
		var long := (i % 4 == 0)
		var r2 := R_OUT + (11.0 if long else 5.0)
		draw_line(CENTER + dir * (R_OUT + 3.0), CENTER + dir * r2,
			Color(GOLD.r, GOLD.g, GOLD.b, (0.34 if long else 0.20) * pulse + 0.06), 1.0)
	# raios internos: 8 hastes entre o anel do miolo e o interno (as pontas do sigilo)
	for i in 8:
		var a := float(i) * TAU / 8.0 - PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		draw_line(CENTER + dir * R_MID, CENTER + dir * (R_IN - 5.0), dim, 1.0)
	# marcas cardeais: pequenos losangos de runa nos 4 pontos do anel externo
	for i in 4:
		var a := float(i) * TAU / 4.0 - PI * 0.5
		_rune_diamond(CENTER + Vector2(cos(a), sin(a)) * R_OUT, 5.0, ring)
	# arinho do coração (a lareira em volta da chama)
	draw_arc(CENTER, R_HEARTH, 0.0, TAU, 40, faint, 1.0, true)

## Losango pequeno (marca de runa) centrado em `p`.
func _rune_diamond(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0),
	]), col)

## A gema no coração do emblema: um círculo facetado dourado que cintila (facetas girando devagar,
## brilho especular) e solta partículas subindo — a mesma cor do emblema.
func _draw_gem() -> void:
	var shimmer := 0.85 + 0.15 * sin(_t * 2.2)
	var gem := GOLD.lerp(AMBER, 0.35)
	# auréola quente própria (respira com o shimmer)
	for i in range(5, 0, -1):
		draw_circle(CENTER, 6.0 + i * 6.0 * shimmer,
			Color(AMBER.r, AMBER.g, AMBER.b, 0.05 * (1.0 - i / 6.0) + 0.02))
	# aro escuro + corpo da gema
	draw_circle(CENTER, GEM_R + 1.0, Color(gem.r * 0.4, gem.g * 0.4, gem.b * 0.4, 0.9))
	draw_circle(CENTER, GEM_R, gem)
	# facetas: cunhas radiais alternando claro/escuro, girando devagar (a cintilância)
	var rot := _t * 0.5
	for i in 8:
		var a0 := rot + float(i) * TAU / 8.0
		var a1 := rot + float(i + 1) * TAU / 8.0
		var shade := 1.15 if i % 2 == 0 else 0.72
		var c := Color(clampf(gem.r * shade, 0, 1), clampf(gem.g * shade, 0, 1), clampf(gem.b * shade, 0, 1), 0.55)
		draw_colored_polygon(PackedVector2Array([
			CENTER, CENTER + Vector2(cos(a0), sin(a0)) * GEM_R, CENTER + Vector2(cos(a1), sin(a1)) * GEM_R,
		]), c)
	# mesa (topo plano) mais clara + brilho especular deslizando
	draw_circle(CENTER, GEM_R * 0.5, gem.lerp(Color(1, 1, 1, 1), 0.4))
	var spec := CENTER + Vector2(-GEM_R * 0.35, -GEM_R * 0.35) + Vector2(1.5 * sin(_t * 1.3), 0)
	draw_circle(spec, 2.0 * shimmer, Color(1, 1, 1, 0.8 * shimmer))
	# partículas subindo do topo da gema (mesma cor)
	for e in _embers:
		var p: float = fmod(_t * e["speed"] + e["phase"], 1.0)
		var pos := CENTER + Vector2(e["x"] + 4.0 * sin(p * 6.28 + e["phase"] * 9.0), -GEM_R - p * e["rise"])
		draw_circle(pos, e["size"], Color(gem.r, gem.g, gem.b, (1.0 - p) * 0.85))

## Vinheta: escurece topo e base, afunilando o olhar ao emblema e ao texto no centro.
func _draw_vignette() -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 72), Vector2(0, 72)]),
		PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	draw_polygon(
		PackedVector2Array([Vector2(0, H - 96), Vector2(W, H - 96), Vector2(W, H), Vector2(0, H)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6)]))
