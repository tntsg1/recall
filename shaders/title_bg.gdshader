shader_type canvas_item;

uniform float gamma = 2.2;   // 1.0 in the browser (sRGB buffer)
// Title backdrop: the dot grid on the GPU, brightening around the cursor.
// Colours are written in sRGB terms and converted for the linear HDR buffer.

uniform vec2 cursor = vec2(960.0, 540.0);
uniform vec2 size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 p = UV * size;
	float sp = 48.0;
	vec2 cell = (fract((p - 24.0) / sp + 0.5) - 0.5) * sp;
	float near = exp(-length(p - cursor) / 220.0);
	float r = 1.0 + near * 0.8;
	float d = length(cell);
	float dot_a = 1.0 - smoothstep(r - 0.6, r + 0.6, d);
	float a = (0.07 + 0.12 * near) * dot_a;
	vec3 bg = vec3(0.043, 0.043, 0.047);
	vec3 col = mix(bg, vec3(0.925, 0.93, 0.935), a);
	COLOR = vec4(pow(col, vec3(gamma)), 1.0);
}
