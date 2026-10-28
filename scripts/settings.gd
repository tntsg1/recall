class_name Settings
# Player options in user://recall_settings.cfg: volumes, screen shake, softer
# flashes, fullscreen, language, and key bindings. Tests never save them.

const PATH := "user://recall_settings.cfg"


# Under a test script the settings live in a sandbox file (see Meta.path).
static func _path() -> String:
	return "user://recall_settings.test.cfg" if Meta.under_test() else PATH
const ACTIONS := ["up", "down", "left", "right", "recall", "dash", "pause"]

static var master := 1.0
static var music := 0.8
static var sfx := 1.0
static var shake := true
static var soft := false
static var fullscreen := false
static var lang := ""          # "" follows the system
static var keys := {}          # action -> physical keycode
static var loaded := false
static var assist := false
static var damage_reduction := 20
static var retry_limit := 3


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var cf := ConfigFile.new()
	if cf.load(_path()) != OK:
		return
	master = cf.get_value("audio", "master", master)
	music = cf.get_value("audio", "music", music)
	sfx = cf.get_value("audio", "sfx", sfx)
	shake = cf.get_value("video", "shake", shake)
	soft = cf.get_value("video", "soft", soft)
	fullscreen = cf.get_value("video", "fullscreen", fullscreen)
	lang = cf.get_value("game", "lang", lang)
	keys = cf.get_value("input", "keys", {})
	assist = bool(cf.get_value("assist", "enabled", false))
	damage_reduction = clampi(int(cf.get_value("assist", "damage_reduction", 20)), 0, 80)
	retry_limit = clampi(int(cf.get_value("assist", "retries", 3)), 0, 5)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "sfx", sfx)
	cf.set_value("video", "shake", shake)
	cf.set_value("video", "soft", soft)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("game", "lang", lang)
	cf.set_value("input", "keys", keys)
	cf.set_value("assist", "enabled", assist)
	cf.set_value("assist", "damage_reduction", damage_reduction)
	cf.set_value("assist", "retries", retry_limit)
	cf.save(_path())


# Volumes, window mode, language and rebinds take effect here.
static func apply(tree: SceneTree) -> void:
	_vol("Master", master)
	_vol("Music", music, -8.0)
	_vol("SFX", sfx, -2.0)
	if lang != "":
		Txt.zh = lang == "zh"
	var w := tree.root.get_window()
	var want := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if w.mode != want and not (want == Window.MODE_WINDOWED and w.mode == Window.MODE_MAXIMIZED):
		w.mode = want
	for a in keys:
		if InputMap.has_action(a):
			for ev in InputMap.action_get_events(a):
				if ev is InputEventKey:
					InputMap.action_erase_event(a, ev)
			var k := InputEventKey.new()
			k.physical_keycode = keys[a]
			InputMap.action_add_event(a, k)


static func _vol(bus: String, v: float, base: float = 0.0) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	if bus == "Master":
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	else:
		AudioServer.set_bus_volume_db(i, base + linear_to_db(maxf(v, 0.0001)))


static func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
	return "-"
