## Espantalho de treino: um boneco de palha na Cidade, para o jogador experimentar o ataque num
## alvo que reage. Não é um inimigo — não persegue, não ataca, não morre. Leva o golpe, pisca e
## BALANÇA no poste, e volta ao lugar. Substituiu o esqueleto dormente que servia de boneco antes:
## um esqueleto parado na vila dava a impressão errada de que a Cidade tinha combate.
##
## Herda de EnemyView só para caber na checagem `is EnemyView` do golpe do jogador
## (_enemies_in_reach). Toda a lógica de inimigo é substituída: `_build` desenha a palha em vez do
## corpo cinza + arte, e `_physics_process` faz só a gravidade e o balanço — sem IA nenhuma.
class_name ScarecrowView
extends EnemyView

const CAIXA := Vector2(24.0, 46.0)
const BALANCO_MAX := 0.5           # empurrão no balanço a cada golpe (rad/s)
const BALANCO_DECAI := 6.0         # rapidez com que a mola volta ao prumo

var _corpo: Node2D                 # a parte que balança (tudo menos o poste)
var _balanco := 0.0
var _balanco_vel := 0.0

## Montagem mínima: só guarda o essencial. O EnemyView._ready chama _build() (sobrescrito abaixo)
## quando o nó entra na árvore — é lá que a colisão e o desenho nascem.
func setup(enemy: Enemy, target_node: Node2D) -> void:
	data = enemy
	target = target_node
	hp_bar_visible = false
	box_w = CAIXA.x
	box_h = CAIXA.y

## Substitui o _build do EnemyView por inteiro: sem corpo cinza, sem tentar carregar arte de
## inimigo, sem barra de vida. Só a forma de colisão (para o golpe o encontrar) e o boneco de palha.
func _build() -> void:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = CAIXA
	col.shape = rect
	add_child(col)
	_desenha()

func _desenha() -> void:
	# Poste fincado (não balança).
	var poste := ColorRect.new()
	poste.color = Color(0.40, 0.28, 0.16)
	poste.size = Vector2(4.0, 44.0)
	poste.position = Vector2(-2.0, -44.0)
	add_child(poste)

	# O corpo que balança, com pivô na travessa (o "ombro" do espantalho).
	_corpo = Node2D.new()
	_corpo.position = Vector2(0.0, -30.0)
	add_child(_corpo)

	var palha := Color(0.82, 0.66, 0.24)
	var palha_esc := Color(0.62, 0.48, 0.16)
	var pano := Color(0.72, 0.30, 0.24)

	# Travessa (os braços).
	var braco := ColorRect.new()
	braco.color = palha_esc
	braco.size = Vector2(30.0, 4.0)
	braco.position = Vector2(-15.0, -2.0)
	_corpo.add_child(braco)
	for lado in [-1.0, 1.0]:
		var mao := ColorRect.new()
		mao.color = palha
		mao.size = Vector2(4.0, 8.0)
		mao.position = Vector2(lado * 15.0 - (0.0 if lado < 0.0 else 4.0), -1.0)
		_corpo.add_child(mao)

	# Tronco de palha atado.
	var tronco := ColorRect.new()
	tronco.color = palha
	tronco.size = Vector2(16.0, 22.0)
	tronco.position = Vector2(-8.0, 0.0)
	_corpo.add_child(tronco)
	for i in 2:
		var atadura := ColorRect.new()
		atadura.color = pano
		atadura.size = Vector2(18.0, 2.0)
		atadura.position = Vector2(-9.0, 4.0 + i * 12.0)
		_corpo.add_child(atadura)

	# Cabeça de saco com uma cara riscada.
	var cabeca := ColorRect.new()
	cabeca.color = Color(0.86, 0.74, 0.46)
	cabeca.size = Vector2(14.0, 13.0)
	cabeca.position = Vector2(-7.0, -14.0)
	_corpo.add_child(cabeca)
	for ox in [-4.0, 2.0]:
		var olho := ColorRect.new()
		olho.color = Color(0.20, 0.15, 0.10)
		olho.size = Vector2(2.0, 2.0)
		olho.position = Vector2(ox, -10.0)
		_corpo.add_child(olho)

func _physics_process(delta: float) -> void:
	# Só a gravidade e o balanço voltando ao prumo. Este _physics_process substitui o do EnemyView
	# de propósito, e aqui NÃO há windup, perseguição nem ataque para replicar.
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0
	move_and_slide()
	# Oscilação amortecida (mola): o balanço volta a zero passando por ele algumas vezes.
	_balanco_vel += -_balanco * BALANCO_DECAI * BALANCO_DECAI * delta
	_balanco_vel *= (1.0 - minf(1.0, BALANCO_DECAI * delta))
	_balanco += _balanco_vel * delta
	if is_instance_valid(_corpo):
		_corpo.rotation = _balanco

## Golpe: pisca, solta palha e TOMBA para o lado do golpe — mas não perde vida e nunca morre.
func apply_damage(amount: int, knockback_mult := 1.0) -> void:
	if is_instance_valid(_corpo):
		Juice.flash_modulate(_corpo)
	Juice.burst(get_parent(), global_position + Vector2(0, -22), Color(0.86, 0.74, 0.46), 8, 90.0)
	if data != null and data.hurt_sfx != "":
		Sfx.play(data.hurt_sfx)
	var dir := 1.0
	if is_instance_valid(target):
		dir = signf(global_position.x - target.global_position.x)
	_balanco_vel += (dir if dir != 0.0 else 1.0) * BALANCO_MAX * (2.0 + knockback_mult)
