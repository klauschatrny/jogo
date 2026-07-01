## Fundo ambiental por bioma (Leva 4): céu em gradiente + duas camadas de silhuetas com
## parallax horizontal manual. Fica num CanvasLayer ATRÁS do mundo (layer negativa). O
## parallax é manual (a câmera é controlada por nós) — robusto e sem o acoplamento vertical
## do ParallaxBackground. Placeholder procedural: troca-se por arte real depois.
class_name BiomeBackground
extends CanvasLayer

const VIEW := Vector2(640.0, 360.0)
const HORIZON := 300.0          # linha do chão (GROUND_Y) em coordenadas de tela
const PATTERN := 640.0          # largura do padrão que se repete
const TILE_SCALE := 2.0         # arte de fundo desenhada em texel 2 (mesmo dos personagens)

var _layers: Array = []         # [{ node, scale }] para o scroll manual

func _init() -> void:
	layer = -10                  # bem atrás do mundo (layer 0) e da UI (layers positivas)

## (Re)constrói o fundo para um bioma. dim escurece tudo (usado na sala do boss).
func apply(biome: Dictionary, dim := 0.0) -> void:
	for c in get_children():
		c.queue_free()
	_layers.clear()

	# Céu: textura (assets/bg/<id>/sky.png) ou gradiente procedural.
	var sky := _tex_path(biome, "sky")
	if sky != "" and ResourceLoader.exists(sky):
		_add_sky_texture(sky, dim)
	else:
		_add_sky(_col(biome, "bg_top", "15161f").darkened(dim), _col(biome, "bg_bottom", "23271f").darkened(dim))

	# Duas camadas de silhueta com parallax: cada uma usa far.png/mid.png se houver, senão
	# cai nos blocos procedurais. far rola mais devagar (mais distante) que mid.
	_add_layer(biome, "far", 0.2, dim, _col(biome, "far", "2b3a30").darkened(dim), 5, 80.0, 173.0, 67.0, 120.0)
	_add_layer(biome, "mid", 0.45, dim, _col(biome, "mid", "3c4d3e").darkened(dim), 7, 53.0, 120.0, 50.0, 93.0)

## Chamado todo frame com a posição X da câmera para deslocar as camadas (parallax).
func update_scroll(camera_x: float) -> void:
	for l in _layers:
		var node: Node2D = l["node"]
		var s: float = l["scale"]
		node.position.x = -fposmod(camera_x * s, PATTERN)

func _col(b: Dictionary, key: String, def: String) -> Color:
	return Color(String(b.get(key, def)))

## Caminho da arte de um pedaço do bioma (ou "" se o bioma não tem id).
func _tex_path(b: Dictionary, name: String) -> String:
	var id := String(b.get("id", ""))
	return "" if id == "" else "res://assets/bg/%s/%s.png" % [id, name]

## Uma camada de silhueta: usa a textura (parallax em tile) se existir, senão os blocos procedurais.
func _add_layer(b: Dictionary, name: String, scale: float, dim: float, color: Color,
		count: int, hmin: float, hmax: float, wmin: float, wmax: float) -> void:
	var path := _tex_path(b, name)
	if path != "" and ResourceLoader.exists(path):
		_add_texture_layer(path, scale, dim)
	else:
		_add_silhouettes(scale, color, count, hmin, hmax, wmin, wmax)

## Céu por textura: 320×180 (texel 2) esticado para a tela 640×360, estático (sem scroll).
func _add_sky_texture(path: String, dim: float) -> void:
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = VIEW
	tr.modulate = Color(1, 1, 1).darkened(dim)
	add_child(tr)

## Camada de parallax por textura: tira transparente (320×Hpx, texel 2) repetida em duas cópias
## lado a lado (largura = PATTERN) para o scroll ser contínuo. A base encosta no horizonte.
func _add_texture_layer(path: String, scale: float, dim: float) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var node := Node2D.new()
	add_child(node)
	var h := tex.get_height() * TILE_SCALE
	for copy in 2:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_SCALE     # estica a largura para PATTERN (×2 se nativo=320)
		tr.size = Vector2(PATTERN, h)
		tr.position = Vector2(PATTERN * copy, HORIZON - h)
		tr.modulate = Color(1, 1, 1).darkened(dim)
		node.add_child(tr)
	_layers.append({ "node": node, "scale": scale })

func _add_sky(top: Color, bottom: Color) -> void:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = int(VIEW.x)
	tex.height = int(VIEW.y)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.size = VIEW
	add_child(tr)                # estático (sem scroll): é o céu

## Camada de silhuetas (blocos com base na linha do chão) com duas cópias lado a lado
## para o parallax horizontal ser contínuo ao deslocar.
func _add_silhouettes(scale: float, color: Color, count: int, hmin: float, hmax: float, wmin: float, wmax: float) -> void:
	var node := Node2D.new()
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(scale * 100000) + count   # determinístico por camada
	for copy in 2:
		var base_x := PATTERN * copy
		for i in count:
			var w := rng.randf_range(wmin, wmax)
			var h := rng.randf_range(hmin, hmax)
			var x := base_x + (PATTERN / count) * i + rng.randf_range(-17.0, 17.0)
			var rect := ColorRect.new()
			rect.color = color
			rect.size = Vector2(w, h)
			rect.position = Vector2(x, HORIZON - h)
			node.add_child(rect)
	_layers.append({ "node": node, "scale": scale })
