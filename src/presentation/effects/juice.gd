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
