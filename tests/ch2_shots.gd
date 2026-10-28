extends SceneTree
# Stills of the Hall of Mirrors (off-screen, no video): the room with prisms,
# the warden turning, its second phase with orbiting prisms, its lunge.
# Usage: tools/run_test.sh tests/ch2_shots.gd --fixed-fps 60

const Cap = preload("res://tests/cap.gd")
var game
var brain
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var taken := {}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/m7"))
	seed(9)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	brain = preload("res://tests/brain.gd").new(bot)


func _shot(k: String) -> void:
	if not taken.has(k):
		taken[k] = true
		Cap.save(root, "res://proofs/m7/%s.png" % k)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 3:
		game.next_chapter()
		game.lv = {"bounce": 1, "split": 1, "orbit": 1, "magnet": 1, "blast": 0, "charge": 0, "shadow": 0, "chain": 0}
	if frame < 4:
		return false
	brain.think(game)
	if frame == 160:
		_shot("1_intro")
	var w = game.wave_ctl
	if w.index == 1 and w.phase == Waves.FIGHT and w.t > 4.0:
		_shot("2_prisms")
		if w.t > 4.1:
			game.dev_jump(Waves.BOSS)
	var b = game.boss
	if b is Warden:
		if b.state == Warden.RUN and b.t > 6.0:
			_shot("3_warden")
		if b.phase == 1 and b.guard_t <= 0.0 and b.t > 2.0:
			_shot("4_phase2")
		if b.phase == 2 and b.mode == Warden.BRACE and b.mode_t > 0.7:
			_shot("5_lunge")
			return true
	return frame > 60 * 240
