## Fundo ambiental (parallax) por bioma. Fica num CanvasLayer ATRÁS do mundo (layer negativa),
## em espaço de TELA — a câmera trava o Y, então o scroll horizontal manual basta e evita o
## acoplamento vertical do ParallaxBackground.
##
## As camadas são DATA-DRIVEN (data/biomes.json): uma lista ordenada de FUNDO → FRENTE, cada uma
## com `tex` (png), `speed` (fração do movimento da câmera: 0 = fixa, 1 = colada no mundo) e
## `drift` (px/s de deslocamento próprio, p/ nuvens ao vento). Cada camada é um tile emendável
## repetido na horizontal; o comprimento do nível é irrelevante.
##
## Sem lista de camadas (ou sem os PNGs), cai no placeholder procedural: gradiente + silhuetas
## de ColorRect. Nada quebra.
class_name BiomeBackground
extends CanvasLayer

const VIEW := Vector2(640.0, 360.0)
const HORIZON := 300.0          # linha do chão (GROUND_Y) em coordenadas de tela
const PROC_PATTERN := 640.0     # largura do padrão que se repete (placeholder procedural)

# [{ node, scale, pattern, drift, offset }] — estado do scroll manual, por camada.
var _layers: Array = []

func _init() -> void:
	layer = -10                  # bem atrás do mundo (layer 0) e da UI (layers positivas)

## (Re)constrói o fundo. `specs` é a lista de camadas (fundo → frente); se vazia, o bioma cai no
## placeholder procedural. `dim` escurece tudo (usado na sala do boss).
func apply(biome: Dictionary, dim := 0.0, specs: Array = []) -> void:
	for c in get_children():
		c.queue_free()
	_layers.clear()

	if not specs.is_empty():
		var built := 0
		for spec in specs:
			if typeof(spec) == TYPE_DICTIONARY and _add_parallax_layer(spec, dim):
				built += 1
		if built > 0:
			return                # arte carregada: pronto

	_add_procedural(biome, dim)   # sem arte (ou PNGs ausentes): placeholder

## Chamado todo frame com a posição X da câmera: desloca as camadas (parallax).
func update_scroll(camera_x: float) -> void:
	for l in _layers:
		l["camera_x"] = camera_x
	_reposition()

## Deriva própria das camadas com `drift` (nuvens ao vento): avança mesmo com o player parado.
func _process(delta: float) -> void:
	var moved := false
	for l in _layers:
		var drift: float = l["drift"]
		if drift != 0.0:
			l["offset"] = fposmod(l["offset"] + drift * delta, l["pattern"])
			moved = true
	if moved:
		_reposition()

func _reposition() -> void:
	for l in _layers:
		var node: Node2D = l["node"]
		var total: float = l["camera_x"] * float(l["scale"]) + float(l["offset"])
		node.position.x = -fposmod(total, l["pattern"])

## Uma camada de arte: o tile é repetido em cópias lado a lado (o bastante p/ cobrir a tela em
## qualquer deslocamento) e desenhado 1:1, no topo da tela. Devolve false se o PNG não existir.
func _add_parallax_layer(spec: Dictionary, dim: float) -> bool:
	var path := String(spec.get("tex", ""))
	if path == "" or not ResourceLoader.exists(path):
		return false
	var tex := load(path) as Texture2D
	if tex == null:
		return false

	var pattern := float(tex.get_width())
	if pattern <= 0.0:
		return false
	var node := Node2D.new()
	add_child(node)
	# O nó desliza em [-pattern, 0]; cópias suficientes p/ cobrir a viewport em qualquer offset.
	var copies := int(ceil(VIEW.x / pattern)) + 1
	for i in copies:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_KEEP        # 1:1, sem esticar (texel da arte)
		tr.size = tex.get_size()
		tr.position = Vector2(pattern * i, 0.0)
		tr.modulate = Color(1, 1, 1).darkened(dim)
		node.add_child(tr)

	_layers.append({
		"node": node,
		"scale": float(spec.get("speed", 0.0)),
		"drift": float(spec.get("drift", 0.0)),
		"pattern": pattern,
		"offset": 0.0,
		"camera_x": 0.0,
	})
	return true

## Placeholder procedural (sem arte): céu em gradiente + duas camadas de silhuetas de blocos.
func _add_procedural(biome: Dictionary, dim: float) -> void:
	_add_sky(_col(biome, "bg_top", "15161f").darkened(dim), _col(biome, "bg_bottom", "23271f").darkened(dim))
	_add_silhouettes(0.2, _col(biome, "far", "2b3a30").darkened(dim), 5, 80.0, 173.0, 67.0, 120.0)
	_add_silhouettes(0.45, _col(biome, "mid", "3c4d3e").darkened(dim), 7, 53.0, 120.0, 50.0, 93.0)

func _col(b: Dictionary, key: String, def: String) -> Color:
	return Color(String(b.get(key, def)))

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
		var base_x := PROC_PATTERN * copy
		for i in count:
			var w := rng.randf_range(wmin, wmax)
			var h := rng.randf_range(hmin, hmax)
			var x := base_x + (PROC_PATTERN / count) * i + rng.randf_range(-17.0, 17.0)
			var rect := ColorRect.new()
			rect.color = color
			rect.size = Vector2(w, h)
			rect.position = Vector2(x, HORIZON - h)
			node.add_child(rect)
	_layers.append({
		"node": node,
		"scale": scale,
		"drift": 0.0,
		"pattern": PROC_PATTERN,
		"offset": 0.0,
		"camera_x": 0.0,
	})
