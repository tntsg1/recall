shader_type canvas_item;
// The run's screen pass: chromatic split that pulses on big moments, a zoom punch
// toward the recall, shock rings that bend the picture where things die, a red
// vignette when you are hit, and a whisper of grain. Everything rests near zero.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float ca = 0.0;            // chromatic split, in uv
uniform vec2 focus_uv = vec2(0.5);  // zoom punch centre
uniform float zoom = 0.0;
uniform vec4 shocks[6];            // xy uv centre, z ring radius (in screen heights), w strength
uniform float aspect = 1.7778;
uniform float vig = 0.0;
uniform float grain = 0.0;
uniform float t = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	uv = focus_uv + (uv - focus_uv) * (1.0 - zoom);
	for (int i = 0; i < 6; i++) {
		vec4 s = shocks[i];
		if (s.w <= 0.0) continue;
		vec2 d = uv - s.xy;
		d.x *= aspect;
		float l = length(d);
		float band = exp(-pow((l - s.z) / 0.045, 2.0)) * s.w;
		vec2 n = d / max(l, 0.0001);
		n.x /= aspect;
		uv -= n * band * 0.018;
	}
	vec2 dir = uv - focus_uv;
	float amt = ca * (0.3 + length(dir) * 1.2);
	vec3 col;
	col.r = texture(screen_tex, uv + dir * amt * 0.8).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * amt * 0.8).b;
	vec2 c = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float v = smoothstep(0.55, 1.15, length(c));
	col += vec3(0.55, 0.04, 0.03) * v * vig;
	col += (hash(SCREEN_UV * 1000.0 + t) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
