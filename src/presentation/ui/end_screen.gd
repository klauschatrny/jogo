## Tela de fim de run (§2.4 Fase 4): morte ou vitória. Overlay escuro com título, algumas
## linhas de status e a instrução para voltar ao menu. Puramente visual — quem trata o input
## (Enter → menu) é a cena (floor_scene), que conhece a transição.
class_name EndScreen
extends Control

const W := 1920.0   # (= 640 × 3, viewport 1920×1080)

func setup(title: String, lines: Array, accent: Color) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	add_child(_centered(title, 330, 96, accent))

	var y := 540
	for line in lines:
		add_child(_centered(String(line), y, 40, Palette.TEXT))
		y += 64

	add_child(_centered("Enter para voltar ao menu", 960, 32, Palette.TEXT))

func _centered(text: String, y: int, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(W, font_size + 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
