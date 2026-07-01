## Necromante (classe "elite"): NÃO se move em direção ao herói — mantém a posição e dispara
## projéteis no player quando ele está na mesma tela. Sempre na camada visual mais alta.
## A revivência da horda e o "mata todos ao morrer" são regidos pela cena (floor_scene).
class_name NecromancerView
extends EnemyView

const SHOOT_INTERVAL := 1.4       # cadência de disparo
const PROJECTILE_SPEED := 150.0
const SCREEN_RANGE := 340.0       # dispara quando o player está a ~meia tela (mesma tela)
const TOP_Z := 300                # acima do player (200) e de tudo

var _shoot_cd := 0.0

func _ready() -> void:
	super._ready()
	z_index = TOP_Z

## Substitui totalmente a IA do EnemyView: estático, ranged.
func _physics_process(delta: float) -> void:
	if data == null or not is_instance_valid(target):
		return
	_anim_lock = maxf(0.0, _anim_lock - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0                       # mantém a posição (não persegue, ignora knockback)
	move_and_slide()

	var dx := target.global_position.x - global_position.x
	_update_sprite(dx, false)              # encara o player, idle

	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	if absf(dx) <= SCREEN_RANGE and _shoot_cd <= 0.0:
		_shoot_cd = SHOOT_INTERVAL
		_fire()

func _fire() -> void:
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("attack"):
		_sprite.play("attack")
		_sprite.frame = 0
		_anim_lock = SHOOT_INTERVAL * 0.5
	var origin := global_position + Vector2(0.0, -box_h * 0.5)   # altura do "peito"
	var proj := NecroProjectile.new()
	proj.setup(target.global_position - origin, PROJECTILE_SPEED, data.stats, target)
	proj.global_position = origin
	get_parent().add_child(proj)
