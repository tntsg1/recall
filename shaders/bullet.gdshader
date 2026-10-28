shader_type canvas_item;
// One bullet head per MultiMesh instance: a soft streak, brightest at the nose.
// The instance colour may exceed 1.0 so the HDR glow pass blooms it.

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(vec2(uv.x * 0.98, uv.y));
	float body = 1.0 - smoothstep(0.55, 1.0, r);
	float core = 1.0 - smoothstep(0.0, 0.45, abs(uv.y));
	float nose = mix(0.45, 1.0, smoothstep(-1.0, 0.7, uv.x));
	vec3 c = tint.rgb * (0.75 + 0.6 * core);
	COLOR = vec4(c, tint.a * body * nose);
}
