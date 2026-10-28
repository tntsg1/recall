shader_type canvas_item;
// Pause backdrop: the frame behind, blurred through its mip chain and dimmed.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float lod = amount * 3.2;
	vec2 px = SCREEN_PIXEL_SIZE * (1.5 + amount * 5.0);
	vec3 c = textureLod(screen_tex, uv, lod).rgb * 0.36;
	c += textureLod(screen_tex, uv + vec2(px.x, 0.0), lod).rgb * 0.16;
	c += textureLod(screen_tex, uv - vec2(px.x, 0.0), lod).rgb * 0.16;
	c += textureLod(screen_tex, uv + vec2(0.0, px.y), lod).rgb * 0.16;
	c += textureLod(screen_tex, uv - vec2(0.0, px.y), lod).rgb * 0.16;
	COLOR = vec4(c * (1.0 - 0.4 * amount), 1.0);
}
