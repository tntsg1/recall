extends Control
# Title: scattered rounds fly back to spell RECALL, then the menu — start,
# magazine, stake, achievements, settings, quit. Every piece moves on springs
# (Motion): the highlight slides between rows, pages slide and cascade in and
# out, values roll, toggles and sliders spring, the cursor reshapes over what
# it can press. Start stretches the chosen row into a line of light that wipes
# into the run. Keyboard, mouse and gamepad (ui_* actions) all work.

const LETTERS := {
	"R": [[Vector2(0, 7), Vector2(0, 0), Vector2(3, 0), Vector2(4, 1), Vector2(4, 3), Vector2(3, 4), Vector2(0, 4)], [Vector2(2, 4), Vector2(4, 7)]],
	"E": [[Vector2(4, 0), Vector2(0, 0), Vector2(0, 7), Vector2(4, 7)], [Vector2(0, 3.5), Vector2(3, 3.5)]],
	"C": [[Vector2(4, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 6), Vector2(1, 7), Vector2(4, 7)]],
	"A": [[Vector2(0, 7), Vector2(2, 0), Vector2(4, 7)], [Vector2(1, 4.5), Vector2(3, 4.5)]],
	"L": [[Vector2(0, 0), Vector2(0, 7), Vector2(4, 7)]],
	"N": [[Vector2(0, 7), Vector2(0, 0), Vector2(4, 7), Vector2(4, 0)]],
	"O": [[Vector2(1, 0), Vector2(3, 0), Vector2(4, 1), Vector2(4, 6), Vector2(3, 7), Vector2(1, 7), Vector2(0, 6), Vector2(0, 1), Vector2(1, 0)]],
	"I": [[Vector2(1, 0), Vector2(3, 0)], [Vector2(2, 0), Vector2(2, 7)], [Vector2(1, 7), Vector2(3, 7)]],
	"D": [[Vector2(0, 0), Vector2(0, 7), Vector2(3, 7), Vector2(4, 6), Vector2(4, 1), Vector2(3, 0), Vector2(0, 0)]],
	" ": [],
}
const UNIT := 22.0
const MENU := ["start", "trial", "tutorial", "gun", "stake", "achievements", "archive", "settings", "quit"]
const SETTINGS := ["master", "music", "sfx", "shake", "soft", "fullscreen", "lang", "keys", "assist", "back"]
const ROW_H := 58.0
const ROW_W := 520.0
const PAGE_T := 0.42

var t := 0.0
var rounds: Array = []
var strokes: Array = []
var page := "menu"
var assist_panel: AssistPanel
var prev_page := ""
var page_t := 9.0               # time since the page changed
var sel := {"menu": 0, "settings": 0, "keys": 0}
var waiting_key := ""
var guns: Array = []
var gun_i := 0
var hover := -1
var font_l: Font
var font_s: Font
var font_b: Font
var font_xl: Font
var glint := 0.0
var glint_stroke := 0
var sfx: Sfx
# motion
var hl := Motion.Spring2.new(Vector2.ZERO, 420.0, 0.78)   # highlight centre
var hl_w := Motion.Spring.new(0.0, 380.0, 0.8)            # highlight width
var row_k: Array = []      # per row: Spring (0..1 how "lifted" it is)
var press: Array = []      # per row: Spring for a press squash
var cur_r := Motion.Spring.new(5.0, 520.0, 0.6)           # cursor ring radius
var cur_p := Motion.Spring2.new(Vector2(960, 540), 1400.0, 0.9)
var knobs := {}            # settings toggles: Spring 0..1
var bars := {}             # settings volumes: Spring
var val_old := ""
var val_dir := 0
var val_t := 9.0
var val_row := ""
var start_t := -1.0
var dragging := ""
var count_roll := Motion.Roller.new(0.0, 6.0)
var menu_in := 0.0
var leaving := false
var bg: ColorRect
var dot_tex: Texture2D


func _ready() -> void:
	Meta.test_mode = false
	Meta.possess_trial = false
	if not OS.has_feature("web"):
		get_window().title = "霓虹行者 NEON RAID"
	Settings.load_all()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_l = Fonts.get_font("Light")
	font_s = Fonts.get_font("Regular")
	font_b = Fonts.get_font("SemiBold")
	font_xl = Fonts.get_font("Medium")
	guns = Loadout.GUNS.keys()
	gun_i = maxi(0, guns.find(Loadout.gun))
	sfx = Sfx.new()
	add_child(sfx)
	sfx.start_chapter(0)
	Settings.apply(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	for i in 12:
		row_k.append(Motion.Spring.new(0.0, 320.0, 0.7))
		press.append(Motion.Spring.new(0.0, 600.0, 0.45))
	for k in ["shake", "soft", "fullscreen"]:
		knobs[k] = Motion.Spring.new(1.0 if _flag(k) else 0.0, 420.0, 0.62)
	for k in ["master", "music", "sfx"]:
		bars[k] = Motion.Spring.new(_vol(k), 300.0, 0.7)
	count_roll.set_to(float(Meta.load_data().ach.size()))
	_build_word()
	_ensure_ui_keys()
	# the dot field lives on the GPU; rounds are one batched texture
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/title_bg.gdshader")
	if Pal.ldr:
		mat.set_shader_parameter("gamma", 1.0)
	bg.material = mat
	add_child(bg)
	dot_tex = _make_dot()
	# load the run in the background so Start never stalls
	ResourceLoader.load_threaded_request("res://scenes/main.tscn")
	add_child(Warm.new())
	var env := WorldEnvironment.new()
	env.environment = Game.make_environment()
	env.environment.glow_intensity = 0.0001
	add_child(env)
	hl.snap(_row_rect(0).get_center())
	hl_w.snap(ROW_W)


static func _make_dot() -> Texture2D:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length()
			var a := clampf(n / 2.0 - 0.5 - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _dot(p: Vector2, r: float, c: Color) -> void:
	draw_texture_rect(dot_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


func _ensure_ui_keys() -> void:
	var extra := {"ui_up": [KEY_W], "ui_down": [KEY_S], "ui_left": [KEY_A], "ui_right": [KEY_D], "ui_cancel": [KEY_ESCAPE]}
	for a in extra:
		for k in extra[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			if not InputMap.action_has_event(a, ev):
				InputMap.action_add_event(a, ev)


func _build_word() -> void:
	var word := "NEON RAID"
	var width := (word.length() * 6 - 2) * UNIT
	var origin := Vector2(960 - width / 2.0, 190)
	var i := 0
	for ch in word:
		for line in LETTERS[ch]:
			var pts := PackedVector2Array()
			for p in line:
				pts.append(origin + Vector2(i * 6 * UNIT, 0) + (p as Vector2) * UNIT)
			strokes.append(pts)
			for k in pts.size() - 1:
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[k + 1]
				var n := maxi(1, int(a.distance_to(b) / (UNIT * 0.6)))
				for j in n:
					var to := a.lerp(b, float(j) / n)
					var from := to + Vector2.from_angle(randf() * TAU) * randf_range(900, 1400)
					rounds.append([from, to, randf_range(0.2, 1.4)])
		i += 1


# ---------------------------------------------------------------- layout

func _vp() -> Vector2:
	return get_viewport_rect().size


# "Continue" leads the menu while a run is waiting (it may arrive from the cloud).
func _menu() -> Array:
	return (["continue"] + MENU) if Meta.run_saved() != null else MENU


func _rows() -> Array:
	match page:
		"menu":
			return _menu()
		"settings":
			return SETTINGS
		"keys":
			return Settings.ACTIONS
	return []


func _row_top() -> float:
	return _vp().y * (_menu_top() if page == "menu" else 0.40)

func _menu_top() -> float:
	return 0.46 if _menu().size() >= 8 else 0.52


func _row_rect(i: int, pg: String = "") -> Rect2:
	var vp := _vp()
	var on := pg if pg != "" else page
	var top := vp.y * (_menu_top() if on == "menu" else 0.40)
	# a long menu (Continue on top) packs its rows a little closer
	var step := 52.0 if on == "menu" and _menu().size() >= 10 else ROW_H
	return Rect2(vp.x / 2.0 - ROW_W / 2.0, top + i * step, ROW_W, step - 10.0)


func _bar_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(r.end.x - 240.0, r.position.y + 20.0, 170.0, 8.0)


func _flag(k: String) -> bool:
	match k:
		"shake":
			return Settings.shake
		"soft":
			return Settings.soft
		"fullscreen":
			return Settings.fullscreen
	return false


func _vol(k: String) -> float:
	match k:
		"master":
			return Settings.master
		"music":
			return Settings.music
	return Settings.sfx


# ---------------------------------------------------------------- update

func _process(dt: float) -> void:
	Meta.poll_cloud()
	t += dt
	page_t += dt
	val_t += dt
	glint += dt
	if glint > 3.5:
		glint = 0.0
		glint_stroke = randi() % strokes.size()
	menu_in = clampf((t - 2.6) / 0.8, 0.0, 1.0)
	var m := get_local_mouse_position()
	cur_p.target = m
	cur_p.step(dt)
	hover = -1
	if start_t < 0.0 and page_t > PAGE_T * 0.6 and menu_in >= 1.0:
		var rows := _rows()
		for i in rows.size():
			if _row_rect(i).has_point(m):
				hover = i
	if dragging != "":
		var idx := SETTINGS.find(dragging)
		var br := _bar_rect(idx)
		_set_vol(dragging, clampf((m.x - br.position.x) / br.size.x, 0.0, 1.0))
	# springs
	var rows2 := _rows()
	var cur: int = sel.get(page, 0)
	for i in row_k.size():
		row_k[i].target = 1.0 if (i == cur and i < rows2.size()) else (0.4 if i == hover else 0.0)
		row_k[i].step(dt)
		press[i].step(dt)
	if rows2.size() > 0:
		var r := _row_rect(cur)
		hl.target = r.get_center()
		hl_w.target = ROW_W
	hl.step(dt)
	hl_w.step(dt)
	cur_r.target = 22.0 if hover >= 0 else 5.0
	cur_r.step(dt)
	for k in knobs:
		knobs[k].target = 1.0 if _flag(k) else 0.0
		knobs[k].step(dt)
	for k in bars:
		bars[k].target = _vol(k)
		bars[k].step(dt)
	count_roll.step(dt)
	if start_t >= 0.0:
		start_t += dt
		if start_t > 1.05 and not leaving and (Warm.done or start_t > 2.5):
			leaving = true
			var packed = ResourceLoader.load_threaded_get("res://scenes/main.tscn")
			if packed is PackedScene:
				get_tree().change_scene_to_packed(packed)
			else:
				get_tree().change_scene_to_file("res://scenes/main.tscn")
	sfx.step(dt, 0.0)
	queue_redraw()


func _go(to: String) -> void:
	prev_page = page
	page = to
	page_t = 0.0
	hover = -1
	var r := _row_rect(sel.get(to, 0))
	hl.snap(r.get_center() + Vector2(120, 0))
	hl_w.snap(0.0)
	sfx.play("card", 1.2, -8.0)


var dev_panel: DevPanel


func _open_dev_panel() -> void:
	dev_panel = DevPanel.new().setup(self, [
		{"kind": "head", "text": Txt.t("devx_h_title")},
		{"kind": "toggle", "label": Txt.t("devx_unlock"), "id": "unlock", "get": func(): return Meta.dev_unlock},
		{"kind": "stat", "get": func(): return Txt.t("devx_unlock_note")},
		{"kind": "btns", "items": [{"label": Txt.t("dev_off"), "id": "close"}]},
	])
	add_child(dev_panel)


func dev_action(id: String, _arg) -> void:
	match id:
		"unlock":
			Meta.dev_unlock = not Meta.dev_unlock
			sfx.play("tick", 1.4 if Meta.dev_unlock else 0.8, -4.0)
		"close":
			Meta.dev_unlock = false
			if is_instance_valid(dev_panel):
				dev_panel.close()
				dev_panel = null
			sfx.play("tick", 0.8, -4.0)


func _input(ev: InputEvent) -> void:
	if is_instance_valid(assist_panel):
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_QUOTELEFT:
		if Meta.dev_auth or Meta.dev_unlock:
			if is_instance_valid(dev_panel):
				dev_panel.close()
				dev_panel = null
			else:
				_open_dev_panel()
			sfx.play("tick", 1.0, -6.0)
		elif not has_node("DevPrompt"):
			# ~ asks for the code first; 111 opens developer mode for this session
			var dp := DevPrompt.new()
			dp.name = "DevPrompt"
			dp.unlocked.connect(func():
				Meta.dev_auth = true
				Meta.dev_unlock = true
				sfx.play("tick", 1.4, -4.0)
				_open_dev_panel())
			add_child(dp)
			sfx.play("tick", 1.1, -6.0)
		get_viewport().set_input_as_handled()
		return
	if start_t >= 0.0 or menu_in < 1.0:
		return
	if waiting_key != "":
		if ev is InputEventKey and ev.pressed:
			if ev.physical_keycode != KEY_ESCAPE:
				Settings.keys[waiting_key] = ev.physical_keycode
				Settings.save()
				Settings.apply(get_tree())
			waiting_key = ""
			_tick(1.3)
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if not ev.pressed:
			if dragging != "":
				dragging = ""
				Settings.save()
			return
		if page == "achievements" or page == "archive":
			_go("menu")
			return
		if hover >= 0:
			sel[page] = hover
			if page == "settings" and bars.has(SETTINGS[hover]) and _bar_rect(hover).grow(10).has_point(get_local_mouse_position()):
				dragging = SETTINGS[hover]
				return
			_press(hover)
			_accept(1)
		return
	if ev.is_action_pressed("ui_cancel"):
		if page != "menu":
			_go("settings" if page == "keys" else "menu")
	elif ev.is_action_pressed("ui_up"):
		_move(-1)
	elif ev.is_action_pressed("ui_down"):
		_move(1)
	elif ev.is_action_pressed("ui_left"):
		_side(-1)
	elif ev.is_action_pressed("ui_right"):
		_side(1)
	elif ev.is_action_pressed("ui_accept"):
		_press(sel.get(page, 0))
		_accept(0)


func _move(d: int) -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	sel[page] = posmod(sel.get(page, 0) + d, rows.size())
	_tick(1.0 + 0.03 * sel[page])


func _tick(p: float = 1.2) -> void:
	sfx.play("tick", p, -7.0)


func _press(i: int) -> void:
	if i >= 0 and i < press.size():
		press[i].kick(-9.0)


func _side(d: int) -> void:
	if page == "menu":
		var key: String = _menu()[sel.menu]
		if key == "gun" or key == "stake":
			_change_value(key, d)
	elif page == "settings":
		_set_change(d)


func _accept(d: int) -> void:
	match page:
		"menu":
			match _menu()[sel.menu]:
				"continue":
					Meta.training_requested = 0
					var snap = Meta.run_saved()
					if snap == null:
						return
					Loadout.gun = str(snap.gun)
					Loadout.stake = int(snap.stake)
					Meta.resume = snap
					start_t = 0.0
					sfx.play("release", 1.0, -2.0)
				"start":
					if not Meta.gun_open(guns[gun_i]) or not Meta.stake_open(Loadout.stake):
						sfx.play("empty", 1.0, -4.0)
						press[0].kick(14.0)
						return
					Loadout.gun = guns[gun_i]
					Meta.training_requested = 1 if Meta.needs_tutorial() else 0
					Meta.clear_run()
					start_t = 0.0
					sfx.play("release", 1.0, -2.0)
				"trial":
					# 夺壳试玩: an endless room of chasers and leeches, nothing saved
					Meta.resume = null
					Meta.training_requested = 0
					Meta.possess_trial = true
					start_t = 0.0
					sfx.play("release", 1.0, -2.0)
				"tutorial":
					Meta.resume = null
					Meta.training_requested = 2
					start_t = 0.0
					sfx.play("release", 1.0, -2.0)
				"gun", "stake":
					_change_value(_menu()[sel.menu], 1)
				"achievements":
					_go("achievements")
				"archive":
					_go("archive")
				"settings":
					_go("settings")
				"quit":
					Meta.leave(get_tree())
		"settings":
			_set_change(1 if d >= 0 else -1)
		"keys":
			waiting_key = Settings.ACTIONS[sel["keys"]]
			_tick(0.8)


func _change_value(key: String, d: int) -> void:
	val_old = _value_text(key)
	val_dir = d
	val_t = 0.0
	val_row = key
	if key == "gun":
		gun_i = posmod(gun_i + d, guns.size())
	else:
		Loadout.stake = posmod(Loadout.stake + d, Loadout.STAKES.size())
	_tick(1.1 + 0.05 * d)


func _value_text(key: String) -> String:
	if key == "gun":
		var gid: String = guns[gun_i]
		return Loadout.gun_name(gid) + ("" if Meta.gun_open(gid) else "  ·  " + Txt.t("t_locked"))
	return "%d · %s" % [Loadout.stake + 1, Loadout.stake_name(Loadout.stake)] + ("" if Meta.stake_open(Loadout.stake) else "  ·  " + Txt.t("t_locked"))


func _set_vol(k: String, v: float) -> void:
	match k:
		"master":
			Settings.master = v
		"music":
			Settings.music = v
		"sfx":
			Settings.sfx = v
	Settings.apply(get_tree())


func _set_change(d: int) -> void:
	var key: String = SETTINGS[sel.settings]
	match key:
		"master", "music", "sfx":
			_set_vol(key, clampf(snappedf(_vol(key) + 0.1 * d, 0.1), 0.0, 1.0))
		"shake":
			Settings.shake = not Settings.shake
		"soft":
			Settings.soft = not Settings.soft
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
		"lang":
			val_old = "中文" if Txt.zh else "English"
			val_dir = d
			val_t = 0.0
			val_row = "lang"
			Settings.lang = "en" if Txt.zh else "zh"
		"keys":
			_go("keys")
			return
		"assist":
			assist_panel = AssistPanel.new()
			add_child(assist_panel)
			return
		"back":
			_go("menu")
			return
	Settings.save()
	Settings.apply(get_tree())
	_tick(1.0 + 0.1 * d)


# ---------------------------------------------------------------- drawing

func _text_c(font: Font, txt: String, center: Vector2, size: int, c: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(center.x - w / 2.0, center.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


# How present page `pg` is right now (0..1), and its slide offset.
# The old page leaves first and fast; the new one comes in only once it has
# mostly gone, so the two never sit on top of each other.
func _page_k(pg: String, i: int) -> Vector2:
	var k_in := Pal.ease_out(Motion.stagger(page_t - PAGE_T * 0.4, i, 0.035, PAGE_T * 0.7))
	var k_out := 1.0 - Pal.ease_in(Motion.stagger(page_t, i, 0.006, PAGE_T * 0.32))
	if pg == page:
		return Vector2(k_in, (1.0 - k_in) * 60.0)
	if pg == prev_page:
		return Vector2(k_out, -(1.0 - k_out) * 60.0)
	return Vector2(0, 0)


func _draw() -> void:
	var vp := _vp()
	var bm := bg.material as ShaderMaterial
	bm.set_shader_parameter("cursor", cur_p.x)
	bm.set_shader_parameter("size", vp)
	_draw_word(vp)
	var dim_word := 0.0
	for pg in ["achievements", "archive", "settings", "keys"]:
		dim_word = maxf(dim_word, _page_k(pg, 0).x)
	if dim_word > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.022, 0.93 * dim_word))
	for pg in [prev_page, page]:
		if pg == "":
			continue
		match pg:
			"menu":
				_draw_menu(vp)
			"achievements":
				_draw_ach(vp)
			"archive":
				_draw_archive(vp)
			"settings":
				_draw_settings(vp)
			"keys":
				_draw_keys(vp)
	if Meta.dev_unlock and Meta.test_mode == false and OS.get_cmdline_user_args().is_empty():
		var db := Txt.t("dev_title")
		draw_string(font_b, Vector2(28, 44), db, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.red(1.0, 1.6))
	_draw_start(vp)
	_draw_cursor()


func _draw_word(vp: Vector2) -> void:
	var cur: Vector2 = cur_p.x
	# the word sits a touch off the cursor, as if it floated above the grid
	var par := ((cur - vp / 2.0) * -0.012).limit_length(6.0)
	var cyc := fmod(maxf(0.0, t - 3.4), 6.5)
	var sweep := lerpf(500.0, 1420.0, Pal.ease_io(clampf(cyc / 1.8, 0.0, 1.0)))
	var sweep_a := sin(clampf(cyc / 1.8, 0.0, 1.0) * PI) if t > 3.4 else 0.0
	for r in rounds:
		var k := clampf((t - r[2]) / 0.9, 0.0, 1.0)
		if k <= 0.0:
			continue
		var e := Pal.ease_io(k)
		var to: Vector2 = r[1]
		var p: Vector2 = (r[0] as Vector2).lerp(to, e) + par
		if k < 1.0:
			var back := (r[0] as Vector2).lerp(to, maxf(0.0, e - 0.12)) + par
			draw_line(back, p, Pal.red(0.6, 2.0), 1.5)
			_dot(p, 2.6, Pal.red(1.0, 2.6))
		else:
			var settle := clampf((t - r[2] - 0.9) / 0.3, 0.0, 1.0)
			# each landed round gives a small bounce
			var bob := sin(clampf((t - r[2] - 0.9) / 0.25, 0.0, 1.0) * PI) * 3.0
			var q := to + par + Vector2(0, -bob)
			# the cursor nudges the rounds aside as it passes over the word
			var dv := q - cur
			var dd := dv.length_squared()
			if dd < 4900.0 and dd > 0.01:
				q += dv / sqrt(dd) * (1.0 - dd / 4900.0) * 9.0
			# a slow band of light runs across the word
			var lit := exp(-pow((to.x - sweep) / 46.0, 2.0)) * sweep_a
			_dot(q, 2.8 + 0.6 * lit, Pal.ink(minf(1.0, 0.5 + 0.5 * settle + 0.4 * lit), 1.0 + 0.6 * (1.0 - settle) + 1.6 * lit))
	var whole := clampf((t - 2.4) / 0.6, 0.0, 1.0)
	if whole > 0.0:
		draw_set_transform(par, 0.0, Vector2.ONE)
		for s in strokes:
			draw_polyline(s, Pal.ink(0.35 * whole, 1.2), 2.0, false)
		var g := clampf(glint / 0.8, 0.0, 1.0)
		if g < 1.0 and strokes.size() > 0:
			var st: PackedVector2Array = strokes[glint_stroke]
			var total := 0.0
			for i in st.size() - 1:
				total += st[i].distance_to(st[i + 1])
			var at := total * (1.0 - Pal.ease_io(g))
			var acc := 0.0
			for i in st.size() - 1:
				var l := st[i].distance_to(st[i + 1])
				if acc + l >= at:
					var p2 := st[i].lerp(st[i + 1], (at - acc) / l)
					draw_circle(p2, 5.0, Pal.red(1.0, 3.0))
					break
				acc += l
	_text_c(font_s, "霓虹行者", Vector2(vp.x / 2.0, 395), 22, Pal.ink(0.55 * whole))
	# where and when: the world in one line, lit a beat after the word
	var era := clampf((t - 3.0) / 0.8, 0.0, 1.0)
	if era > 0.0:
		_text_c(font_s, Txt.t("t_era"), Vector2(vp.x / 2.0, 428), 14, Pal.ink(0.35 * era * whole))


# The highlight: a soft band that springs between rows, a red underline that
# stretches from the centre, and a small bracket that leads it.
func _draw_highlight(a: float) -> void:
	var w: float = hl_w.x
	if w < 2.0 or a <= 0.0:
		return
	var c: Vector2 = hl.x
	var r := Rect2(c - Vector2(w / 2.0, 24.0), Vector2(w, 48.0))
	Pal.band(self, r, 0.022 * a)
	var stretch := clampf(absf(hl.v.y) / 1200.0, 0.0, 0.5)
	var uw := w * (1.0 - stretch * 0.6)
	draw_line(Vector2(c.x - uw / 2.0, r.end.y), Vector2(c.x + uw / 2.0, r.end.y), Pal.red(0.85 * a, 2.0), 2.0)
	draw_line(Vector2(r.position.x - 10.0, r.position.y + 8.0), Vector2(r.position.x - 10.0, r.end.y - 8.0), Pal.red(a, 2.2), 2.0)


func _row(i: int, pg: String, label: String, value: String, a: float, dx: float, locked: bool = false, value_key: String = "") -> void:
	var r := _row_rect(i, pg)
	var lift: float = row_k[i].x if pg == page else 0.0
	var pr: float = press[i].x if pg == page else 0.0
	var sc := 1.0 + 0.025 * lift + pr * 0.01
	var c := Pal.ink((0.55 + 0.4 * lift) * a * (0.5 if locked else 1.0))
	# the chosen row swells in place: it stays on the menu's centre line
	draw_set_transform(r.get_center() + Vector2(dx, 0), 0.0, Vector2(sc, sc))
	var lr := Rect2(-r.size / 2.0, r.size)
	if value == "":
		_text_c(font_xl, label, Vector2(0, 9), 24, c)
	else:
		draw_string(font_s, lr.position + Vector2(20, 31), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink((0.45 + 0.2 * lift) * a))
		var vx := lr.end.x - 24.0
		if value_key != "" and value_key == val_row and val_t < 0.3:
			# the old value slides out, the new one in
			var k := Pal.ease_out(val_t / 0.3)
			var vw0 := font_b.get_string_size(val_old, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(font_b, Vector2(vx - vw0 - 30.0 * k * val_dir, lr.position.y + 31), val_old, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.ink((1.0 - k) * 0.9 * a))
			var vw1 := font_b.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(font_b, Vector2(vx - vw1 + 30.0 * (1.0 - k) * val_dir, lr.position.y + 31), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(c.r, c.g, c.b, c.a * k))
		else:
			var vw := font_b.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(font_b, Vector2(vx - vw, lr.position.y + 31), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, c)
			if lift > 0.5 and value_key != "":
				var nudge := sin(t * 5.0) * 2.0
				draw_string(font_b, Vector2(vx - vw - 26.0 - nudge, lr.position.y + 31), "◂", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.5 * a * lift))
				draw_string(font_b, Vector2(vx + 8.0 + nudge, lr.position.y + 31), "▸", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.ink(0.5 * a * lift))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_menu(vp: Vector2) -> void:
	var gid: String = guns[gun_i]
	var gun_ok := Meta.gun_open(gid)
	var stake_ok := Meta.stake_open(Loadout.stake)
	if page == "menu":
		_draw_highlight(menu_in * _page_k("menu", 0).x)
	var menu := _menu()
	for i in menu.size():
		var key: String = menu[i]
		var pk := _page_k("menu", i)
		# the first entrance cascades in after the word forms
		var ent := Pal.ease_out(Motion.stagger(t - 2.6, i, 0.06, 0.5))
		var a := pk.x * ent
		if a <= 0.01:
			continue
		var dx := pk.y + (1.0 - ent) * 40.0
		match key:
			"continue":
				var snap = Meta.run_saved()
				var sch := int(snap.chapter)
				if int(snap.get("v", 1)) < 2:
					sch = Chapters.OLD_RUN[clampi(sch, 0, Chapters.OLD_RUN.size() - 1)]
				var where := Chapters.label(sch) + " · " + Txt.t("wave") % (int(snap.wave) + 1)
				_row(i, "menu", Txt.t("t_continue") + "  ·  " + where, "", a, dx)
			"start":
				_row(i, "menu", Txt.t("t_start") if Meta.run_saved() == null else Txt.t("t_new_run"), "", a, dx, not (gun_ok and stake_ok))
			"gun":
				_row(i, "menu", Txt.t("t_gun"), _value_text("gun"), a, dx, not gun_ok, "gun")
			"stake":
				_row(i, "menu", Txt.t("t_stake"), _value_text("stake"), a, dx, not stake_ok, "stake")
			_:
				_row(i, "menu", Txt.t("t_" + key), "", a, dx)
	var pa := _page_k("menu", 0).x * menu_in
	var info := ""
	var mk: String = _menu()[sel.menu]
	if mk == "gun":
		info = Loadout.gun_desc(gid) if gun_ok else Txt.t("t_unlock") + " · " + _unlock_text(Loadout.GUNS[gid][4])
	elif mk == "stake":
		var lines: Array = []
		for k in range(1, Loadout.stake + 1):
			lines.append(Loadout.stake_desc(k))
		info = ("  ·  ".join(lines) if not lines.is_empty() else Loadout.stake_desc(0)) if stake_ok else Txt.t("t_stake_lock")
	if info != "":
		_text_c(font_s, info, Vector2(vp.x / 2.0, _row_rect(_menu().size(), "menu").position.y + 24), 16, Pal.ink(0.6 * pa))
	var d := Meta.load_data()
	var rec := Txt.t("t_records") % [int(d.runs), int(d.wins), int(round(count_roll.shown)), Ach.LIST.size()]
	_text_c(font_s, rec, Vector2(vp.x / 2.0, vp.y - 40.0), 15, Pal.ink(0.45 * pa))


func _unlock_text(key: String) -> String:
	if Ach.LIST.has(key):
		return Ach.desc_of(key)
	return key


# The archive: every fragment of the world found so far, chapter by chapter,
# in three columns by where it came from. What is still out there shows as a
# blacked-out line of the same length, like a censored file.
const ARCHIVE_COLS := [["w", "arch_walls"], ["s", "arch_seize"], ["r", "arch_radio"]]
var _arch_wrap := {}


func _arch_lines(txt: String, width: float, size: int) -> Array:
	var key := "%d|%d|%s" % [size, int(width), txt]
	if _arch_wrap.has(key):
		return _arch_wrap[key]
	var out: Array = []
	var cur := ""
	for ch in txt:
		if font_s.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			out.append(cur)
			cur = ch.strip_edges(true, false)
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	_arch_wrap[key] = out
	return out


func _draw_archive(vp: Vector2) -> void:
	var pk := _page_k("archive", 0)
	if pk.x <= 0.01:
		return
	var total := 0
	var have := 0
	var chapters: Array = []
	for i in Chapters.count():
		var items := Lore.all_of(Chapters.story(i))
		if items.is_empty():
			continue
		chapters.append([i, items])
		for it in items:
			total += 1
			if Lore.found(it[0]):
				have += 1
	# a dark sheet over the word behind
	draw_rect(Rect2(0.0, 80.0, vp.x, vp.y - 140.0), Color(0.02, 0.02, 0.022, 0.96 * pk.x))
	_text_c(font_xl, Txt.t("t_archive") + "  %d / %d" % [have, total], Vector2(vp.x / 2.0, 130 + pk.y * 0.5), 34, Pal.ink(pk.x))
	_text_c(font_s, Txt.t("archive_hint"), Vector2(vp.x / 2.0, 166 + pk.y * 0.5), 15, Pal.ink(0.5 * pk.x))
	var colw := 400.0
	var gap := 44.0
	var x0 := vp.x / 2.0 - (colw * 3.0 + gap * 2.0) / 2.0
	var y := 236.0
	var row := 0
	for ch in chapters:
		var kc := _page_k("archive", row)
		row += 1
		view_label(Chapters.label(ch[0]) + "  ·  " + Chapters.title(ch[0]), Vector2(x0 + kc.y, y), 20, Pal.ink(0.95 * kc.x), font_b)
		draw_line(Vector2(x0, y + 12.0), Vector2(x0 + (colw * 3.0 + gap * 2.0) * kc.x, y + 12.0), Pal.ink(0.25 * kc.x), 1.0)
		y += 52.0
		var tallest := 0.0
		for c in ARCHIVE_COLS.size():
			var src: String = ARCHIVE_COLS[c][0]
			var cx := x0 + c * (colw + gap)
			var items: Array = []
			var got_n := 0
			for it in ch[1]:
				if String(it[0]).begins_with(src):
					items.append(it)
					if Lore.found(it[0]):
						got_n += 1
			var kh := _page_k("archive", row + c)
			_arch_icon(src, Vector2(cx + 8.0, y - 6.0), Pal.ink(0.7 * kh.x))
			view_label(Txt.t(ARCHIVE_COLS[c][1]) + "   %d / %d" % [got_n, items.size()], Vector2(cx + 26.0 + kh.y, y), 15, Pal.ink(0.6 * kh.x), font_b)
			var yy := y + 30.0
			for it in items:
				var kj := _page_k("archive", row + c + 1)
				var got := Lore.found(it[0])
				var lines := _arch_lines(String(it[1]), colw - 20.0, 16)
				var top_y := yy - 15.0
				for ln in lines:
					if got:
						var col := Possess.cyan(0.9 * kj.x, 1.3) if src == "s" else Pal.ink(0.85 * kj.x)
						view_label(ln, Vector2(cx + 12.0 + kj.y, yy), 16, col, font_s)
					else:
						# blacked out: a bar as long as the words it hides
						var lw := font_s.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
						draw_rect(Rect2(cx + 12.0 + kj.y, yy - 13.0, lw, 15.0), Pal.ink(0.13 * kj.x))
					yy += 24.0
				draw_line(Vector2(cx + 4.0, top_y), Vector2(cx + 4.0, yy - 20.0), Possess.cyan(0.6 * kj.x) if (got and src == "s") else Pal.ink((0.5 if got else 0.15) * kj.x), 2.0)
				yy += 12.0
			tallest = maxf(tallest, yy - y)
		row += 4
		y += tallest + 26.0
	_text_c(font_s, Txt.t("t_back"), Vector2(vp.x / 2.0, vp.y - 40), 15, Pal.ink(0.5 * pk.x))


func _arch_icon(src: String, c: Vector2, col: Color) -> void:
	match src:
		"w":
			# a wall with a mark on it
			draw_rect(Rect2(c + Vector2(-7, -7), Vector2(14, 14)), col, false, 1.5)
			draw_line(c + Vector2(-4, 3), c + Vector2(4, -3), col, 1.5)
		"s":
			# the seize corners
			for k in 4:
				var d := Vector2.from_angle(PI / 4.0 + TAU * k / 4.0)
				var p := c + d * 8.0
				draw_line(p, p + Vector2(-signf(d.x) * 5.0, 0), Possess.cyan(col.a, 1.6), 2.0)
				draw_line(p, p + Vector2(0, -signf(d.y) * 5.0), Possess.cyan(col.a, 1.6), 2.0)
		_:
			# a loudspeaker
			draw_rect(Rect2(c + Vector2(-8, -4), Vector2(5, 8)), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -4), c + Vector2(5, -9), c + Vector2(5, 9), c + Vector2(-3, 4)]), col)


func view_label(txt: String, at: Vector2, size: int, c: Color, f: Font) -> void:
	draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _draw_ach(vp: Vector2) -> void:
	var pk := _page_k("achievements", 0)
	if pk.x <= 0.01:
		return
	var d := Meta.load_data()
	_text_c(font_xl, Txt.t("t_achievements") + "  %d / %d" % [d.ach.size(), Ach.LIST.size()], Vector2(vp.x / 2.0, 120 + pk.y * 0.5), 34, Pal.ink(pk.x))
	var ids: Array = Ach.LIST.keys()
	var cols := 3
	var cw := 520.0
	var x0 := vp.x / 2.0 - cw * cols / 2.0
	for i in ids.size():
		var id: String = ids[i]
		var got: bool = d.ach.has(id)
		# each cell flips in, in reading order
		var ki := _page_k("achievements", i)
		var flip: float = Motion.out_back(ki.x, 1.6) if prev_page != "achievements" or page == "achievements" else ki.x
		if ki.x <= 0.01:
			continue
		var cell := Rect2(Vector2(x0 + (i % cols) * cw + 12.0, 154.0 + (i / cols) * 76.0), Vector2(cw - 24, 64))
		var cc := cell.get_center()
		draw_set_transform(cc, 0.0, Vector2(1.0, maxf(0.02, flip)))
		var lr := Rect2(-cell.size / 2.0, cell.size)
		if got:
			draw_rect(lr, Pal.ink(0.035 * ki.x))
			# a sheen sweeps across the ones you have
			var sw := fmod(t * 0.35 + i * 0.07, 1.6)
			if sw < 1.0:
				var sx := lerpf(lr.position.x, lr.end.x, sw)
				draw_line(Vector2(sx, lr.position.y), Vector2(sx - 30.0, lr.end.y), Pal.ink(0.12 * ki.x, 1.5), 6.0)
		draw_rect(lr, Pal.ink((0.35 if got else 0.12) * ki.x), false, 1.0)
		draw_string(font_b, lr.position + Vector2(12, 26), Ach.name_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink((0.95 if got else 0.35) * ki.x))
		draw_string(font_s, lr.position + Vector2(12, 50), Ach.desc_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.ink((0.6 if got else 0.3) * ki.x))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text_c(font_s, Txt.t("t_back"), Vector2(vp.x / 2.0, vp.y - 40), 15, Pal.ink(0.5 * pk.x))


func _draw_settings(vp: Vector2) -> void:
	var pk := _page_k("settings", 0)
	if pk.x <= 0.01:
		return
	_text_c(font_xl, Txt.t("t_settings"), Vector2(vp.x / 2.0, 330 + pk.y * 0.5), 34, Pal.ink(pk.x))
	if page == "settings":
		_draw_highlight(pk.x)
	for i in SETTINGS.size():
		var key: String = SETTINGS[i]
		var ki := _page_k("settings", i)
		if ki.x <= 0.01:
			continue
		match key:
			"master", "music", "sfx":
				_row(i, "settings", Txt.t("s_" + key), " ", ki.x, ki.y)
				_draw_bar(i, key, ki)
			"shake", "soft", "fullscreen":
				_row(i, "settings", Txt.t("s_" + key), " ", ki.x, ki.y)
				_draw_toggle(i, key, ki)
			"lang":
				_row(i, "settings", Txt.t("s_lang"), "中文" if Txt.zh else "English", ki.x, ki.y, false, "lang")
			"keys":
				_row(i, "settings", Txt.t("s_keys"), "▸", ki.x, ki.y)
			"assist":
				_row(i, "settings", Txt.t("s_assist"), "▸", ki.x, ki.y)
			"back":
				_row(i, "settings", Txt.t("t_back_short"), "", ki.x, ki.y)
	_text_c(font_s, Txt.t("t_pad"), Vector2(vp.x / 2.0, vp.y - 40), 14, Pal.ink(0.45 * pk.x))


func _draw_bar(i: int, key: String, ki: Vector2) -> void:
	var br := _bar_rect(i)
	br.position.x += ki.y
	var v: float = clampf(bars[key].x, 0.0, 1.05)
	draw_rect(br, Pal.ink(0.12 * ki.x))
	draw_rect(Rect2(br.position, Vector2(br.size.x * minf(v, 1.0), br.size.y)), Pal.ink(0.85 * ki.x, 1.1))
	var knob := Vector2(br.position.x + br.size.x * minf(v, 1.0), br.get_center().y)
	draw_circle(knob, 7.0 + (2.0 if dragging == key else 0.0), Pal.ink(ki.x, 1.3))
	var pct := "%d%%" % int(round(_vol(key) * 100))
	draw_string(font_b, Vector2(br.end.x + 14.0, br.position.y + 11.0), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.ink(0.8 * ki.x))


func _draw_toggle(i: int, key: String, ki: Vector2) -> void:
	var r := _row_rect(i)
	var track := Rect2(r.end.x - 90.0 + ki.y, r.position.y + 14.0, 56.0, 20.0)
	var k: float = knobs[key].x
	draw_rect(track, Pal.ink((0.12 + 0.2 * clampf(k, 0.0, 1.0)) * ki.x))
	draw_rect(track, Pal.ink(0.4 * ki.x), false, 1.0)
	var kx := lerpf(track.position.x + 10.0, track.end.x - 10.0, k)
	# the knob stretches a little while it travels
	var stretch := clampf(absf(knobs[key].v) / 30.0, 0.0, 0.6)
	draw_set_transform(Vector2(kx, track.get_center().y), 0.0, Vector2(1.0 + stretch, 1.0 - stretch * 0.3))
	draw_circle(Vector2.ZERO, 8.0, Pal.ink(ki.x, 1.0 + 0.5 * clampf(k, 0.0, 1.0)).lerp(Pal.red(ki.x, 2.0), clampf(k, 0.0, 1.0) * 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_keys(vp: Vector2) -> void:
	var pk := _page_k("keys", 0)
	if pk.x <= 0.01:
		return
	_text_c(font_xl, Txt.t("s_keys"), Vector2(vp.x / 2.0, 330 + pk.y * 0.5), 34, Pal.ink(pk.x))
	if page == "keys":
		_draw_highlight(pk.x)
	for i in Settings.ACTIONS.size():
		var act: String = Settings.ACTIONS[i]
		var ki := _page_k("keys", i)
		var val := Settings.key_name(act)
		if waiting_key == act:
			val = "· · ·".substr(0, 1 + int(t * 6.0) % 5)
		_row(i, "keys", Txt.t("k_" + act), val, ki.x, ki.y)
	_text_c(font_s, Txt.t("t_keys_hint"), Vector2(vp.x / 2.0, vp.y - 40), 14, Pal.ink(0.45 * pk.x))


# Start: the chosen row draws into a line of light, which opens the run.
func _draw_start(vp: Vector2) -> void:
	if start_t < 0.0:
		return
	var r := _row_rect(0, "menu")
	var k1 := Pal.ease_in(clampf(start_t / 0.35, 0.0, 1.0))
	var k2 := Pal.ease_io(clampf((start_t - 0.3) / 0.45, 0.0, 1.0))
	var cy := lerpf(r.get_center().y, vp.y / 2.0, k2)
	var half_w := lerpf(ROW_W / 2.0, vp.x * 0.6, k2)
	var th := lerpf(48.0 * (1.0 - k1) + 2.0, 2.0, k1)
	draw_rect(Rect2(Vector2(0, 0), vp), Color(0.0, 0.0, 0.0, 0.85 * k2))
	draw_rect(Rect2(Vector2(vp.x / 2.0 - half_w, cy - th / 2.0), Vector2(half_w * 2.0, th)), Pal.red(1.0, 2.6))
	var shut := Pal.ease_in(clampf((start_t - 0.75) / 0.3, 0.0, 1.0))
	if shut > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, shut))


func _draw_cursor() -> void:
	var p: Vector2 = cur_p.x
	var r: float = cur_r.x
	draw_circle(p, 2.5, Pal.ink(0.95, 1.3))
	if r > 6.0:
		# over something pressable the cursor opens into brackets
		var k := clampf((r - 5.0) / 17.0, 0.0, 1.0)
		for s in 4:
			var a := PI / 4.0 + TAU * s / 4.0 + t * 0.8
			draw_arc(p, r, a - 0.35, a + 0.35, 6, Pal.ink(0.8 * k, 1.2), 1.5, false)
	else:
		draw_arc(p, 9.0, 0.0, TAU, 20, Pal.ink(0.35), 1.0, false)
