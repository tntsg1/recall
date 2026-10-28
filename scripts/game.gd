class_name Game
extends Node2D
# 归弹 RECALL — shoot, embed, hold Q, release, rounds come home.
# A run: chapters of random waves and a boss, cards after every wave, five cracks.
# Owns input, the two clocks (real and sim) and the order of updates.

const MAG := 24
const FIRE_INTERVAL := 0.105
const FOCUS_MAX := 1.2
const SLOW := 0.08
const CRACKS := 5
const CHAPTERS := 5   # chapters built so far
const REGEN_TIME := 1.4

var arena: Arena
var bullets: Bullets
var enemies: Enemies
var boss                      # the current chapter's boss (train, warden, ...)
var bosses: Array = []
var wave_ctl: Waves
var fx: Fx
var cam: Cam
var player: Player
var possess: Possess
var possess_prev := false
var trial := false            # 训练场: dummies, number keys to any shell, nothing ends, nothing saved
var trial_cd := 0.0
var hud: Hud
var sfx: Sfx
var floor_rect: ColorRect
var floor_mat: ShaderMaterial

var ammo := MAG
var mag := MAG
var fire_cd := 0.0
var empty_cd := 0.0
var focus := 0.0
var focusing := false
var focus_time := 0.0
var slow := 1.0
var hitstop := 0.0
var post: Post
var cine_t := -1.0         # time since a recall began: the world eases back from slow motion
var cine_k := 0.0
var regen: Array[float] = []
var real_time := 0.0
var sim_time := 0.0
var waves: Array = []        # [center, age, strength]
var pass_hits := 0
var pass_active := false
var home_streak := 0
var last_focus_drawn := -1.0
var paused := false
var tutorial: TutorialGate
var assist_panel: AssistPanel
var assist_retries_used := 0
var assist_damage := 0.0
var assist_checkpoint := {}
var assist_restored := false
var focus_held_prev := false
var dash_prev := false
# test driver: {move: Vector2, aim: Vector2 (world), fire: bool, focus: bool, dash: bool}
var bot = null
var hits_taken := 0
var lv := {"bounce": 0, "split": 0, "orbit": 0, "magnet": 0, "blast": 0, "charge": 0, "shadow": 0, "chain": 0, "possess": 0}
var picking := false
var offers: Array = []
var pick_cd := 0.0
var orbit_used := 0
var victory_slow := 0.0
# the run
var chapter := 0
var cracks := CRACKS
var relics: Array[String] = []
var rerolls := 1
var undying_used := false
var armed := {"overload": false, "firststrike": false, "stasis": false, "ward": false, "longhold": false, "slowfield": false, "tempo": false, "haste": false, "calm_mind": false, "card_luck": false}
# run stats (results card, achievements)
var max_combo := 0
var crosses := 0
var crit_recalls := 0
var steals := 0
var rerolled := false
var chapter_hits := 0
var run_ach: Array = []
var wave_haste := false
var wave_calm := false
var encore_ready := false
var waves_cleared := 0
var trail: Array = []   # [sim time, player pos] for echoes
var wave_tempo := false
var crescendo := 0
var last_release := -99.0
var pass_beat := false
var pierce_bank := 0
var grit_t := 0.0
var wave_drag := false
var first_blood_ready := false
var phoenix_used := false
var pass_first = null
var max_cracks := CRACKS
var wave_longhold := false
var pass_focus := false
var pass_big := false
var spare_used := false
var pass_overload := false
var pass_kills := 0
var wave_half := false
var stasis_t := 0.0
var replacing := {}            # the card waiting for a slot to replace
var kills := 0
var run_time := 0.0
var lost := false
# developer mode (` toggles; works in every build)
var dev := false
var dev_god := false
var dev_ammo := false
const DEV_SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0]
var dev_speed := 2


func _ready() -> void:
	Meta.test_mode = bot != null
	if Meta.possess_trial:
		Meta.possess_trial = false
		trial = true
		Meta.test_mode = true
	if Meta.training_requested > 0:
		tutorial = TutorialGate.new()
		tutorial.configure(self, Meta.training_requested)
		Meta.training_requested = 0
	if Meta.resume is Dictionary:
		var snap: Dictionary = Meta.resume
		Meta.resume = null
		call_deferred("_resume", snap)
	if Meta.dev_unlock:
		dev = true
		if bot == null:
			call_deferred("_open_dev_panel")
	Settings.load_all()
	if bot == null:
		randomize()
	_setup_input()
	var env := WorldEnvironment.new()
	env.environment = make_environment()
	add_child(env)
	post = Post.new()
	add_child(post)


	floor_rect = ColorRect.new()
	floor_rect.position = Arena.ROOM.position
	floor_rect.size = Arena.ROOM.size
	floor_rect.z_index = -10
	floor_rect.z_as_relative = false
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = load("res://shaders/floor.gdshader")
	if Pal.ldr:
		floor_mat.set_shader_parameter("gamma", 1.0)
	floor_mat.set_shader_parameter("room_pos", Arena.ROOM.position)
	floor_mat.set_shader_parameter("room_size", Arena.ROOM.size)
	floor_rect.material = floor_mat
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)

	sfx = Sfx.new()
	add_child(sfx)
	arena = Arena.new()
	arena.game = self
	add_child(arena)
	player = Player.new()
	player.game = self
	add_child(player)
	enemies = Enemies.new()
	enemies.game = self
	add_child(enemies)
	possess = Possess.new()
	possess.game = self
	add_child(possess)
	for cls in [Boss, Warden, Devourer, Metronome, Zero]:
		var bn = cls.new()
		bn.game = self
		add_child(bn)
		bosses.append(bn)
	boss = bosses[0]
	wave_ctl = Waves.new()
	wave_ctl.game = self
	add_child(wave_ctl)
	bullets = Bullets.new()
	bullets.game = self
	add_child(bullets)
	fx = Fx.new()
	fx.game = self
	add_child(fx)
	cam = Cam.new()
	cam.game = self
	add_child(cam)
	cam.make_current()
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	if bot == null:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	hud.chapter_intro()
	sfx.game = self
	_apply_loadout()
	if tutorial != null:
		add_child(tutorial)
	if bot == null:
		Settings.apply(get_tree())
	cam.shake_scale = 1.0 if Settings.shake or bot != null else 0.0
	sfx.play("chapter", 1.0, -2.0)


func _setup_input() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"recall": [KEY_Q], "possess": [KEY_E], "dash": [KEY_SPACE, KEY_SHIFT], "pause": [KEY_ESCAPE], "fullscreen": [KEY_F11], "quit": [KEY_BACKSPACE], "restart": [KEY_R], "pick1": [KEY_1], "pick2": [KEY_2], "pick3": [KEY_3],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			for k in keys[a]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(a, ev)
	# gamepad: sticks, triggers, A, Start
	var pad := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	for a2 in pad:
		var jm := InputEventJoypadMotion.new()
		jm.axis = pad[a2][0]
		jm.axis_value = pad[a2][1]
		if not InputMap.action_has_event(a2, jm):
			InputMap.action_add_event(a2, jm)
	for pair in [["dash", JOY_BUTTON_A], ["pause", JOY_BUTTON_START], ["recall", JOY_BUTTON_LEFT_SHOULDER], ["possess", JOY_BUTTON_Y]]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], jb):
			InputMap.action_add_event(pair[0], jb)
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	if not InputMap.action_has_event("recall", lt):
		InputMap.action_add_event("recall", lt)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)
		var mr := InputEventMouseButton.new()
		mr.button_index = MOUSE_BUTTON_RIGHT
		InputMap.add_action("recall_mouse")
		InputMap.action_add_event("recall_mouse", mr)
		var rt := InputEventJoypadMotion.new()
		rt.axis = JOY_AXIS_TRIGGER_RIGHT
		rt.axis_value = 1.0
		InputMap.action_add_event("fire", rt)


func _dev_key(ev: InputEventKey) -> bool:
	var k := ev.physical_keycode
	if ev.ctrl_pressed and k >= KEY_1 and k <= KEY_9:
		dev_action("sch:" + Cards.SCHOOLS[k - KEY_1], null)
		return true
	if ev.ctrl_pressed and k == KEY_R:
		dev_action("relic", null)
		return true
	var keys := {KEY_PAGEUP: "next", KEY_PAGEDOWN: "prev", KEY_B: "boss", KEY_N: "nextch", KEY_H: "heal", KEY_G: "god", KEY_I: "ammo", KEY_K: "kill"}
	if keys.has(k):
		dev_action(keys[k], null)
		return true
	match k:
		KEY_BRACKETLEFT:
			dev_action("speed", maxi(0, dev_speed - 1))
		KEY_BRACKETRIGHT:
			dev_action("speed", mini(DEV_SPEEDS.size() - 1, dev_speed + 1))
		KEY_Z:
			dev_action("spawn", Enemies.CHASER)
		KEY_X:
			dev_action("spawn", Enemies.GUARD)
		KEY_C:
			dev_action("spawn", Enemies.CHARGER)
		_:
			return false
	return true


# Every developer action, from a shortcut or from the panel.
func dev_action(id: String, arg) -> void:
	if id.begins_with("sch:"):
		var key := id.substr(4)
		lv[key] = (lv[key] + 1) % 4
		hud.school_pop[key] = 1.0
	else:
		match id:
			"close":
				_set_dev(false)
				return
			"next":
				dev_jump(mini(wave_ctl.index + 1, Waves.COUNT - 1))
			"prev":
				dev_jump(maxi(wave_ctl.index - 1, 0))
			"boss":
				dev_jump(Waves.BOSS)
			"nextch":
				if chapter + 1 < CHAPTERS:
					replacing = {}
					picking = false
					hud.replace_done()
					hud.cards_t = -1.0
					next_chapter()
			"heal":
				cracks = max_cracks
				hud.crack_mend(cracks)
			"god":
				dev_god = not dev_god
			"ammo":
				dev_ammo = not dev_ammo
			"kill":
				for e in enemies.list:
					if e.state == Enemies.ALIVE:
						enemies._die(e, Vector2.UP)
					else:
						e.state = Enemies.DEAD
				boss.dev_strike()
			"speed":
				dev_speed = int(arg)
				Engine.time_scale = DEV_SPEEDS[dev_speed]
			"relic":
				var pool: Array = []
				for rid in Cards.RELICS:
					if not relics.has(rid):
						pool.append(rid)
				if not pool.is_empty():
					if relics.size() >= Cards.RELIC_SLOTS:
						_lose_relic(relics[0])
						relics.remove_at(0)
					var pick: String = pool[randi() % pool.size()]
					_gain_relic(pick)
					hud.relic_pop[pick] = 1.0
					hud.flash_text(Cards.relic_name(pick))
			"spawn":
				# from the panel the pointer is on the panel: drop it near the player instead
				var at := aim_world()
				if dev_panel and dev_panel.over:
					at = player.pos + Vector2.from_angle(randf() * TAU) * 320.0
				enemies.spawn(int(arg), at)
	sfx.play("tick", 1.2, -8.0)


var dev_panel: DevPanel


func _open_dev_panel() -> void:
	if not is_instance_valid(dev_panel):
		dev_panel = DevPanel.new().setup(self, _dev_rows())
		add_child(dev_panel)


func _set_dev(on: bool) -> void:
	dev = on
	if not dev:
		Engine.time_scale = 1.0
		dev_speed = 2
	sfx.play("tick", 1.4 if dev else 0.8, -4.0)
	if dev and bot == null and not is_instance_valid(dev_panel):
		dev_panel = DevPanel.new().setup(self, _dev_rows())
		add_child(dev_panel)
	elif not dev and is_instance_valid(dev_panel):
		dev_panel.close()
		dev_panel = null


func _dev_rows() -> Array:
	var chips: Array = []
	for k in Cards.SCHOOLS:
		chips.append({"label": Txt.t("sch_" + k), "id": "sch:" + k, "get": func(): return int(lv.get(k, 0))})
	return [
		{"kind": "stat", "get": func(): return "FPS %d  ·  %s %d  ·  %s %d  ·  ×%.2f" % [Engine.get_frames_per_second(), Txt.t("dev_ch"), chapter + 1, Txt.t("dev_wave"), wave_ctl.index + 1, Engine.time_scale]},
		{"kind": "stat", "get": func(): return "%s %d  ·  boss %d / %d" % [Txt.t("devx_enemies"), enemies.remaining(), int(boss.hp), boss.phase]},
		{"kind": "head", "text": Txt.t("devx_h_jump")},
		{"kind": "btns", "items": [{"label": Txt.t("devx_prev"), "id": "prev"}, {"label": Txt.t("devx_next"), "id": "next"}]},
		{"kind": "btns", "items": [{"label": Txt.t("dev_boss"), "id": "boss"}, {"label": Txt.t("dev_next_ch"), "id": "nextch"}]},
		{"kind": "head", "text": Txt.t("devx_h_toggle")},
		{"kind": "toggle", "label": Txt.t("dev_god"), "id": "god", "get": func(): return dev_god},
		{"kind": "toggle", "label": Txt.t("dev_ammo"), "id": "ammo", "get": func(): return dev_ammo},
		{"kind": "head", "text": Txt.t("devx_h_field")},
		{"kind": "btns", "items": [{"label": Txt.t("devx_kill"), "id": "kill"}, {"label": Txt.t("dev_heal"), "id": "heal"}, {"label": Txt.t("devx_relic"), "id": "relic"}]},
		{"kind": "head", "text": Txt.t("devx_h_time")},
		{"kind": "seg", "id": "speed", "options": ["×0.25", "×0.5", "×1", "×2", "×4"], "get": func(): return dev_speed},
		{"kind": "head", "text": Txt.t("devx_h_sch")},
		{"kind": "chips", "items": chips},
		{"kind": "head", "text": Txt.t("devx_h_spawn")},
		{"kind": "btns", "items": [{"label": Txt.t("devx_chaser"), "id": "spawn", "arg": Enemies.CHASER}, {"label": Txt.t("devx_guard"), "id": "spawn", "arg": Enemies.GUARD}, {"label": Txt.t("devx_charger"), "id": "spawn", "arg": Enemies.CHARGER}]},
	]


# Dev: start wave i from its title, clearing whatever is on the field.
func dev_jump(i: int) -> void:
	for e in enemies.list:
		e.state = Enemies.DEAD
	boss.reset()
	picking = false
	hud.cards_t = -1.0
	hud.cards.clear()
	hud.final_t = -1.0
	replacing = {}
	hud.replace_done()
	var w := wave_ctl
	while w.results.size() > i:
		w.results.pop_back()
	while w.results.size() < i:
		w.results.append([0.0, "-"])
	w.queue.clear()
	w.index = i - 1
	w._next()


func _apply_loadout() -> void:
	mag = Loadout.mag()
	ammo = mag
	if Loadout.at_least(4):
		max_cracks = 4
	rerolls = 0 if Loadout.at_least(2) else 1
	match Loadout.gun:
		"ricochet":
			lv.bounce = 1
		"orbiter":
			lv.orbit = 2
		"zero":
			max_cracks = 3
			var pool: Array = Cards.RELICS.keys()
			pool.shuffle()
			for k in 2:
				relics.append(pool[k])
	cracks = max_cracks
	if has("glass_cannon"):
		max_cracks -= 1
		cracks = max_cracks


func gun_dmg() -> float:
	var m := Loadout.dmg_mult()
	if has("glass_cannon"):
		m *= 1.4
	if has("apex"):
		var n := 0
		for k in lv:
			if lv[k] >= 3:
				n += 1
		if n >= 3:
			m *= 1.5
	return m


# Achievements: saved, mirrored to Steam, and shown once.
func ach(id: String) -> void:
	if bot != null or tutorial != null:
		return
	if Meta.achieve(id):
		run_ach.append(id)
		hud.flash_text(Txt.t("ach_got") + " · " + Ach.name_of(id))
		sfx.play("relic", 1.2, -4.0)


func has(id: String) -> bool:
	return relics.has(id)


func fire_interval() -> float:
	var k := 0.8 if has("quick") else 1.0
	if has("heavy"):
		k *= 1.1
	if wave_tempo:
		k *= 0.6
	if has("steady") and player.vel.length() < 30.0:
		k *= 0.7
	return FIRE_INTERVAL * k * Loadout.fire_mult()


func focus_max() -> float:
	if wave_longhold:
		return 3.0
	return (2.0 if has("stillheart") else FOCUS_MAX) + (0.3 if has("deep_focus") else 0.0)


func slow_min() -> float:
	return 0.04 if has("stillheart") or has("deep_focus") else SLOW


func embed_life() -> float:
	return 20.0 if has("longfuse") else Bullets.LIFE


func out_dmg() -> float:
	return Bullets.OUT_DMG * (1.5 if has("whet") else 1.0) * gun_dmg()


# Multiplier on every returning hit of the current recall.
func ret_mult() -> float:
	var m := 1.0
	if has("chain"):
		m *= 1.0 + 0.06 * pass_hits
	if has("zeroblade"):
		m *= minf(4.0, pow(1.08, pass_hits))
	if has("reaper"):
		m *= 1.0 + 0.12 * pass_kills
	if pass_overload:
		m *= 3.0
	if pass_focus:
		m *= 1.4
	if pass_big:
		m *= 2.0
	if pass_beat:
		m *= 1.3
	if has("crescendo"):
		m *= 1.0 + 0.25 * crescendo
	if grit_t > 0.0:
		m *= 1.2
	if has("fortress"):
		m *= 1.0 + 0.08 * (max_cracks - cracks)
	if wave_calm:
		m *= 1.2
	if has("fortress"):
		m *= 1.0 + 0.08 * (max_cracks - cracks)
	if has("keen_edge"):
		m *= 1.15
	return m * gun_dmg()


func enemy_speed() -> float:
	var k := (0.3 if stasis_t > 0.0 else 1.0) * Loadout.enemy_speed() * (1.0 + 0.05 * chapter)
	if has("time_lord") and focusing:
		k = 0.0
	return k * (0.8 if wave_drag else 1.0)


func out_mult() -> float:
	var m := 1.0
	if has("heavy"):
		m *= 1.25
	if grit_t > 0.0:
		m *= 1.2
	if has("overflow") and ammo >= mag - 1:
		m *= 1.4
	return m


# Blast school: a returning round that pierced goes off where it last hit.
func blast(at: Vector2, charge: int) -> void:
	var lvl: int = lv.blast
	var rad := 80.0 if lvl == 1 else 120.0
	var dmg := (12.0 if lvl == 1 else 18.0) * charge
	fx.ring(at, 8.0, rad, 0.35, Pal.red(1.0, 2.6), 3.0)
	fx.flash(at, rad * 0.9, 0.25, Pal.red(0.6, 2.0))
	fx.sparks(at, Vector2.UP, 10, Pal.red(1.0, 2.6), 500.0, 0.3, PI)
	sfx.play("slam", 1.3, -3.0)
	cam.add_trauma(0.15)
	for e in enemies.list:
		if e.state == Enemies.ALIVE and e.pos.distance_to(at) < rad + e.r:
			enemies.blast_hit(e, (e.pos - at).normalized(), dmg)
	if boss.alive() and boss.state != Boss.DYING and boss.core_pos().distance_to(at) < rad + 40.0:
		boss.damage(dmg * 0.5, true, boss.core_pos(), Vector2.UP)


var pad_aim := false
var pad_dir := Vector2.RIGHT
var _last_mouse := Vector2.ZERO


func _pause_choice(c: String) -> void:
	if tutorial != null and c == "restart":
		Meta.training_requested = tutorial.entry
		paused = true
		hud.paused = false
		Engine.time_scale = 1.0
		hud.close_to(func(): get_tree().call_deferred("reload_current_scene"))
		return
	if tutorial != null and c == "title":
		paused = true
		hud.paused = false
		Engine.time_scale = 1.0
		hud.close_to(func(): get_tree().call_deferred("change_scene_to_file", "res://scenes/title.tscn"))
		return
	match c:
		"assist":
			assist_panel = AssistPanel.new()
			assist_panel.game = self
			add_child(assist_panel)
		"resume":
			paused = false
			hud.paused = false
			sfx.play("card", 1.1, -8.0)
		"restart":
			paused = false
			hud.paused = false
			Engine.time_scale = 1.0
			hud.close_to(func(): get_tree().reload_current_scene())
		"title":
			paused = false
			hud.paused = false
			Engine.time_scale = 1.0
			hud.close_to(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
		"quit":
			if Meta.leave(get_tree()):
				_pause_choice("title")


func aim_world() -> Vector2:
	if bot != null:
		return bot.aim
	# the right stick takes over aiming until the mouse moves again
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.35:
		pad_aim = true
		pad_dir = rs.normalized()
	var mp := get_global_mouse_position()
	if mp.distance_to(_last_mouse) > 2.0:
		pad_aim = false
	_last_mouse = mp
	if pad_aim:
		return player.pos + pad_dir * 260.0
	return mp


func _in_move() -> Vector2:
	if bot != null:
		return bot.move
	return Input.get_vector("left", "right", "up", "down")


func _in_fire() -> bool:
	if tutorial != null and tutorial.stage != TutorialGate.SHOOT and tutorial.stage != TutorialGate.POSSESS:
		return false
	if tutorial != null and not bullets.list.is_empty():
		return false
	if bot == null and is_instance_valid(dev_panel) and dev_panel.over:
		return false
	return bot.fire if bot != null else Input.is_action_pressed("fire")


func _in_focus() -> bool:
	if tutorial != null and tutorial.stage not in [TutorialGate.HOLD, TutorialGate.RETURN, TutorialGate.POSSESS]:
		return false
	if bot != null:
		return bot.focus
	return Input.is_action_pressed("recall") or Input.is_action_pressed("recall_mouse")


# 训练场 (the title's training yard): no real fight. A field of target dummies that
# never die for long, and the number keys put you straight into any shell:
# 1 chaser · 2 leech · 3 guard · 4 charger · 5 prism · 6 pulse · 7 echo. No time
# limit, no cooldown, nothing can hurt you; E steps out, R resets the dummies,
# T makes them walk and fight back. Shooting and Q still work for the combos.
const YARD_KEYS := [Enemies.CHASER, Enemies.LEECH, Enemies.GUARD, Enemies.CHARGER, Enemies.PRISM, Enemies.PULSE, Enemies.ECHO]
var yard_slots: Array = []      # [kind, home position, enemy or null, respawn timer]
var yard_live := false
var yard_timed := false         # Y: shells run their real time (to see the Lv2 chain and the final blast)


func _yard_layout() -> void:
	yard_slots.clear()
	var c := Arena.ROOM.get_center()
	# an arc of chasers, two guards in front of the right wall to ram into it, two chargers
	for k in 7:
		yard_slots.append([Enemies.CHASER, c + Vector2.from_angle(-PI * 0.75 + k * PI * 0.25) * 300.0 + Vector2(120, 0), null, 0.0])
	yard_slots.append([Enemies.GUARD, Vector2(Arena.ROOM.end.x - 200.0, c.y - 90.0), null, 0.0])
	yard_slots.append([Enemies.GUARD, Vector2(Arena.ROOM.end.x - 200.0, c.y + 90.0), null, 0.0])
	yard_slots.append([Enemies.CHARGER, c + Vector2(-80, -330), null, 0.0])
	yard_slots.append([Enemies.CHARGER, c + Vector2(-80, 330), null, 0.0])


func _trial_step(sdt: float) -> void:
	dev_god = true
	dev_ammo = true
	possess.endless = not yard_timed
	possess.cooldown = 0.0
	if wave_ctl.phase != Waves.FIGHT:
		return
	wave_ctl.queue.clear()
	if yard_slots.is_empty():
		_yard_layout()
		for e in enemies.list:
			if e.state != Enemies.HOST:
				e.state = Enemies.DEAD
	for sl in yard_slots:
		var e = sl[2]
		if e != null and e.state == Enemies.DEAD:
			sl[2] = null
			sl[3] = 1.2
		if sl[2] == null:
			sl[3] -= sdt
			if sl[3] <= 0.0:
				var ne = enemies.spawn(sl[0], sl[1])
				sl[2] = ne
		elif not yard_live and e.state == Enemies.ALIVE:
			# a dummy: it stays on its spot and does not come for you
			e.vel = Vector2.ZERO
			e.mode = Enemies.APPROACH
			e.cool = 99.0
			e.pos = e.pos.lerp(sl[1], 1.0 - exp(-2.0 * sdt))


func yard_key(k: int) -> void:
	if k == KEY_L:
		# the 夺壳 school, 0 → 3
		lv.possess = (int(lv.get("possess", 0)) + 1) % 4
		hud.school_pop["possess"] = 1.0
		hud.flash_text(Txt.t("yard_lv_now") % lv.possess)
		sfx.play("pick", 1.0 + lv.possess * 0.1, -6.0)
		return
	if k == KEY_Y:
		yard_timed = not yard_timed
		possess.endless = not yard_timed
		if yard_timed and possess.hosting():
			possess.t_left = possess.duration()
		hud.flash_text(Txt.t("yard_timed_on" if yard_timed else "yard_timed_off"))
		sfx.play("tick", 1.0, -6.0)
		return
	if k == KEY_M:
		for sl in yard_slots:
			if sl[2] != null and sl[2].state == Enemies.ALIVE:
				possess.mark(sl[2])
		sfx.play("lit", 1.0, -6.0)
		return
	if k == KEY_R:
		for sl in yard_slots:
			if sl[2] != null and sl[2].state != Enemies.HOST:
				sl[2].state = Enemies.DEAD
			sl[3] = 0.0
		sfx.play("reroll", 1.0, -6.0)
		return
	if k == KEY_T:
		yard_live = not yard_live
		for sl in yard_slots:
			if sl[2] != null and sl[2].state == Enemies.ALIVE:
				sl[2].speed = Enemies.SPEC[sl[0]].speed if yard_live else sl[2].speed
		hud.flash_text(Txt.t("yard_live_on" if yard_live else "yard_live_off"))
		sfx.play("tick", 1.0, -6.0)
		return
	var i := k - KEY_1
	if i < 0 or i >= YARD_KEYS.size():
		return
	# straight into that shell, wherever you stand
	if possess.hosting():
		possess.end(false, true)
	var e = enemies.spawn(YARD_KEYS[i], player.pos + player.aim * 4.0)
	e.state = Enemies.ALIVE
	e.t = 0.0
	possess.seize_now(e)


func _in_possess() -> bool:
	if tutorial != null and tutorial.stage != TutorialGate.POSSESS:
		return false
	if bot != null:
		return bot.get("possess", false)
	return Input.is_action_pressed("possess")


# The left button while seized: the shell's own attack.
func _in_ability() -> bool:
	if bot != null:
		return bot.fire
	if is_instance_valid(dev_panel) and dev_panel.over:
		return false
	return Input.is_action_pressed("fire")


func _in_dash() -> bool:
	if tutorial != null and tutorial.stage != TutorialGate.DASH:
		return false
	return bot.dash if bot != null else Input.is_action_pressed("dash")


# ~ asks for the code first (111); the run stands still while the box is open.
func _ask_dev_code() -> void:
	if has_node("DevPrompt"):
		return
	var keep := Engine.time_scale
	Engine.time_scale = 0.0001
	var dp := DevPrompt.new()
	dp.name = "DevPrompt"
	dp.unlocked.connect(func():
		Meta.dev_auth = true
		_set_dev(true))
	dp.tree_exited.connect(func(): Engine.time_scale = keep if not dev else 1.0)
	add_child(dp)
	sfx.play("tick", 1.1, -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(assist_panel):
		return
	if trial and not paused and event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if (kc >= KEY_1 and kc <= KEY_7) or kc in [KEY_R, KEY_T, KEY_L, KEY_Y, KEY_M]:
			yard_key(kc)
			get_viewport().set_input_as_handled()
			return
	if tutorial != null and not paused and tutorial.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT:
			if bot == null and not Meta.dev_auth and not dev:
				_ask_dev_code()
				get_viewport().set_input_as_handled()
				return
			_set_dev(not dev)
			get_viewport().set_input_as_handled()
			return
		if dev and _dev_key(event):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	elif event.is_action_pressed("pause"):
		paused = not paused
		hud.paused = paused
		if paused:
			hud.pause_open()
		sfx.play("card", 0.9 if paused else 1.1, -8.0)
	elif paused:
		if event.is_action_pressed("ui_up"):
			hud.pause_move(-1)
		elif event.is_action_pressed("ui_down"):
			hud.pause_move(1)
		elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hud.pause_hover() >= 0):
			_pause_choice(hud.pause_choice())
		elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_M:
			_pause_choice("title")
		elif event.is_action_pressed("restart"):
			_pause_choice("restart")
		elif event.is_action_pressed("quit"):
			get_tree().quit()
	elif paused and event.is_action_pressed("quit"):
		get_tree().quit()
	elif (lost or wave_ctl.phase == Waves.DONE) and event is InputEventKey and event.pressed and event.physical_keycode == KEY_M:
		_pause_choice("title")
	elif not replacing.is_empty() and not paused:
		if event is InputEventKey and event.pressed and not event.echo:
			var kc: int = event.physical_keycode
			if kc >= KEY_1 and kc <= KEY_5:
				replace_slot(kc - KEY_1)
			elif kc == KEY_0 or kc == KEY_X:
				replace_slot(-1)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var j: int = hud.replace_at(hud.reticle)
			if j != -2:
				replace_slot(j)
	elif picking and not paused:
		for k in 3:
			if event.is_action_pressed("pick%d" % (k + 1)) and k < offers.size():
				choose(k)
				return
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_T:
			reroll()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var k2: int = hud.card_at(hud.reticle)
			if k2 >= 0:
				choose(k2)
			elif hud.reroll_hit(hud.reticle):
				reroll()
	elif event.is_action_pressed("restart") and (wave_ctl.phase == Waves.DONE or lost):
		_pause_choice("restart")



# The run's glow. The title builds the same one at no strength, so the glow
# passes are compiled and their buffers made before the first frame of play.
static func make_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.05
	if Pal.ldr:
		# nothing passes 1.0 here: let only the clipped-white highlights glow
		e.glow_hdr_threshold = 0.97
		e.glow_intensity = 0.7
	e.glow_hdr_scale = 2.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lv in 7:
		e.set_glow_level(lv, 0.0)
	e.set_glow_level(1, 0.6)
	e.set_glow_level(2, 0.8)
	e.set_glow_level(3, 0.6)
	e.set_glow_level(4, 0.35)
	return e


var resume_note := false


# per-section frame timings, filled only while a perf test asks for them
var prof_on := false
var prof := {}
var _lap_at := 0


func _lap(name: String) -> void:
	var now := Time.get_ticks_usec()
	prof[name] = (now - _lap_at) / 1000.0
	_lap_at = now


func _process(dt: float) -> void:
	if prof_on:
		prof.clear()
		_lap_at = Time.get_ticks_usec()
	_run_frame(dt)
	if prof_on:
		_lap("tail")


func _run_frame(dt: float) -> void:
	dt = minf(dt, 1.0 / 20.0)
	if paused:
		hud.step(dt)
		sfx.step(dt, 1.0)
		post.step(dt)
		return
	real_time += dt
	if picking and bot != null and bot.get("pick", -1) >= 0:
		choose(bot.pick)
		bot.pick = -1
	if not replacing.is_empty() and bot != null and bot.has("replace"):
		replace_slot(bot.replace)
		bot.erase("replace")
	_update_focus(dt)
	var sdt := dt * slow
	if cine_t >= 0.0:
		# the recall: the world drops into slow motion and eases back out of it
		cine_t += dt
		var back := Pal.ease_in(clampf(cine_t / 0.42, 0.0, 1.0))
		sdt *= lerpf(lerpf(1.0, 0.28, cine_k), 1.0, back)
		if cine_t > 0.42:
			cine_t = -1.0
	if hitstop > 0.0:
		hitstop -= dt
		sdt *= 0.05
	sim_time += sdt
	grit_t = maxf(0.0, grit_t - sdt)
	_beat_events()
	if wave_ctl.phase == Waves.FIGHT:
		run_time += sdt
	stasis_t = maxf(0.0, stasis_t - sdt)

	var move := _in_move()
	var pnow := _in_possess()
	if pnow and not possess_prev and not picking and replacing.is_empty() and wave_ctl.phase == Waves.FIGHT and not lost:
		possess.press()
	possess_prev = pnow
	var dash := _in_dash() and not possess.busy()
	if dash and not dash_prev and player.try_dash(move):
		if tutorial != null:
			tutorial.dashed = true
		sfx.play("dash", randf_range(0.95, 1.05), -6.0)
		fx.ring(player.pos, 10.0, 34.0, 0.25, Pal.ink(0.5), 1.2)
	dash_prev = dash
	if possess.hosting():
		possess.host_step(sdt, dt, move, aim_world(), _in_ability() and not picking)
	elif not possess.busy():
		player.step(sdt, dt, move, aim_world())
	possess.step(sdt, dt)
	if prof_on:
		_lap("player+possess")
	trail.append([sim_time, player.pos])
	while trail.size() > 2 and sim_time - trail[0][0] > 4.0:
		trail.pop_front()
	_update_fire(sdt, dt)
	if prof_on:
		_lap("fire")
	bullets.step(sdt, dt)
	if prof_on:
		_lap("bullets")
	enemies.step(sdt)
	if prof_on:
		_lap("enemies")
	boss.step(sdt)
	if prof_on:
		_lap("boss")
	if tutorial != null:
		tutorial.step(dt)
	else:
		wave_ctl.step(sdt)
		if trial:
			_trial_step(sdt)
	if prof_on:
		_lap("waves")
	fx.step(sdt, dt)
	if prof_on:
		_lap("fx")
	_update_regen(sdt)
	_update_pass()
	if prof_on:
		_lap("regen+pass")
	cam.step(dt)
	post.step(dt)
	hud.step(dt)
	sfx.step(dt, focus)
	if prof_on:
		_lap("cam+post+hud+sfx")
	_update_floor(dt)
	if absf(focus - last_focus_drawn) > 0.004:
		last_focus_drawn = focus
		arena.queue_redraw()


func _update_focus(dt: float) -> void:
	var held := _in_focus()
	var pressed := held and not focus_held_prev
	focus_held_prev = held
	if pressed and not focusing:
		if bullets.count_state(Bullets.EMBED) > 0:
			_start_focus()
		else:
			player.empty_pulse = 1.0
			hud.dry()
			sfx.play("empty", 0.8, -8.0)
	if focusing:
		focus_time += dt
		if has("leech_ward"):
			for b in bullets.list:
				if b.state == Bullets.CAPTURED and not b.child:
					bullets.send_home(b)
		if not held or focus_time >= focus_max():
			_release()
	focus = Pal.damp(focus, 1.0 if focusing else 0.0, 11.0 if focusing else 6.5, dt)
	slow = lerpf(1.0, slow_min(), Pal.ease_io(focus))
	if victory_slow > 0.0:
		victory_slow = maxf(0.0, victory_slow - dt / 1.6)
		slow = minf(slow, lerpf(1.0, 0.15, Pal.ease_out(victory_slow)))


func _start_focus() -> void:
	focusing = true
	focus_time = 0.0
	bullets.light_up(player.pos)
	sfx.play("focus", 1.0, -3.0)
	cam.add_trauma(0.12)
	fx.ring(player.pos, 20.0, 90.0, 0.5, Pal.red(0.8, 2.0), 1.5)


func _release() -> void:
	focusing = false
	var held := focus_time
	var n := bullets.recall(player.pos)
	possess.on_recall_release()
	if n <= 0:
		return
	pass_focus = has("focus_lens") and held >= 0.8
	# Downbeat: a release on the beat lands harder
	var on_beat: bool = sfx.beat_frac() < 0.12 or sfx.beat_frac() > 0.88
	if on_beat and Meta.count("beat") >= 10:
		ach("beat10")
	ach("first_recall")
	pass_beat = has("downbeat") and on_beat
	if pass_beat:
		hud.flash_text(Cards.relic_name("downbeat"))
	if has("crescendo"):
		crescendo = mini(4, crescendo + 1) if real_time - last_release < 4.0 else 0
	last_release = real_time
	pass_big = has("eclipse") and n >= 12
	if pass_big:
		hud.flash_text(Cards.relic_name("eclipse") + "  ×2")
	pass_active = true
	pass_hits = 0
	pass_kills = 0
	orbit_used = 0
	for e in enemies.list:
		e.pass_hits = 0
	pass_overload = armed.overload
	if armed.overload:
		armed.overload = false
		hud.flash_text(Cards.item_name("overload") + "  ×3")
		cam.add_trauma(0.2)
	home_streak = 0
	sfx.play("release", 1.0, 0.0)
	sfx.drop()
	cam.add_trauma(0.32)
	cam.punch(0.05)
	fx.ring(player.pos, 18.0, 240.0, 0.5, Pal.red(1.0, 2.6), 2.5)
	fx.flash(player.pos, 90.0, 0.22, Pal.red(0.4, 1.6))
	fx.wave_push(player.pos, 700.0, 160.0)
	_wave(player.pos, 1.0)
	hud.recalled_once()
	hud.recall_pull()
	# the cinematic: slow motion, a zoom punch at you, the colours split, lines rush in
	cine_k = clampf(n / 12.0, 0.35, 1.0)
	cine_t = 0.0
	var su := screen_uv(player.pos)
	post.pulse(0.006 + 0.008 * cine_k)
	post.punch(su, 0.018 + 0.022 * cine_k)
	post.shock(su, 1.2 * cine_k, 2.2)
	hud.speed_lines(cine_k)


func _update_fire(sdt: float, dt: float) -> void:
	fire_cd -= sdt
	empty_cd -= dt
	pick_cd -= dt
	if focusing or picking or pick_cd > 0.0 or possess.busy() or not _in_fire() or fire_cd > 0.0:
		return
	if lv.orbit >= 3 and bullets.orbit_count() > 0:
		# lv3 orbit: the ring empties first and the magazine is untouched
		if bullets.fire_from_orbit(aim_world()):
			fire_cd = fire_interval()
			player.kick()
			hud.fired()
			sfx.play("shot", randf_range(1.05, 1.15), -5.0)
			cam.kick(-player.aim, 1.2)
		return
	if ammo <= 0:
		if empty_cd <= 0.0:
			empty_cd = 0.3
			player.empty_pulse = 1.0
			hud.dry()
			sfx.play("empty", 1.0, -6.0)
		return
	fire_cd = fire_interval()
	if not dev_ammo:
		ammo -= 1
	var dir := player.aim
	var at := player.muzzle()
	# never spawn a round inside a wall
	var h := arena.raycast(player.pos, at)
	if h:
		at = h.point - dir * 1.0
	bullets.fire(at, dir)
	if Loadout.gun == "scatter":
		for side in [-1.0, 1.0]:
			if ammo > 0:
				if not dev_ammo:
					ammo -= 1
				bullets.fire(at, dir.rotated(0.12 * side))
	if has("twin"):
		bullets.twin(at, dir.rotated(randf_range(-0.09, 0.09)))
	if ammo == 0 and has("spare_round") and not spare_used:
		spare_used = true
		bullets.quick_home(3)
	player.kick()
	player.pop_tick(ammo, false)
	hud.fired()
	sfx.play("shot", randf_range(0.94, 1.06), -4.0)
	cam.kick(-dir, 1.6)
	cam.add_trauma(0.035)
	fx.flash(at + dir * 4.0, 34.0, 0.07, Pal.ink(0.9, 2.0))
	fx.spark(at, dir.rotated(0.5) * 260.0, 0.08, Pal.ink(1.0, 2.0), 1.2, 6.0, 14.0)
	fx.spark(at, dir.rotated(-0.5) * 260.0, 0.08, Pal.ink(1.0, 2.0), 1.2, 6.0, 14.0)


func _update_regen(sdt: float) -> void:
	var i := 0
	while i < regen.size():
		regen[i] -= sdt
		if regen[i] <= 0.0:
			regen.remove_at(i)
			if ammo < mag:
				player.pop_tick(ammo, false)
				ammo += 1
				hud.ammo_in()
				sfx.play("home", 0.7, -14.0)
		else:
			i += 1


func _update_pass() -> void:
	if pass_active and not bullets.recall_active():
		pass_active = false
		max_combo = maxi(max_combo, pass_hits)
		if pass_hits >= 10:
			ach("pierce10")
		if pass_hits >= 30:
			ach("pierce30")
		if pass_hits >= 60:
			ach("pierce60")
		pass_overload = false
		pass_focus = false
		pass_big = false
		if has("echo") and pass_first != null and pass_first.state == Enemies.ALIVE and pass_hits > 0:
			enemies.blast_hit(pass_first, Vector2.UP, 6.0 * pass_hits)
			fx.ring(pass_first.pos, 6.0, 60.0, 0.4, Pal.red(0.9, 2.4), 2.0)
		if has("singularity") and pass_hits >= 20:
			hud.flash_text(Cards.relic_name("singularity"))
			fx.ring(player.pos, 20.0, 1600.0, 1.0, Pal.red(0.9, 2.4), 4.0)
			for e in enemies.list:
				if e.state == Enemies.ALIVE:
					enemies.blast_hit(e, Vector2.UP, 50.0)
		pass_first = null
		if pass_hits > 0:
			hud.combo_end()
			if pass_hits >= 6:
				cam.add_trauma(0.2)
				cam.punch(0.03)


func _update_floor(dt: float) -> void:
	var packed: Array[Vector4] = []
	var i := 0
	while i < waves.size():
		waves[i][1] += dt
		if waves[i][1] > 1.6:
			waves.remove_at(i)
		else:
			i += 1
	for k in 4:
		if k < waves.size():
			var w: Array = waves[waves.size() - 1 - k]
			packed.append(Vector4(w[0].x, w[0].y, w[1], w[2]))
		else:
			packed.append(Vector4(0, 0, 0, 0))
	floor_mat.set_shader_parameter("waves", packed)
	floor_mat.set_shader_parameter("player", player.pos)
	floor_mat.set_shader_parameter("focus", focus)
	floor_mat.set_shader_parameter("t", real_time)


func _wave(at: Vector2, strength: float) -> void:
	waves.append([at, 0.0, strength])
	if waves.size() > 4:
		waves.remove_at(0)


func queue_regen() -> void:
	regen.append(REGEN_TIME)


func add_hitstop(t: float) -> void:
	hitstop = minf(maxf(hitstop, t), 0.09)


# ---------------------------------------------------------------- events

func on_embed(b, normal: Vector2) -> void:
	var p: Vector2 = b.pos
	if has("spark") and not b.foe:
		for e in enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(p) < 30.0 + e.r:
				enemies.blast_hit(e, (e.pos - p).normalized(), 6.0)
	if bullets.list.size() > 250:
		# a storm of split rounds: one quiet mark each
		fx.flash(p, 14.0, 0.1, Pal.ink(0.4, 1.3))
		if randf() < 0.15:
			sfx.play("embed", randf_range(0.9, 1.1), -14.0)
		return
	fx.sparks(p, normal, 5, Pal.ink(1.0, 1.8), 340.0, 0.2, 0.8)
	fx.spark(p, normal.orthogonal() * 180.0, 0.12, Pal.ink(0.9, 1.5), 1.0, 5.0)
	fx.spark(p, -normal.orthogonal() * 180.0, 0.12, Pal.ink(0.9, 1.5), 1.0, 5.0)
	fx.flash(p, 22.0, 0.12, Pal.ink(0.6, 1.6))
	sfx.play("embed", randf_range(0.9, 1.1), -9.0)


func on_target_hit(ret: bool) -> void:
	if tutorial != null and ret:
		tutorial.return_hit = true
	if ret:
		pass_hits += 1
		if has("vampire"):
			pierce_bank += 1
			if pierce_bank >= 40:
				pierce_bank = 0
				if cracks < max_cracks:
					cracks += 1
					hud.crack_mend(cracks)
					sfx.play("mend", 1.2, -4.0)
		hud.combo_hit(pass_hits)
		hud.hit_confirm(true)
		var rung := mini(pass_hits - 1, 20)
		# A minor pentatonic from A4, the key the music is in
		var ladder := [0, 3, 5, 7, 10, 12, 15, 17, 19, 22, 24, 27, 29, 31, 34, 36, 39, 41, 43, 46, 48]
		sfx.play("pierce", pow(2.0, ladder[rung] / 12.0) * sfx.key_ratio, -3.0)
		add_hitstop(0.022)
		cam.add_trauma(0.07)
	else:
		hud.hit_confirm(false)
		sfx.play("hit", randf_range(0.95, 1.05), -6.0)
		add_hitstop(0.016)
		cam.add_trauma(0.04)


func screen_uv(p: Vector2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return (get_viewport().get_canvas_transform() * p) / vp


func on_target_die(p: Vector2, kind: int) -> void:
	kills += 1
	var big: bool = kind != Enemies.CHASER
	post.shock(screen_uv(p), 1.0 if big else 0.6, 1.6 if big else 1.3)
	post.pulse(0.003 if big else 0.0015)
	hud.kill_confirm(big)
	sfx.play("die", randf_range(0.92, 1.05) * (0.8 if big else 1.0), -2.0 if big else -5.0)
	add_hitstop(0.07 if big else 0.035)
	cam.add_trauma(0.34 if big else 0.16)
	cam.punch(0.025 if big else 0.01)
	fx.wave_push(p, 260.0, 120.0)
	_wave(p, 0.6 if big else 0.35)


# Returns true when the hit landed (not during invulnerability).
func on_player_hit(dir: Vector2, _e) -> bool:
	if tutorial != null:
		return false
	if possess.busy():
		# seized: the shell takes it (and costs no crack); in flight, nothing lands
		return possess.shell_hit(dir)
	if player.invuln > 0.0 or wave_ctl.phase != Waves.FIGHT or dev_god or lost:
		return false
	if has("lightstep") and player.dash_t > 0.0:
		return false
	if has("brace") and focusing:
		return false
	if has("grit"):
		grit_t = 3.0
	if armed.ward:
		armed.ward = false
		player.invuln = 0.8
		hud.flash_text(Cards.item_name("ward"))
		fx.ring(player.pos, 10.0, 90.0, 0.4, Pal.ink(1.0, 2.0), 3.0)
		sfx.play("shield", 1.2, -2.0)
		return false
	hits_taken += 1
	var damage := 1
	if Settings.assist:
		assist_damage += 1.0 - Settings.damage_reduction / 100.0
		damage = int(floor(assist_damage + 0.00001))
		assist_damage = maxf(0.0, assist_damage - damage)
	cracks -= damage
	if has("grit"):
		player.invuln = 2.0
	if cracks <= 0 and has("phoenix") and not phoenix_used:
		phoenix_used = true
		cracks = mini(max_cracks, 3)
		hud.crack_mend(cracks)
		hud.flash_text(Cards.relic_name("phoenix"))
		fx.ring(player.pos, 10.0, 320.0, 0.8, Pal.red(1.0, 2.6), 4.0)
		sfx.play("mend", 0.8, 0.0)
	if cracks <= 0 and has("undying") and not undying_used:
		undying_used = true
		cracks = 1
		hud.flash_text(Cards.relic_name("undying"))
		fx.ring(player.pos, 10.0, 200.0, 0.6, Pal.ink(1.0, 2.0), 3.0)
	if damage > 0:
		hud.crack_break(cracks)
	post.hurt(1.0)
	post.pulse(0.012)
	sfx.play("crack", 1.0, -1.0)
	player.hurt(dir)
	wave_ctl.add_penalty(5.0)
	hud.penalty(get_viewport().get_canvas_transform() * player.pos)
	add_hitstop(0.09)
	cam.add_trauma(0.55)
	cam.kick(dir, 6.0)
	cam.punch(0.035)
	sfx.play("hurt", 1.0, 0.0)
	fx.ring(player.pos, 14.0, 120.0, 0.45, Pal.ink(1.0, 1.6), 3.0)
	fx.sparks(player.pos, dir, 12, Pal.ink(1.0, 1.8), 600.0, 0.35, 1.4)
	fx.flash(player.pos, 70.0, 0.22, Pal.ink(0.4, 1.3))
	_wave(player.pos, 0.8)
	if cracks <= 0:
		_game_over()
	elif has("mirror_skin") and bullets.count_state(Bullets.EMBED) > 0:
		_release()
	return true


func _game_over() -> void:
	if Settings.assist and assist_retries_used < Settings.retry_limit and not assist_checkpoint.is_empty():
		assist_retries_used += 1
		var snap := assist_checkpoint.duplicate(true)
		snap.assist_retries_used = assist_retries_used
		snap.assist_restored = true
		Meta.resume = snap
		if bot == null and not dev and not Meta.test_mode and not Meta.dev_unlock:
			Meta.save_run(snap)
		paused = true
		Engine.time_scale = 1.0
		get_tree().call_deferred("reload_current_scene")
		return
	lost = true
	victory_slow = 1.0
	player.shatter()
	sfx.play("over", 1.0, 0.0)
	sfx.drop()
	cam.add_trauma(0.9)
	cam.punch(0.06)
	wave_ctl.phase = Waves.DONE
	hud.game_over()
	Meta.record_run(self, false)
	if bot == null:
		Meta.clear_run()
	_check_counts()


# Where you were `back` seconds ago (echoes walk it).
func trail_at(back: float) -> Vector2:
	var want := sim_time - back
	for i in range(trail.size() - 1, -1, -1):
		if trail[i][0] <= want:
			return trail[i][1]
	return trail[0][1] if not trail.is_empty() else player.pos


func take_encore() -> bool:
	if encore_ready:
		encore_ready = false
		hud.flash_text(Cards.relic_name("encore"))
		return true
	return false


var _last_beat := -1


# Beat Heart: every 8th beat the embedded rounds pulse.
func _beat_events() -> void:
	var bi := int(floor(sfx.beat()))
	if bi == _last_beat:
		return
	_last_beat = bi
	if has("beat_heart") and bi % 8 == 0 and wave_ctl.phase == Waves.FIGHT:
		for b in bullets.list:
			if b.state == Bullets.EMBED:
				fx.ring(b.pos, 4.0, 50.0, 0.3, Pal.red(0.8, 2.2), 1.5)
				for e in enemies.list:
					if e.state == Enemies.ALIVE and e.pos.distance_to(b.pos) < 50.0 + e.r:
						enemies.blast_hit(e, (e.pos - b.pos).normalized(), 8.0)


func on_pass_kill(at: Vector2) -> void:
	pass_kills += 1
	if has("aftershock"):
		fx.ring(at, 8.0, 80.0, 0.3, Pal.red(0.9, 2.2), 2.0)
		for e in enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(at) < 80.0 + e.r:
				enemies.aftershock_hit(e, (e.pos - at).normalized())


func orbit_time() -> float:
	return 2.0 if lv.orbit <= 1 else 4.0


# Does this round circle the player before it drops into the magazine?
func orbit_take(b) -> bool:
	if b.orbited or lv.orbit <= 0:
		return false
	var cap := 6 if lv.orbit == 1 else (12 if lv.orbit == 2 else 9999)
	if orbit_used >= cap:
		return false
	orbit_used += 1
	return true


func start_pick() -> void:
	offers = Cards.offer(self)
	if offers.is_empty():
		wave_ctl.pick_done()
		return
	picking = true
	hud.show_cards(offers)
	sfx.play("card", 1.0, -4.0)


func reroll() -> void:
	if not picking or rerolls <= 0 or hud.chosen >= 0:
		return
	rerolls -= 1
	rerolled = true
	offers = Cards.offer(self)
	hud.show_cards(offers)
	sfx.play("reroll", 1.0, -3.0)
	cam.punch(0.015)


func choose(i: int) -> void:
	if not picking or i < 0 or i >= offers.size():
		return
	var c: Dictionary = offers[i]
	picking = false
	pick_cd = 0.3
	hud.pick(i, c)
	sfx.play("pick", 1.0, -2.0)
	cam.punch(0.02)
	_wave(player.pos, 0.6)
	match c.type:
		"school":
			if c.get("full", false):
				_ask_replace(c)
				return
			lv[c.id] += 1
			_check_schools()
		"relic":
			if relics.size() >= Cards.RELIC_SLOTS:
				_ask_replace(c)
				return
			_gain_relic(c.id)
		"item":
			_use_item(c.id)
	wave_ctl.pick_done()


func _check_schools() -> void:
	var n := 0
	for k in lv:
		if lv[k] >= 3:
			n += 1
	if n >= 1:
		ach("school3")
	if n >= 2:
		ach("two_school3")


func _ask_replace(c: Dictionary) -> void:
	replacing = c
	hud.show_replace(c)


# j = slot to give up, -1 = keep what you have and drop the new card
func replace_slot(j: int) -> void:
	if replacing.is_empty():
		return
	var c := replacing
	if j >= 0:
		if c.type == "school":
			var held: Array = []
			for k in Cards.SCHOOLS:
				if lv[k] > 0:
					held.append(k)
			if j >= held.size():
				return
			lv[held[j]] = 0
			lv[c.id] = 1
		else:
			if j >= relics.size():
				return
			_lose_relic(relics[j])
			relics.remove_at(j)
			_gain_relic(c.id)
		sfx.play("pick", 0.9, -3.0)
	replacing = {}
	hud.replace_done()
	wave_ctl.pick_done()


func _gain_relic(id: String) -> void:
	relics.append(id)
	if relics.size() >= Cards.RELIC_SLOTS:
		ach("relics5")
	if id == "glass_cannon":
		max_cracks -= 1
		cracks = mini(cracks, max_cracks)
		hud.crack_break(max_cracks)
	if id == "lucky":
		rerolls += 1
	if id == "reserve":
		mag += 3
		ammo += 3
		hud.ammo_in()
	if id == "thick":
		max_cracks += 1
		cracks = mini(max_cracks, cracks + 1)
		hud.crack_mend(cracks)
	sfx.play("relic", 1.0, -3.0)
	if id == "deepmag":
		mag += 6
		ammo += 6
		hud.ammo_in()


func _lose_relic(id: String) -> void:
	if id == "glass_cannon":
		max_cracks += 1
	if id == "reserve":
		mag -= 3
		ammo = mini(ammo, mag)
	if id == "thick":
		max_cracks -= 1
		cracks = mini(cracks, max_cracks)
	if id == "deepmag":
		mag -= 6
		ammo = mini(ammo, mag)


func _use_item(id: String) -> void:
	match id:
		"patch":
			cracks = mini(max_cracks, cracks + 1)
			hud.crack_mend(cracks)
			sfx.play("mend", 1.0, -3.0)
		"spare":
			rerolls += 1
		"mend_all":
			cracks = mini(max_cracks, cracks + 2)
			hud.crack_mend(cracks)
			sfx.play("mend", 1.0, -3.0)
		"rewind":
			for b in bullets.list:
				if b.state == Bullets.EMBED:
					b.life = 0.0
		"recall_order":
			for b in bullets.list:
				if b.state == Bullets.CAPTURED and not b.child:
					bullets.send_home(b)
		_:
			armed[id] = true
	hud.flash_text(Cards.item_name(id))
	sfx.play("item", 1.0, -3.0)


# Called by the wave controller when a wave's fight begins.
func on_wave_start() -> void:
	_save_run()
	if assist_restored:
		assist_restored = false
		player.invuln = 2.0
		hud.flash_text(Txt.t("a_restored") % maxi(0, Settings.retry_limit - assist_retries_used))
	wave_half = armed.firststrike
	armed.firststrike = false
	wave_longhold = armed.longhold
	armed.longhold = false
	wave_drag = armed.slowfield
	armed.slowfield = false
	wave_tempo = armed.tempo
	armed.tempo = false
	wave_haste = armed.haste
	armed.haste = false
	wave_calm = armed.calm_mind
	armed.calm_mind = false
	encore_ready = has("encore")
	first_blood_ready = has("first_blood")
	spare_used = false
	if armed.stasis:
		armed.stasis = false
		stasis_t = 6.0


# Between chapters: rounds come home, the room and its boss change, the
# music changes key.
# The run as it stands when a wave begins: enough to start that wave again later.
func _save_run() -> void:
	if tutorial != null:
		return
	assist_checkpoint = run_snapshot()
	if bot != null or dev or Meta.dev_unlock or Meta.test_mode:
		return
	Meta.save_run(run_snapshot())


func run_snapshot() -> Dictionary:
	return {
		"assist_retries_used": assist_retries_used, "assist_damage": assist_damage,
		"plan": wave_ctl.plan.duplicate(true), "phoenix_used": phoenix_used,
		"undying_used": undying_used, "waves_cleared": waves_cleared,
		"v": 1, "chapter": chapter, "wave": wave_ctl.index, "gun": Loadout.gun, "stake": Loadout.stake,
		"cracks": cracks, "max_cracks": max_cracks, "relics": relics.duplicate(), "lv": lv.duplicate(),
		"armed": armed.duplicate(), "rerolls": rerolls, "run_time": run_time, "kills": kills,
		"hits_taken": hits_taken, "chapter_hits": chapter_hits, "max_combo": max_combo, "crosses": crosses,
		"crit_recalls": crit_recalls, "steals": steals, "run_ach": run_ach.duplicate(),
		"results": wave_ctl.results.duplicate(true), "chapter_log": wave_ctl.chapter_log.duplicate(true),
	}


func _resume(snap: Dictionary) -> void:
	for i in int(snap.get("chapter", 0)):
		next_chapter()
	assist_retries_used = int(snap.get("assist_retries_used", 0))
	assist_damage = float(snap.get("assist_damage", 0.0))
	assist_restored = bool(snap.get("assist_restored", false))
	phoenix_used = bool(snap.get("phoenix_used", false))
	undying_used = bool(snap.get("undying_used", false))
	waves_cleared = int(snap.get("waves_cleared", 0))
	if snap.has("plan"):
		wave_ctl.plan = snap.plan.duplicate(true)
	relics.clear()
	mag = Loadout.mag()
	for id in snap.get("relics", []):
		if Cards.RELICS.has(id):
			_gain_relic(id)
	var slv: Dictionary = snap.get("lv", {})
	for k in slv:
		lv[k] = int(slv[k])
	for k in snap.get("armed", {}):
		armed[k] = bool(snap.armed[k])
	max_cracks = int(snap.get("max_cracks", max_cracks))
	cracks = int(snap.get("cracks", cracks))
	rerolls = int(snap.get("rerolls", rerolls))
	run_time = float(snap.get("run_time", 0.0))
	kills = int(snap.get("kills", 0))
	hits_taken = int(snap.get("hits_taken", 0))
	chapter_hits = int(snap.get("chapter_hits", 0))
	max_combo = int(snap.get("max_combo", 0))
	crosses = int(snap.get("crosses", 0))
	crit_recalls = int(snap.get("crit_recalls", 0))
	steals = int(snap.get("steals", 0))
	run_ach = snap.get("run_ach", []).duplicate()
	ammo = mag
	wave_ctl.results = snap.get("results", []).duplicate(true)
	wave_ctl.chapter_log = snap.get("chapter_log", []).duplicate(true)
	var w := int(snap.get("wave", 0))
	if w > 0:
		# pick up as if the cards before this wave had just been chosen
		wave_ctl.index = w - 1
		wave_ctl.phase = Waves.CLEAR
		wave_ctl.pick_state = 2
		# the chapter's opening plays out first; the wave's title follows it
		wave_ctl.t = 0.0
		wave_ctl.pick_done_t = 2.2
	# "from the start of this wave" rides under that title, not over the opening
	resume_note = true


func next_chapter() -> void:
	chapter += 1
	ammo = mini(mag, ammo + bullets.clear_for_chapter())
	for e in enemies.list:
		e.state = Enemies.DEAD
	boss.reset()
	boss = bosses[mini(chapter, bosses.size() - 1)]
	boss.reset()
	arena.setup(chapter)
	sfx.start_chapter(chapter)
	sfx.play("chapter", 1.0, -2.0)
	hud.chapter_intro()
	wave_ctl.start_chapter(chapter)
	player.pos = Vector2(960, 860)
	player.vel = Vector2.ZERO


func on_chapter_clear() -> void:
	armed.ward = false
	if hits_taken == chapter_hits:
		ach("nohit_chapter")
	chapter_hits = hits_taken
	var all_s := true
	var sum := 0.0
	for r in wave_ctl.results:
		sum += r[0]
		if r[1] != "S":
			all_s = false
	if all_s and wave_ctl.results.size() >= Waves.COUNT:
		ach("all_s_chapter")
	if chapter == 0 and sum <= 150.0:
		ach("fast_ch1")
	ach("boss_%d" % (chapter + 1))
	if Loadout.at_least(7):
		rerolls = maxi(rerolls, 0 if Loadout.at_least(2) else 1) + (1 if has("lucky") else 0)
		undying_used = false
		return
	cracks = mini(max_cracks, cracks + 2)
	hud.crack_mend(cracks)
	sfx.play("mend", 0.9, -2.0)
	rerolls = maxi(rerolls, 0 if Loadout.at_least(2) else 1) + (1 if has("lucky") else 0)
	undying_used = false


func on_wave_title(index: int, note: String) -> void:
	if resume_note:
		resume_note = false
		note = "resumed"
	hud.wave_title(index, note)
	sfx.play("title", 1.0, -4.0)


func on_wave_clear(index: int, time: float, grade: String) -> void:
	waves_cleared += 1
	if has("second_wind") and waves_cleared % 3 == 0 and cracks < max_cracks:
		cracks += 1
		hud.crack_mend(cracks)
		sfx.play("mend", 1.1, -4.0)
	hud.stamp(index, time, grade)
	sfx.play("stamp", 1.0 if grade == "S" else 0.9, 0.0)
	cam.add_trauma(0.25)
	cam.punch(0.03)
	_wave(player.pos, 0.9)


func on_boss_dying() -> void:
	sfx.drop()
	add_hitstop(0.12)
	cam.add_trauma(0.5)
	cam.punch(0.05)


func on_boss_dead(at: Vector2) -> void:
	# the core implodes: everything left on the field goes with it
	victory_slow = 1.0
	for e in enemies.list:
		if e.state == Enemies.ALIVE:
			enemies._die(e, (e.pos - at).normalized())
		else:
			e.state = Enemies.DEAD
	fx.ring(at, 240.0, 6.0, 0.35, Pal.ink(0.9, 1.6), 3.0)
	fx.ring(at, 20.0, 1400.0, 1.4, Pal.ink(0.8, 1.5), 4.0)
	fx.ring(at, 10.0, 900.0, 1.0, Pal.red(0.8, 2.4), 2.5)
	fx.flash(at, 420.0, 0.6, Pal.ink(0.7, 1.6))
	fx.wave_push(at, 2000.0, 400.0)
	_wave(at, 1.4)
	sfx.play("boss_die", 1.0, 2.0)
	cam.add_trauma(1.0)
	cam.punch(0.08)


func on_run_done(results: Array) -> void:
	hud.final(results)
	sfx.play("title", 0.8, -2.0)
	Meta.record_run(self, true)
	if bot == null:
		Meta.clear_run()
	ach("win")
	if Loadout.at_least(3):
		ach("win_stake4")
	if Loadout.at_least(7):
		ach("win_stake8")
	if not rerolled:
		ach("no_reroll")
	if bot == null and Meta.load_data().gun_wins.size() >= 3:
		ach("guns3")
	_check_counts()


func _check_counts() -> void:
	var d := Meta.load_data()
	if int(d.kills) >= 300:
		ach("kills_300")
	if int(d.kills) >= 3000:
		ach("kills_3000")
	if int(d.runs) >= 10:
		ach("runs10")


func on_return_arrive(b) -> void:
	fx.ring(b.pos, 3.0, 16.0, 0.3, Pal.red(0.9, 2.4), 1.4)
	fx.flash(b.pos, 20.0, 0.15, Pal.red(0.6, 2.0))


func on_ammo_home(_b) -> void:
	possess.on_round_home()
	if tutorial != null and not _b.child:
		tutorial.returned = true
	if ammo >= mag:
		return
	if has("homing_spark"):
		var best = null
		var bd := 900.0
		for e in enemies.list:
			if e.state == Enemies.ALIVE and e.pos.distance_to(player.pos) < bd:
				bd = e.pos.distance_to(player.pos)
				best = e
		if best != null:
			bullets.twin(player.muzzle(), (best.pos - player.pos).normalized())
	player.pop_tick(ammo, true)
	ammo += 1
	home_streak += 1
	hud.ammo_in()
	sfx.play("home", minf(2.2, 0.9 + home_streak * 0.03), -9.0)
	fx.flash(player.pos, 34.0, 0.1, Pal.red(0.4, 1.8))
