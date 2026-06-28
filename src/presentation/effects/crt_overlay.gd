## Overlay CRT/scanline (§2.4 Fase 5.4). Um ColorRect em tela cheia cujo shader escurece a
## imagem em linhas horizontais (scanlines) e nas bordas (vinheta). NÃO lê o screen_texture
## (apenas escurece por alpha), então funciona no renderer Compatibility sem BackBufferCopy.
## Coloque-o numa CanvasLayer alta, acima de tudo. Opcional/alternável.
class_name CrtOverlay
extends ColorRect

const SHADER_CODE := "
shader_type canvas_item;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float scanline_count = 180.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	// Scanlines: linhas escuras periódicas no eixo vertical.
	float s = sin(uv.y * scanline_count * 3.14159265);
	float scan = scanline_strength * (0.5 + 0.5 * s);
	// Vinheta: escurece em direção às bordas.
	float dist = length(uv - vec2(0.5)) * 1.41421356;
	float vig = vignette_strength * smoothstep(0.55, 1.0, dist);
	float darken = clamp(scan + vig, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, darken);
}
"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material = mat
