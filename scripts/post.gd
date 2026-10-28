class_name Post
extends CanvasLayer
# Drives shaders/post.gdshader over the run (below the HUD, so the numbers stay
# crisp), and only while something is happening: pulse() for the chromatic split, punch() for a zoom toward a point,
# shock() for a ring that bends the picture, hurt() for the red vignette.
# Springs and decays run on real time; softer flashes / no shake tone it down.

var rect: ColorRect
var mat: ShaderMaterial
var ca := 0.0
var zoom_s := Motion.Spring.new(0.0, 260.0, 0.55)
var focus := Vector2(0.5, 0.5)
var vig := 0.0
var shocks: Array = []        # [uv, age, strength, speed]
var t := 0.0


func _ready() -> void:
	layer = 4
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/post.gdshader")
	rect.material = mat
	add_child(rect)


func _soft() -> float:
	return 0.45 if Settings.soft else 1.0


func pulse(a: float) -> void:
	ca = maxf(ca, a * _soft())


func punch(uv: Vector2, z: float) -> void:
	if not Settings.shake:
		z *= 0.3
	focus = uv
	zoom_s.kick(z * 30.0)


func shock(uv: Vector2, strength: float, speed: float = 1.4) -> void:
	shocks.append([uv, 0.0, strength * _soft(), speed])
	if shocks.size() > 6:
		shocks.pop_front()


func hurt(a: float) -> void:
	vig = maxf(vig, a * _soft())


func step(dt: float) -> void:
	t += dt
	ca = maxf(0.0, ca - dt * (0.02 + ca * 3.0))
	vig = maxf(0.0, vig - dt / 0.6)
	zoom_s.step(dt)
	var i := 0
	while i < shocks.size():
		shocks[i][1] += dt
		if shocks[i][1] > 0.6:
			shocks.remove_at(i)
		else:
			i += 1
	# at rest the pass costs a full-screen copy for nothing: switch it off
	var active := ca > 0.0002 or vig > 0.002 or absf(zoom_s.x) > 0.0005 or absf(zoom_s.v) > 0.002 or not shocks.is_empty()
	rect.visible = active
	if not active:
		return
	var vp := rect.get_viewport_rect().size
	var arr := PackedVector4Array()
	for k in 6:
		if k < shocks.size():
			var s: Array = shocks[k]
			var age: float = s[1]
			var fade := 1.0 - age / 0.6
			arr.append(Vector4(s[0].x, s[0].y, age * s[3] * 0.5, s[2] * fade * fade))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	mat.set_shader_parameter("shocks", arr)
	mat.set_shader_parameter("ca", ca)
	mat.set_shader_parameter("zoom", clampf(zoom_s.x, -0.045, 0.045))
	mat.set_shader_parameter("focus_uv", focus)
	mat.set_shader_parameter("vig", vig)
	mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	mat.set_shader_parameter("grain", 0.006 if not Pal.ldr else 0.012)
	mat.set_shader_parameter("t", fmod(t, 100.0))
