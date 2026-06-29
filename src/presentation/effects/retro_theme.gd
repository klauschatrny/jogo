## Constrói o Theme global retrô com a fonte bitmap Pixel Operator (CC0, em assets/fonts).
## Carrega a fonte forçando renderização "crisp" (sem antialiasing/hinting/subpixel/mipmaps)
## para o texto ficar pixel-perfeito no viewport 640x360 com filtro nearest. Aplicado na
## janela raiz pelo GameManager, então vale para toda a UI e persiste entre cenas (§5.4).
class_name RetroTheme
extends RefCounted

const FONT_PATH := "res://assets/fonts/PixelOperator.ttf"
const DEFAULT_SIZE := 32   # corpo de texto a 1080p (= 16 × 2, múltiplo nativo = nítido)

static func build() -> Theme:
	var theme := Theme.new()
	var font := _crisp(FONT_PATH)
	if font != null:
		theme.default_font = font
	theme.default_font_size = DEFAULT_SIZE
	return theme

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
