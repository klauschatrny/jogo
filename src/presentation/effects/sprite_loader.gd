## Monta um AnimatedSprite2D a partir de um spritesheet em grade + manifesto JSON (Leva 4).
##
## Convenção "1 linha por animação":
##   - A arte fica em  res://assets/sprites/<subdir>/<id>.png  como uma grade de células de
##     tamanho cell_w × cell_h (retangular; use "cell" sozinho para quadrada). Cada animação
##     ocupa UMA linha (row), com N frames nas colunas (da esquerda para a direita).
##   - O sprite é ancorado pelos PÉS (bottom-center do quadro), então desenhe o personagem com
##     a sola dos pés na borda INFERIOR do canvas, centralizado na horizontal, virado p/ direita.
##   - O manifesto  res://data/sprites/<id>.json  descreve a grade e as animações:
##       {
##         "cell_w": 32, "cell_h": 48,
##         "animations": {
##           "idle":   { "row": 0, "frames": 4, "fps": 6 },
##           "run":    { "row": 1, "frames": 6, "fps": 10 },
##           "attack": { "row": 2, "frames": 4, "fps": 12, "loop": false }
##         }
##       }
##
## Sem PNG ou sem manifesto válido, retorna null e a view mantém o placeholder ColorRect
## (degradação graciosa — o jogo nunca quebra por falta de arte).
class_name SpriteLoader
extends RefCounted

static func build(id: String, subdir: String) -> AnimatedSprite2D:
	if id == "":
		return null
	var png := "res://assets/sprites/%s/%s.png" % [subdir, id]
	if not ResourceLoader.exists(png):
		return null
	var manifest: Variant = JsonLoader.load_file("res://data/sprites/%s.json" % id)
	if typeof(manifest) != TYPE_DICTIONARY or (manifest as Dictionary).is_empty():
		return null
	var m := manifest as Dictionary
	var anims: Dictionary = m.get("animations", {})
	if anims.is_empty():
		return null
	var tex := load(png) as Texture2D
	if tex == null:
		return null

	var cell := int(m.get("cell", 32))
	var cell_w := int(m.get("cell_w", cell))   # célula retangular: largura/altura separadas
	var cell_h := int(m.get("cell_h", cell))   # (cell_w = cell_h = cell se só "cell" for dado)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")          # remove a animação vazia padrão
	for anim_name in anims.keys():
		var a: Dictionary = anims[anim_name]
		var row := int(a.get("row", 0))
		var frames := maxi(1, int(a.get("frames", 1)))
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(a.get("fps", 8.0)))
		sf.set_animation_loop(anim_name, bool(a.get("loop", true)))
		for i in frames:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * cell_w, row * cell_h, cell_w, cell_h)
			sf.add_frame(anim_name, at)

	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel-art sem suavização
	# Multiplicador de tamanho (padrão 1). Use inteiro (2, 3) para manter os pixels nítidos.
	# Escala SÓ o ator no mundo (cenário fica igual); a hitbox é escalada junto pelas views.
	var sc := maxf(0.01, float(m.get("scale", 1.0)))
	spr.scale = Vector2(sc, sc)
	# Direção em que a arte foi desenhada ("right" padrão | "left"). As views usam isto para
	# decidir o flip_h: arte virada p/ esquerda inverte o espelhamento. Guardado como meta.
	spr.set_meta("faces_left", String(m.get("facing", "right")) == "left")
	# Âncora nos PÉS: coloca o bottom-center do quadro no (0,0) local do sprite. A view então
	# desloca esse ponto para a base da hitbox (o chão). Assim o artista desenha os pés colados
	# na borda inferior do canvas — sem vão e sem cálculo de offset, com canvas de qualquer altura.
	spr.centered = false
	spr.offset = Vector2(-cell_w / 2.0, -cell_h)
	spr.animation = "idle" if sf.has_animation("idle") else String(anims.keys()[0])
	spr.play()
	return spr

## Lê a hitbox opcional do manifesto (data/sprites/<id>.json → "hitbox": [largura, altura]).
## Retorna Vector2(w, h) em px (base 640×360), ou Vector2.ZERO se ausente/inválida (a view
## então cai no seu padrão por rank). Mantém os dados de arte (canvas + hitbox) num arquivo só.
static func hitbox_for(id: String) -> Vector2:
	if id == "":
		return Vector2.ZERO
	var manifest: Variant = JsonLoader.load_file("res://data/sprites/%s.json" % id)
	if typeof(manifest) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var hb: Array = (manifest as Dictionary).get("hitbox", [])
	if hb.size() < 2:
		return Vector2.ZERO
	return Vector2(float(hb[0]), float(hb[1]))

## Multiplicador de tamanho do manifesto (data/sprites/<id>.json → "scale", padrão 1.0).
## As views usam isto para escalar a hitbox junto com a arte (mesmo fator → proporção mantida).
static func scale_for(id: String) -> float:
	if id == "":
		return 1.0
	var manifest: Variant = JsonLoader.load_file("res://data/sprites/%s.json" % id)
	if typeof(manifest) != TYPE_DICTIONARY:
		return 1.0
	return maxf(0.01, float((manifest as Dictionary).get("scale", 1.0)))

## Toca uma animação só se ela existir (senão tenta o fallback); evita reiniciar a mesma.
static func play_safe(spr: AnimatedSprite2D, anim: String, fallback := "idle") -> void:
	if spr == null or spr.sprite_frames == null:
		return
	var target := anim if spr.sprite_frames.has_animation(anim) else fallback
	if not spr.sprite_frames.has_animation(target):
		return
	if spr.animation != target or not spr.is_playing():
		spr.play(target)
