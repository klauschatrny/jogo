## Helpers de "game feel" (§2.4 Fase 5.2). Efeitos puramente visuais, sem lógica de jogo.
## Funções estáticas reutilizáveis pelas views. Tudo aqui é seguro de chamar fire-and-forget.
class_name Juice
extends RefCounted

static var _in_hitstop := false

## Hit-stop: congela quase tudo por um instante para dar peso ao impacto. Usa um timer em
## tempo REAL (ignore_time_scale) para restaurar mesmo com o tempo escalado. Reentrância
## ignorada para golpes rápidos não acumularem.
static func hit_stop(tree: SceneTree, duration := 0.05, scale := 0.04) -> void:
	if _in_hitstop or tree == null:
		return
	_in_hitstop = true
	Engine.time_scale = scale
	var t := tree.create_timer(duration, true, false, true)  # ignore_time_scale = true
	await t.timeout
	Engine.time_scale = 1.0
	_in_hitstop = false

## Flash de impacto: pisca a cor de um ColorRect para branco e volta ao normal. Independe do
## modulate do nó (que o boss usa para o enrage), então não há conflito.
static func flash(rect: ColorRect, base: Color, dur := 0.08) -> void:
	if rect == null:
		return
	rect.color = Color(1, 1, 1, base.a)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color", base, dur)

## Flash de impacto para nós com textura (AnimatedSprite2D): estoura o modulate para branco
## e volta. Usa o modulate do PRÓPRIO sprite (multiplica com o do nó-pai), então não conflita
## com o enrage do boss, que mexe no modulate do nó. Use este para sprites; flash() é p/ ColorRect.
static func flash_modulate(item: CanvasItem, dur := 0.08) -> void:
	if item == null:
		return
	item.modulate = Color(3, 3, 3)
	var tw := item.create_tween()
	tw.tween_property(item, "modulate", Color.WHITE, dur)

## Filtro branco por shader: mistura a arte em direção ao branco por `amount` (0..1) de opacidade,
## em duas piscadas rápidas que somem. Diferente do flash_modulate (que estoura o brilho via
## modulate), isto lava a silhueta de branco de fato — usado no dano por colisão do player. Cria
## um ShaderMaterial no próprio item na 1ª chamada (reaproveitado depois; flash=0 = sem efeito).
const FLASH_SHADER := "shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
"

static func flash_white(item: CanvasItem, amount := 0.6, dur := 0.09) -> void:
	if item == null:
		return
	var mat := item.material as ShaderMaterial
	if mat == null:
		var sh := Shader.new()
		sh.code = FLASH_SHADER
		mat = ShaderMaterial.new()
		mat.shader = sh
		item.material = mat
	var setp := func(v: float) -> void: mat.set_shader_parameter("flash", v)
	var tw := item.create_tween()
	tw.tween_method(setp, amount, 0.0, dur)   # 1ª piscada
	tw.tween_interval(0.03)
	tw.tween_method(setp, amount, 0.0, dur)   # 2ª piscada

## Arco de corte (swipe) curto para telegrafar/impactar um golpe melee, na direção `angle`,
## com `radius` = alcance visual (use o attack range da entidade). Filho de `parent`, em `pos`
## local. Varre um pouco, some e afina; auto-libera ao fim.
static func slash_arc(parent: Node, pos: Vector2, angle: float, radius: float, color: Color,
		thickness := 3.0, span_deg := 110.0, dur := 0.16) -> void:
	if parent == null:
		return
	var slash := Line2D.new()
	slash.width = thickness
	slash.default_color = color
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	slash.joint_mode = Line2D.LINE_JOINT_ROUND
	slash.z_index = 20
	var span := deg_to_rad(span_deg)
	var steps := 10
	for i in steps + 1:
		var a := angle - span * 0.5 + span * (float(i) / steps)
		slash.add_point(Vector2(cos(a), sin(a)) * radius)
	slash.position = pos
	slash.rotation = -span * 0.25
	parent.add_child(slash)
	var tw := slash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash, "rotation", span * 0.25, dur)
	tw.tween_property(slash, "modulate:a", 0.0, dur * 1.1)
	tw.tween_property(slash, "width", thickness * 0.3, dur * 1.1)
	tw.chain().tween_callback(slash.queue_free)

## Estocada (thrust): uma linha reta que avança rápido na direção `angle` até `length` e some.
## `length` = alcance visual (use o attack range). Filho de `parent`, em `pos` local.
static func thrust(parent: Node, pos: Vector2, angle: float, length: float, color: Color,
		thickness := 4.0, dur := 0.16) -> void:
	if parent == null:
		return
	var dir := Vector2(cos(angle), sin(angle))
	var line := Line2D.new()
	line.width = thickness
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 20
	line.add_point(Vector2.ZERO)
	line.add_point(dir * (length * 0.3))
	line.position = pos
	parent.add_child(line)
	var tw := line.create_tween()
	# Avança a ponta até o alcance total (o "empurrão"), depois some.
	tw.tween_method(func(t: float) -> void: line.set_point_position(1, dir * (length * t)), 0.3, 1.0, dur * 0.45)
	tw.tween_property(line, "modulate:a", 0.0, dur * 0.55)
	tw.tween_callback(line.queue_free)

## Rastro/eco visual: uma cópia estática translúcida que some no lugar. Usado no dash da
## esquiva para dar sensação de velocidade. Auto-libera ao fim do fade.
static func afterimage(parent: Node, pos: Vector2, size: Vector2, color: Color, dur := 0.22) -> void:
	if parent == null:
		return
	var g := ColorRect.new()
	g.color = Color(color.r, color.g, color.b, 0.45)
	g.size = size
	g.position = pos - size * 0.5
	g.z_index = 5
	parent.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, dur)
	tw.tween_callback(g.queue_free)

## Explosão curta de partículas no ponto do impacto/morte. Auto-libera após a vida útil.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 8, speed := 90.0) -> void:
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.4
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.z_index = 50
	p.finished.connect(p.queue_free)   # auto-libera quando o one_shot termina
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
