## HUD básico (§2.3): barra de HP do jogador. Escuta o EventBus (player_damaged) —
## a UI observa o Core, nunca o contrário (§0.2.4).
class_name Hud
extends Control

const BAR_WIDTH := 200.0

var _player: Player
var _bar: ColorRect
var _label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = Vector2(12, 12)
	bg.size = Vector2(BAR_WIDTH, 18)
	add_child(bg)

	_bar = ColorRect.new()
	_bar.color = Color(0.9, 0.2, 0.2)
	_bar.position = Vector2(12, 12)
	_bar.size = Vector2(BAR_WIDTH, 18)
	add_child(_bar)

	_label = Label.new()
	_label.position = Vector2(16, 12)
	add_child(_label)

	EventBus.player_damaged.connect(_on_player_damaged)
	_refresh()

func set_player(p: Player) -> void:
	_player = p
	_refresh()

func _on_player_damaged(p: Player, _amount: int) -> void:
	_player = p
	_refresh()

func _refresh() -> void:
	if _player == null or _player.stats == null:
		return
	var ratio := clampf(float(_player.stats.current_hp) / float(maxi(_player.stats.max_hp, 1)), 0.0, 1.0)
	_bar.size.x = BAR_WIDTH * ratio
	_label.text = "HP %d/%d" % [_player.stats.current_hp, _player.stats.max_hp]
