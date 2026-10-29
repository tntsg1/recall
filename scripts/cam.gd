class_name Cam
extends Camera2D
# Trauma shake, directional kicks, a zoom punch and a gentle lean toward the
# player. Runs on real time so slow motion never makes the camera mushy.

const CENTER := Vector2(960, 540)

var game
var trauma := 0.0
var kick_v := Vector2.ZERO
var kick_p := Vector2.ZERO
var zoom_k := 0.0
var zoom_v := 0.0
var follow := Vector2.ZERO
var noise := FastNoiseLite.new()
var nt := 0.0
var shake_scale := 1.0


func _ready() -> void:
	position = CENTER
	ignore_rotation = false
	noise.frequency = 1.6
	noise.fractal_octaves = 2


func add_trauma(a: float) -> void:
	trauma = minf(1.0, trauma + a)


func kick(dir: Vector2, amount: float) -> void:
	kick_v += dir * amount * 60.0


func punch(a: float) -> void:
	zoom_v += a * 30.0


func step(dt: float) -> void:
	nt += dt * 60.0
	trauma = maxf(0.0, trauma - dt * 1.5)
	# springs for kick offset and zoom punch
	kick_v += (-kick_p * 260.0 - kick_v * 22.0) * dt
	kick_p += kick_v * dt
	zoom_v += (-zoom_k * 240.0 - zoom_v * 20.0) * dt
	zoom_k += zoom_v * dt
	var f: float = game.focus
	var pl: Vector2 = game.player.pos
	follow = Pal.damp2(follow, (pl - CENTER) * lerpf(0.05, 0.16, f), 5.0, dt)
	var s := trauma * trauma * 16.0 * shake_scale
	var shake := Vector2(noise.get_noise_2d(nt, 0.0), noise.get_noise_2d(0.0, nt)) * s
	position = CENTER + follow + game.rooms.slide()
	offset = shake + kick_p * shake_scale
	rotation = noise.get_noise_2d(nt * 0.5, 77.0) * trauma * trauma * 0.012 * shake_scale
	var z := 1.0 + 0.035 * Pal.ease_io(f) + zoom_k
	zoom = Vector2(z, z)
