extends SceneTree
# Stills of the Mirror Warden's skills (off-screen, no video): the shard
# volley, the registration stamps, the spotlight, your reflections firing back.
# Usage: tools/run_test.sh tests/warden_skill_shots.gd --fixed-fps 60 -- [english]

const Cap = preload("res://tests/cap.gd")
const OUT := "res://proofs/warden"
var game
var brain
var frame := 0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}
var taken := {}
var stage := 0
var st_t := 0.0


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "english" in OS.get_cmdline_user_args():
		Settings.lang = "en"
	seed(11)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = bot
	root.add_child(scene)
	game = scene
	brain = preload("res://tests/brain.gd").new(bot)


func _shot(k: String) -> void:
	if not taken.has(k):
		taken[k] = true
		Cap.save(root, "%s/%s.png" % [OUT, k])
		print("shot ", k)


func _force(b, rot: int) -> void:
	b.skill = ""
	b.skill_cd = 0.0
	b.guard_t = 0.0
	b.rot = rot
	b.mode = Warden.HOLD
	b.lunge_cd = 99.0


func _process(dt: float) -> bool:
	frame += 1
	if frame == 3:
		game.next_chapter()
		game.lv = {"bounce": 1, "split": 1, "orbit": 1, "magnet": 1, "blast": 0, "charge": 0, "shadow": 0, "chain": 0, "possess": 0}
		game.dev_god = true
	if frame == 12:
		game.dev_jump(Waves.BOSS)
	if frame < 12:
		return false
	var b = game.boss
	if not (b is Warden) or b.state != Warden.RUN:
		brain.think(game)
		return frame > 60 * 60
	st_t += dt
	match stage:
		0:
			# fight a while so rounds sit in the walls, then the volley
			brain.think(game)
			b.skill_cd = maxf(b.skill_cd, 1.0)
			b.lunge_cd = 99.0
			if st_t > 5.0:
				b.glint = 6
				_force(b, 0)
				stage = 1
				st_t = 0.0
		1:
			brain.think(game)
			if b.skill == "volley" and b.skill_t > 0.6:
				_shot("1_volley_warn")
			if taken.has("1_volley_warn") and b.skill == "" and b.shots.size() > 0 and st_t > 1.35:
				_shot("2_volley")
				b.hp = Warden.HP * 0.6
				b.phase = 1
				_force(b, 0)
				stage = 2
				st_t = 0.0
		2:
			brain.think(game)
			if b.stamps.size() > 0:
				var s0: Dictionary = b.stamps[0]
				if s0.t > 1.75:
					_shot("3_stamp_lock")
			if taken.has("3_stamp_lock") and b.stamps.size() > 0 and b.stamps[b.stamps.size() - 1].has("done"):
				_shot("4_stamp_slam")
			if taken.has("4_stamp_slam") and b.skill == "":
				_force(b, 2)
				stage = 3
				st_t = 0.0
		3:
			brain.think(game)
			b.lunge_cd = 99.0
			if b.skill == "beam" and b.skill_t > 0.6:
				_shot("5_beam_warn")
			if b.skill == "beam" and b.skill_t > Warden.BEAM_WARN + 1.0:
				_shot("6_beam_sweep")
				b.hp = Warden.HP * 0.3
				b.phase = 2
				b.skill = ""
				b.skill_cd = 99.0
				stage = 4
				st_t = 0.0
		4:
			# stand along a panel and fire into it: the reflection answers
			b.skill_cd = 99.0
			b.lunge_cd = 99.0
			game.player.pos = Vector2(470, 330)
			bot.move = Vector2.ZERO
			bot.aim = Vector2(900, 330)
			bot.fire = st_t > 0.5 and st_t < 0.62
			if st_t > 0.85 and st_t < 0.95:
				_shot("7_reflection_aim")
			if st_t > 1.08:
				_shot("8_reflection_bolt")
				return true
	return frame > 60 * 120
