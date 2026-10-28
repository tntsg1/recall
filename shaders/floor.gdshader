shader_type canvas_item;

uniform float gamma = 2.2;   // 1.0 in the browser (sRGB buffer)
// The floor: a fine dot grid that brightens around the player, dims while you
// hold Q, and ripples outward from recalls and kills.

uniform vec2 room_pos;
uniform vec2 room_size;
uniform vec2 player;
uniform float focus = 0.0;
uniform float t = 0.0;
uniform vec4 waves[4]; // xy centre, z age (s), w strength

void fragment() {
	vec2 p = room_pos + UV * room_size;
	vec2 disp = vec2(0.0);
	float glow = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) continue;
		vec2 d = p - w.xy;
		float l = length(d) + 0.001;
		float r = w.z * 1700.0;
		float band = exp(-pow((l - r) / 46.0, 2.0)) * w.w * exp(-w.z * 1.8);
		disp += d / l * band * 7.0;
		glow += band;
	}
	float sp = 40.0;
	vec2 q = p - disp;
	vec2 cell = (fract(q / sp) - 0.5) * sp;
	float dist = length(cell);
	float aa = fwidth(dist) + 0.35;
	float dot_a = 1.0 - smoothstep(1.05, 1.05 + aa, dist);
	float near = exp(-length(p - player) / 260.0);
	float a = 0.16 + 0.16 * near + 0.7 * glow;
	a *= 1.0 - 0.55 * focus;
	vec3 ink = vec3(0.925, 0.93, 0.935);
	vec3 red = vec3(1.6, 0.29, 0.24);
	vec3 col = mix(ink, red, clamp(glow * 1.4, 0.0, 1.0));
	// faint long-period breathing so the room is never perfectly still
	a *= 0.9 + 0.1 * sin(t * 0.6 + (p.x + p.y) * 0.004);
	vec3 bg = vec3(0.043, 0.043, 0.047);
	vec3 srgb = mix(bg, col, dot_a * a);
	// the canvas buffer is linear (HDR 2D); this shader works in sRGB terms
	COLOR = vec4(pow(max(srgb, vec3(0.0)), vec3(gamma)), 1.0);
}
