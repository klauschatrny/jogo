## Constrói o Theme global retrô com a fonte bitmap Pixel Operator (CC0, em assets/fonts).
## Carrega a fonte forçando renderização "crisp" (sem antialiasing/hinting/subpixel/mipmaps)
## para o texto ficar pixel-perfeito no viewport 640x360 com filtro nearest. Aplicado na
## janela raiz pelo GameManager, então vale para toda a UI e persiste entre cenas (§5.4).
class_name RetroTheme
extends RefCounted

const FONT_PATH := "res://assets/fonts/PixelOperator.ttf"
const DEFAULT_SIZE := 16   # corpo de texto no base 640×360 (tamanho nativo da fonte = nítido)

static func build() -> Theme:
	var theme := Theme.new()
	var font := _crisp(FONT_PATH)
	if font != null:
		theme.default_font = font
	theme.default_font_size = DEFAULT_SIZE
	return theme

## Aplica o tema na janela raiz E no TEMA PADRÃO global (ThemeDB). O padrão é o que alcança os
## Controls pendurados sob CanvasLayer (HUD, pausa, painéis em jogo) e os Labels do mundo
## (prompts da fogueira etc.): a propagação de tema PARA em ancestrais não-Control, então o theme
## da janela nunca chega neles — eles resolvem pelo default do ThemeDB, que vem com a fonte
## embutida do Godot. Sem trocar a fonte LÁ, o jogo fica com duas letras diferentes.
## (Só o fallback_font não basta: o tema padrão tem fonte própria e vence a resolução.)
static func apply(window: Window) -> void:
	var theme := build()
	if window != null:
		window.theme = theme
	var padrao := ThemeDB.get_default_theme()
	if padrao != null and theme.default_font != null:
		padrao.default_font = theme.default_font
		padrao.default_font_size = DEFAULT_SIZE
	if theme.default_font != null:
		ThemeDB.fallback_font = theme.default_font
	ThemeDB.fallback_font_size = DEFAULT_SIZE

## Carrega um .ttf como FontFile e desliga tudo que borra pixels.
static func _crisp(path: String) -> FontFile:
	var res: Variant = load(path)
	if not (res is FontFile):
		push_warning("[RetroTheme] fonte não encontrada/inválida: %s" % path)
		return null
	var f := res as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	f.multichannel_signed_distance_field = false
	f.generate_mipmaps = false
	return f
