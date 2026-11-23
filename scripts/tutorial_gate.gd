class_name TutorialGate
extends Node2D
# Uses the real player, recorded bullet paths, return damage and dash.
enum { MOVE, SHOOT, HOLD, RETURN, DASH, POSSESS, COMPLETE }
const STEPS := 7
const DEMO := Vector2(300, 140)     # the looping demo of each step, right of its text
const GOAL := Vector2(1260, 800)
var game
var entry := 1
var stage := MOVE
var age := 0.0
var return_hit := false
var returned := false
var dashed := false
var leaving := false
var old_gun := "standard"
var old_stake := 0
var dummy
var marked_round
var retry_note := false
var hold_started := false
var host_dummy                  # the possession step: the one to mark and seize
var targets: Array = []          # ...and the ones to break with it

func configure(owner_game, mode: int) -> void:
	game = owner_game
	entry = mode
	old_gun = Loadout.gun
	old_stake = Loadout.stake
	Loadout.gun = "standard"
	Loadout.stake = 0
	Meta.training_active = true

func _ready() -> void:
	z_index = 3
	z_as_relative = false
	game.arena.inner.clear()
	game.arena.mirrors.clear()
	game.arena.rects.resize(4)
	game.arena.mirror_from = 4
	game.arena.queue_redraw()
	game.wave_ctl.phase = Waves.FIGHT
	game.wave_ctl.index = 0
	game.player.position = game.player.pos
	game.hud.intro_t = -1.0
	game.hud.hint_a = 0.0

func _exit_tree() -> void:
	Loadout.gun = old_gun
	Loadout.stake = old_stake
	Meta.training_active = false

func advance(next: int) -> void:
	stage = next
	age = 0.0
	game.sfx.play("mend", 1.0 + stage * 0.04, -8.0)
	if stage == SHOOT:
		game.bullets.clear_for_chapter()
		game.ammo = game.mag
		game.regen.clear()
		if dummy != null:
			dummy.state = Enemies.DEAD
		return_hit = false
		returned = false
		marked_round = null
	if stage == DASH:
		game.bullets.clear_for_chapter()
		game.ammo = game.mag
		game.player.dash_cd = 0.0
		dashed = false
	if stage == HOLD:
		hold_started = false
	if stage == POSSESS:
		game.bullets.clear_for_chapter()
		game.ammo = game.mag
		game.possess.cooldown = 0.0
		host_dummy = _dummy(Enemies.CHASER, GOAL + Vector2(260, -330), 400.0)
		targets.clear()
		for k in 4:
			targets.append(_dummy(Enemies.CHASER, GOAL + Vector2(-220, -300) + Vector2.from_angle(TAU * k / 4.0) * 80.0, 60.0))
	if stage == COMPLETE:
		if game.possess.hosting():
			game.possess.end(false, true)
		Meta.finish_tutorial(true)
	queue_redraw()

func step(dt: float) -> void:
	if leaving:
		return
	age += dt
	# Practice rounds never expire while the player reads the instructions.
	for b in game.bullets.list:
		if b.state == Bullets.EMBED:
			b.life = 0.0
	match stage:
		MOVE:
			if game.player.pos.distance_to(GOAL) < 55.0:
				advance(SHOOT)
		SHOOT:
			for b in game.bullets.list:
				if b.state == Bullets.EMBED:
					marked_round = b
					dummy = game.enemies.spawn(Enemies.CHASER, b.sample(b.total() * 0.55), 0.0)
					dummy.state = Enemies.ALIVE
					dummy.hp = 20.0
					dummy.maxhp = 20.0
					dummy.speed = 0.0
					advance(HOLD)
					break
		HOLD:
			if game.focusing:
				hold_started = true
			if game.focusing and game.focus_time >= 0.35:
				advance(RETURN)
			elif (hold_started and not game.focusing) or (game.bullets.count_state(Bullets.EMBED) == 0 and not game.bullets.recall_active()):
				retry_note = true
				advance(SHOOT)
		RETURN:
			if return_hit and returned:
				advance(DASH)
			elif not game.focusing and game.bullets.count_state(Bullets.EMBED) == 0 and not game.bullets.recall_active() and game.bullets.count_state(Bullets.HOME) == 0:
				retry_note = true
				advance(SHOOT)
		DASH:
			if dashed and game.player.dash_t <= 0.0:
				advance(POSSESS)
		POSSESS:
			var broken := 0
			for d in targets:
				if d.state == Enemies.DEAD or d.hp < d.maxhp:
					broken += 1
			if game.possess.hosting() and broken >= 2:
				advance(COMPLETE)
			elif host_dummy != null and host_dummy.state == Enemies.DEAD and not game.possess.busy():
				host_dummy = _dummy(Enemies.CHASER, GOAL + Vector2(260, -330), 400.0)
	queue_redraw()

func _dummy(kind: int, at: Vector2, hp: float):
	var d = game.enemies.spawn(kind, at, 0.0)
	d.state = Enemies.ALIVE
	d.hp = hp
	d.maxhp = hp
	d.speed = 0.0
	return d


func skip_rect(vp: Vector2) -> Rect2:
	# in the top band, right-aligned to the arena's edge, clear of its frame
	return Rect2(vp.x - Hud.BAND_EDGE - 20 - 290, 14, 290, 40)

func done_rect(vp: Vector2) -> Rect2:
	return Rect2(vp.x / 2.0 - 280, 340, 560, 64)

func handle_input(event: InputEvent) -> bool:
	if leaving:
		return true
	if stage == COMPLETE and event.is_action_pressed("ui_accept"):
		finish(true)
		return true
	if event.is_action_pressed("ui_focus_next") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
		finish(stage == COMPLETE)
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = game.get_viewport_rect().size
		var mouse: Vector2 = game.hud.reticle
		if skip_rect(vp).has_point(mouse) or (stage == COMPLETE and done_rect(vp).has_point(mouse)):
			finish(stage == COMPLETE)
			return true
	return false

func finish(completed: bool) -> void:
	if leaving:
		return
	leaving = true
	Meta.finish_tutorial(completed)
	game.paused = true
	Engine.time_scale = 1.0
	# A replay never clears an existing formal run. First-time training leads on.
	game.hud.close_to(func():
		if entry == 1:
			game.get_tree().call_deferred("reload_current_scene")
		else:
			game.get_tree().call_deferred("change_scene_to_file", "res://scenes/title.tscn"))

func instructions() -> String:
	var binds := {
		"move": "%s / %s / %s / %s" % [Settings.key_name("up"), Settings.key_name("left"), Settings.key_name("down"), Settings.key_name("right")],
		"recall": Settings.key_name("recall"), "dash": Settings.key_name("dash"), "possess": "E"}
	return Txt.t("teach_%d_body" % stage).format(binds)

var para: TextParagraph
var para_text := ""


func draw_hud(hud, vp: Vector2) -> void:
	var v: CanvasItem = hud.view
	var width := minf(1100, vp.x - 100)
	var x := (vp.x - width) / 2.0
	# shaped once per text, not every frame
	var txt := instructions()
	# (the text keeps to the left; the step's little demo runs on the right)
	var demo_w := DEMO.x + 30.0 if stage != COMPLETE else 0.0
	if para == null or para_text != txt or para.width != width - 60 - demo_w:
		para = TextParagraph.new()
		para.width = width - 60 - demo_w
		para.add_string(txt, hud.font_s, 22)
		para_text = txt
	var paragraph: TextParagraph = para
	# the panel is as tall as what it says
	var ph := maxf(74.0 + paragraph.get_size().y + 32.0, DEMO.y + 24.0 if stage != COMPLETE else 0.0)
	v.draw_rect(Rect2(x, 104, width, ph), Color(0.035, 0.035, 0.04, 1.0))
	v.draw_line(Vector2(x, 104), Vector2(x + width * (stage + 1.0) / STEPS, 104), Pal.red(0.9, 1.5), 3.0)
	v.draw_string(hud.font_s, Vector2(Hud.BAND_EDGE + 20, 41), Txt.t("t_tutorial") + "  %d / %d" % [stage + 1, STEPS], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink(0.7))
	hud._text_c(hud.font_s, Txt.t("teach_skip"), skip_rect(vp).get_center() + Vector2(0, 7), 18, Pal.ink(0.7))
	v.draw_string(hud.font_xl, Vector2(x + 30, 153), Txt.t("teach_%d_title" % stage), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.ink(1.0))
	paragraph.draw(v.get_canvas_item(), Vector2(x + 30, 178), Pal.ink(0.8))
	if stage != COMPLETE:
		_draw_demo(hud, Rect2(Vector2(x + width - DEMO.x - 12.0, 116.0), DEMO))
	if stage == HOLD:
		var progress: float = clampf(game.focus_time / 0.35, 0.0, 1.0) if game.focusing else 0.0
		v.draw_rect(Rect2(x + 30, 104 + ph - 20, (width - 60) * progress, 4), Pal.red(1.0))
	if retry_note and stage == SHOOT:
		hud._text_c(hud.font_s, Txt.t("teach_retry"), Vector2(vp.x / 2.0, 350), 18, Pal.ink(0.65))
	if stage == COMPLETE:
		var r := done_rect(vp)
		v.draw_rect(r, Color(0.12, 0.12, 0.14, 0.95))
		v.draw_line(r.position, Vector2(r.end.x, r.position.y), Pal.red(0.9), 2.0)
		hud._text_c(hud.font_b, Txt.t("teach_start" if entry == 1 else "teach_back"), r.get_center() + Vector2(0, 8), 24, Pal.ink(1.0))

func _draw() -> void:
	if stage == MOVE:
		draw_arc(GOAL, 45.0 + sin(age * 4.0) * 4.0, 0, TAU, 48, Pal.red(0.9, 1.5), 2.5, true)
		draw_line(GOAL - Vector2(16, 0), GOAL + Vector2(16, 0), Pal.ink(0.6), 1.5)
		draw_line(GOAL - Vector2(0, 16), GOAL + Vector2(0, 16), Pal.ink(0.6), 1.5)
	elif stage == SHOOT:
		var p := Vector2(Arena.ROOM.end.x - 5.0, clampf(game.player.pos.y, 390, 910))
		draw_line(p - Vector2(0, 55), p + Vector2(0, 55), Pal.red(0.9, 2.0), 5.0)
		draw_line(game.player.pos + Vector2(45, 0), p - Vector2(20, 0), Pal.ink(0.18), 1.0)
	elif stage == POSSESS:
		if host_dummy != null and host_dummy.state == Enemies.ALIVE and not game.possess.busy():
			draw_arc(host_dummy.pos, 34.0 + sin(age * 4.0) * 3.0, 0, TAU, 40, Possess.cyan(0.8, 1.6), 1.5, true)
		for d in targets:
			if d.state == Enemies.ALIVE:
				draw_arc(d.pos, 26.0, 0, TAU, 32, Pal.foe(0.5), 1.0, true)
	elif stage in [HOLD, RETURN] and marked_round != null:
		draw_circle(marked_round.path[0], 9.0, Pal.ink(0.35))
		if dummy != null and dummy.state == Enemies.ALIVE:
			draw_arc(dummy.pos, 34.0, 0, TAU, 40, Pal.red(0.65), 1.5, true)


# A small looping demo of the step: a ghost of you doing it once, over and over.
func _draw_demo(hud, r: Rect2) -> void:
	var v: CanvasItem = hud.view
	v.draw_rect(r, Color(0.0, 0.0, 0.0, 0.55))
	v.draw_rect(r, Pal.ink(0.25), false, 1.0)
	var period := 3.2
	var t := fmod(game.real_time, period) / period          # 0..1 through one loop
	var fade := clampf(t / 0.08, 0.0, 1.0) * clampf((1.0 - t) / 0.08, 0.0, 1.0)
	var o := r.position
	var ghost := Pal.you(0.55 * fade, 1.3)
	var line_c := Pal.red(0.85 * fade, 1.5)
	var ink := Pal.ink(0.6 * fade)
	var wall_x := o.x + r.size.x - 34.0
	var me := Vector2(o.x + 46.0, o.y + r.size.y * 0.55)
	var hit := Vector2(wall_x, o.y + r.size.y * 0.35)
	var tgt := me.lerp(hit, 0.55)
	match stage:
		MOVE:
			var goal := Vector2(o.x + r.size.x - 60.0, o.y + r.size.y * 0.5)
			v.draw_arc(goal, 18.0, 0.0, TAU, 32, Pal.red(0.9 * fade, 1.5), 2.0, true)
			var k := Pal.ease_io(clampf((t - 0.1) / 0.6, 0.0, 1.0))
			v.draw_circle(Vector2(o.x + 46.0, goal.y).lerp(goal, k), 8.0, ghost)
		SHOOT:
			v.draw_line(Vector2(wall_x + 6.0, o.y + 12.0), Vector2(wall_x + 6.0, o.y + r.size.y - 12.0), Pal.red(0.8 * fade, 1.4), 4.0)
			v.draw_circle(me, 8.0, ghost)
			var k2 := clampf((t - 0.15) / 0.25, 0.0, 1.0)
			v.draw_circle(me.lerp(hit, k2), 3.5, Pal.ink(0.95 * fade, 1.4))
			if k2 >= 1.0:
				v.draw_line(hit + Vector2(-8, 0), hit, Pal.ink(0.95 * fade, 1.4), 2.5)
		HOLD, RETURN:
			v.draw_line(Vector2(wall_x + 6.0, o.y + 12.0), Vector2(wall_x + 6.0, o.y + r.size.y - 12.0), Pal.ink(0.35 * fade), 3.0)
			v.draw_circle(me, 8.0, ghost)
			var lit := clampf((t - 0.1) / 0.35, 0.0, 1.0)
			if stage == HOLD:
				# the way back draws itself, the target stands on it
				v.draw_line(hit, hit.lerp(me, lit), line_c, 2.0)
				v.draw_rect(Rect2(tgt - Vector2(7, 7), Vector2(14, 14)), Pal.ink(0.9 * fade), false, 2.0)
				_key_chip(hud, Vector2(o.x + 14.0, o.y + 14.0), Settings.key_name("recall"), lit > 0.0)
			else:
				var k3 := clampf((t - 0.2) / 0.35, 0.0, 1.0)
				v.draw_line(hit.lerp(me, k3), me, line_c, 2.0)
				var b := hit.lerp(me, k3)
				if k3 < 1.0:
					v.draw_circle(b, 3.5, Pal.red(fade, 2.0))
				if k3 < 0.45:
					v.draw_rect(Rect2(tgt - Vector2(7, 7), Vector2(14, 14)), Pal.ink(0.9 * fade), false, 2.0)
				else:
					for j in 5:
						var a := j * TAU / 5.0
						v.draw_line(tgt + Vector2.from_angle(a) * 6.0, tgt + Vector2.from_angle(a) * (10.0 + 14.0 * (k3 - 0.45)), Pal.ink(0.8 * fade), 2.0)
				_key_chip(hud, Vector2(o.x + 14.0, o.y + 14.0), Settings.key_name("recall"), false)
		DASH:
			var k4 := Pal.ease_io(clampf((t - 0.3) / 0.25, 0.0, 1.0))
			var from := Vector2(o.x + 40.0, o.y + r.size.y * 0.5)
			var to := Vector2(o.x + r.size.x - 40.0, from.y)
			var foe := Vector2(o.x + r.size.x * 0.6 - 40.0 * clampf(t / 0.5, 0.0, 1.0), from.y)
			v.draw_colored_polygon(PackedVector2Array([foe + Vector2(-10, 0), foe + Vector2(8, -9), foe + Vector2(8, 9)]), Pal.ink(0.45 * fade))
			var at := from.lerp(to, k4)
			if k4 > 0.0 and k4 < 1.0:
				v.draw_line(from.lerp(to, maxf(0.0, k4 - 0.35)), at, Pal.you(0.8 * fade, 2.0), 6.0)
			v.draw_circle(at, 8.0, ghost)
			_key_chip(hud, Vector2(o.x + 14.0, o.y + 14.0), Settings.key_name("dash"), k4 > 0.0 and k4 < 1.0)
		POSSESS:
			v.draw_line(Vector2(wall_x + 6.0, o.y + 12.0), Vector2(wall_x + 6.0, o.y + r.size.y - 12.0), Pal.ink(0.35 * fade), 3.0)
			var cy := Possess.cyan(0.9 * fade, 1.6)
			var shot := clampf((t - 0.05) / 0.18, 0.0, 1.0)
			var back := clampf((t - 0.35) / 0.2, 0.0, 1.0)
			var jump := clampf((t - 0.7) / 0.15, 0.0, 1.0)
			if back < 1.0:
				v.draw_circle(me.lerp(hit, shot).lerp(me, back), 3.5, Pal.ink(0.95 * fade, 1.4) if back == 0.0 else Pal.red(fade, 2.0))
			v.draw_arc(tgt, 13.0, 0.0, TAU, 28, cy if back > 0.6 else Possess.cyan(0.35 * fade, 1.2), 2.0, true)
			v.draw_rect(Rect2(tgt - Vector2(7, 7), Vector2(14, 14)), cy if jump >= 1.0 else Pal.ink(0.9 * fade), false, 2.0)
			if jump < 1.0:
				v.draw_circle(me.lerp(tgt, Pal.ease_io(jump)), 8.0, ghost)
			_key_chip(hud, Vector2(o.x + 14.0, o.y + 14.0), "E", jump > 0.0 and jump < 1.0)


func _key_chip(hud, at: Vector2, key: String, on: bool) -> void:
	var v: CanvasItem = hud.view
	var w: float = hud.font_b.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0
	v.draw_rect(Rect2(at, Vector2(w, 22)), Pal.red(0.9, 1.6) if on else Color(0.1, 0.1, 0.12, 0.9))
	v.draw_rect(Rect2(at, Vector2(w, 22)), Pal.ink(0.6), false, 1.0)
	v.draw_string(hud.font_b, at + Vector2(7, 16), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink(1.0))
