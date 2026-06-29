## HUD básico (§2.3): barra de HP do jogador. Escuta o EventBus (player_damaged) —
## a UI observa o Core, nunca o contrário (§0.2.4).
class_name Hud
extends Control

const BAR_WIDTH := 600.0   # (= 200 × 3, viewport 1920×1080)

var _player: Player
var _bar: ColorRect
var _label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Palette.HP_BACK
	bg.position = Vector2(36, 36)
	bg.size = Vector2(BAR_WIDTH, 54)
	add_child(bg)

	_bar = ColorRect.new()
	_bar.color = Palette.PLAYER_HP
	_bar.position = Vector2(36, 36)
	_bar.size = Vector2(BAR_WIDTH, 54)
	add_child(_bar)

	_label = Label.new()
	_label.position = Vector2(48, 42)
	_label.add_theme_font_size_override("font_size", 34)   # HP/Nível na barra (= 48 − 30%)
	add_child(_label)

	_refresh()

func set_player(p: Player) -> void:
	_player = p
	_refresh()

## Atualiza todo frame: reflete dano, cura (lifesteal) e level-up sem depender de eventos.
func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _player == null or _player.stats == null:
		return
	var ratio := clampf(float(_player.stats.current_hp) / float(maxi(_player.stats.max_hp, 1)), 0.0, 1.0)
	_bar.size.x = BAR_WIDTH * ratio
	_label.text = "HP %d/%d    Nv %d" % [_player.stats.current_hp, _player.stats.max_hp, _player.level]
