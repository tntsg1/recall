class_name Pal
# NEON RAID, kept quiet: a near-black night with a hint of blue. Cyan is you
# (your body, your rounds, the shells you seize), red is everything that hunts
# you, a dusty rose-magenta is the recall's own signal, and the walls are a cool
# grey-blue. All of them are held back from full saturation, and brightness
# above 1 is compressed and leans toward white, so the glow reads as light
# rather than paint. White ink stays for text.

const BG := Color(0.036, 0.036, 0.048)
const WALL := Color(0.068, 0.066, 0.085)
const INK := Color(0.925, 0.93, 0.94)
const RED := Color(0.86, 0.38, 0.64)      # the recall signal (rose-magenta; the name stays for the call sites)
const YOU := Color(0.5, 0.84, 0.92)
const FOE := Color(0.88, 0.37, 0.38)
const LINE := Color(0.6, 0.62, 0.8)


# Brightness above 1 is compressed so nothing blooms too hard.
static func _soft(k: float) -> float:
	return k if k <= 1.0 else 1.0 + (k - 1.0) * 0.55

# The browser build (Compatibility renderer) draws into a plain sRGB buffer:
# no HDR, so faint lines blend much darker and nothing goes above 1. Alphas
# are lifted to read the same as they do over the linear desktop buffer.
static var ldr := OS.has_feature("web")
const LDR_ALPHA := 0.62


static func ink(a: float = 1.0, k: float = 1.0) -> Color:
	if ldr:
		a = pow(clampf(a, 0.0, 1.0), LDR_ALPHA)
	return Color(INK.r * k, INK.g * k, INK.b * k, a)


# The recall's magenta. Brightness above 1 goes into red and blue, so the glow
# pass keeps it magenta instead of washing it white.
static func red(a: float = 1.0, k: float = 1.0) -> Color:
	if ldr:
		a = pow(clampf(a, 0.0, 1.0), LDR_ALPHA)
	if k <= 1.0:
		return Color(RED.r * k, RED.g * k, RED.b * k, a)
	k = _soft(k)
	return Color(RED.r * k, RED.g * (1.0 + (k - 1.0) * 0.45), RED.b * (1.0 + (k - 1.0) * 0.85), a)


# Enemies and bosses: brightness into the red channel only, or it turns pink.
static func foe(a: float = 1.0, k: float = 1.0) -> Color:
	if ldr:
		a = pow(clampf(a, 0.0, 1.0), LDR_ALPHA)
	if k <= 1.0:
		return Color(FOE.r * k, FOE.g * k, FOE.b * k, a)
	k = _soft(k)
	return Color(FOE.r * k, FOE.g * (1.0 + (k - 1.0) * 0.3), FOE.b * (1.0 + (k - 1.0) * 0.3), a)


# You: brightness into green and blue so the glow stays cyan.
static func you(a: float = 1.0, k: float = 1.0) -> Color:
	if ldr:
		a = pow(clampf(a, 0.0, 1.0), LDR_ALPHA)
	if k <= 1.0:
		return Color(YOU.r * k, YOU.g * k, YOU.b * k, a)
	k = _soft(k)
	return Color(YOU.r * (1.0 + (k - 1.0) * 0.7), YOU.g * k, YOU.b * k, a)


# The walls' cold violet-blue neon.
static func line(a: float = 1.0, k: float = 1.0) -> Color:
	if ldr:
		a = pow(clampf(a, 0.0, 1.0), LDR_ALPHA)
	if k <= 1.0:
		return Color(LINE.r * k, LINE.g * k, LINE.b * k, a)
	k = _soft(k)
	return Color(LINE.r * k, LINE.g * k, LINE.b * k, a)


static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x


static func ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


static func back(x: float, k: float = 1.7) -> float:
	x = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + x * x * ((k + 1.0) * x + k)


# Frame-rate independent approach toward a target.
static func damp(v: float, to: float, rate: float, dt: float) -> float:
	return lerpf(v, to, 1.0 - exp(-rate * dt))


static func damp2(v: Vector2, to: Vector2, rate: float, dt: float) -> Vector2:
	return v.lerp(to, 1.0 - exp(-rate * dt))


# A selection band that fades to nothing at both ends, with a little more
# light along its bottom edge, so it reads as light rather than a grey box.
static func band(ci: CanvasItem, r: Rect2, a: float) -> void:
	_hfade(ci, r, a * 0.55)
	_hfade(ci, Rect2(r.position.x, r.end.y - 14.0, r.size.x, 14.0), a * 0.6)


static func _hfade(ci: CanvasItem, r: Rect2, a: float) -> void:
	var l := r.position.x
	var m := r.get_center().x
	var e := r.end.x
	var t := r.position.y
	var b := r.end.y
	var c0 := ink(0.0)
	var c1 := ink(a)
	ci.draw_polygon(PackedVector2Array([Vector2(l, t), Vector2(m, t), Vector2(m, b), Vector2(l, b)]), PackedColorArray([c0, c1, c1, c0]))
	ci.draw_polygon(PackedVector2Array([Vector2(m, t), Vector2(e, t), Vector2(e, b), Vector2(m, b)]), PackedColorArray([c1, c0, c0, c1]))


# The game's reticle as a mouse pointer, for overlays that sit above the HUD.
static func pointer(ci: CanvasItem, p: Vector2, a: float) -> void:
	var c := ink(0.95 * a)
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0)
		ci.draw_line(p + d * 6.0, p + d * 12.0, c, 2.0)
	ci.draw_circle(p, 1.6, c)
