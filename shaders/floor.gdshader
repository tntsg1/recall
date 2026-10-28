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
// A seized shell infects the floor: near it the round dots turn into flickering
// cyan pixel squares and stray pixels creep into the cells; where it has been the
// infection lingers and heals back into dots. xy centre, z radius, w strength.
uniform vec4 infect[8];

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453);
}

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
	vec3 ink = vec3(0.58, 0.6, 0.74);     // cool grey-blue dots
	vec3 red = vec3(1.15, 0.5, 0.85);     // recall rose
	vec3 col = mix(ink, red, clamp(glow * 1.4, 0.0, 1.0));
	// faint long-period breathing so the room is never perfectly still
	a *= 0.9 + 0.1 * sin(t * 0.6 + (p.x + p.y) * 0.004);
	vec3 bg = vec3(0.036, 0.036, 0.048);
	vec3 srgb = mix(bg, col, dot_a * a);
	float inf = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 f = infect[i];
		if (f.w <= 0.0) continue;
		float l = length(p - f.xy);
		inf = max(inf, f.w * (1.0 - smoothstep(f.z * 0.3, f.z, l)));
	}
	if (inf > 0.01) {
		vec2 cid = floor(q / sp);
		float flick = hash(cid + floor(t * 9.0));
		// the dot itself becomes a square of 3-px pixels, bigger the deeper the infection
		vec2 pc = floor(cell / 3.0) * 3.0 + 1.5;
		float hs = mix(1.5, 3.0, inf * (0.6 + 0.4 * flick));
		float sq = step(max(abs(pc.x), abs(pc.y)), hs);
		// and stray pixels creep into the cell around it
		vec2 sub = floor((q - cid * sp) / 4.0);
		float h = hash(cid * 13.0 + sub + floor(t * 5.0));
		float stray = step(1.0 - (inf - 0.55) * 0.05, h) * step(0.55, inf);
		vec3 cyan = vec3(0.4, 0.85, 0.95);
		float pa = clamp(sq * (0.3 + 0.4 * inf) * (0.6 + 0.4 * flick) + stray * 0.45 * inf, 0.0, 1.0);
		srgb = mix(srgb * (1.0 - 0.5 * inf * sq), cyan, pa * inf);
	}
	// the canvas buffer is linear (HDR 2D); this shader works in sRGB terms
	COLOR = vec4(pow(max(srgb, vec3(0.0)), vec3(gamma)), 1.0);
}
