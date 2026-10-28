class_name Sfx
extends Node
# Procedural sounds (tools/make_audio.py) through a small voice pool, and the
# chapter's music as four synced loops (base / pulse / glass / boss) whose
# volumes follow the fight. The music muffles while you hold Q and drops back
# in on release.

const NAMES := ["shot", "embed", "hit", "pierce", "focus", "release", "home", "die", "spawn", "empty", "expire", "lit", "dash", "arrive", "hurt", "title", "stamp", "shield", "windup", "dash_e", "slam", "tick", "card", "pick", "split", "horn", "brake", "core", "armor", "boss_die", "crack", "mend", "reroll", "relic", "item", "over", "chapter", "cross", "crit", "p_possess", "p_grow", "p_drill", "p_finish", "p_blast", "p_slam", "p_well", "p_hit", "p_kill", "p_bounce", "p_ready"]
const VOICES := 18
const LAYERS := ["base", "pulse", "glass", "boss"]
const LAYER_DB := {"base": 0.0, "pulse": -2.0, "glass": -5.0, "boss": -2.0}

var game
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var next := 0
var layers := {}        # name -> AudioStreamPlayer
var level := {}         # name -> current linear volume
var lowpass: AudioEffectLowPassFilter
var music_bus := 0
var sfx_bus := 0
var duck := 0.0
var muffle := 0.0
var last_play := {}
var key_ratio := 440.0 / 660.0   # pierce sample (E5) to the chapter's root
const ROOTS := [440.0, 329.63, 293.66, 392.0, 261.63]
const BPMS := [90.0, 96.0, 84.0, 100.0, 92.0]
var music_t := 0.0
var chapter := 0


func _ready() -> void:
	music_bus = _bus("Music", -8.0)
	sfx_bus = _bus("SFX", -2.0)
	# The buses and the filter come from default_bus_layout.tres: the browser build
	# (sample playback) only routes buses that exist at startup, so nothing is added here.
	if AudioServer.get_bus_effect_count(music_bus) > 0 and AudioServer.get_bus_effect(music_bus, 0) is AudioEffectLowPassFilter:
		lowpass = AudioServer.get_bus_effect(music_bus, 0)
	else:
		lowpass = AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = 20000.0
		lowpass.resonance = 0.6
		AudioServer.add_bus_effect(music_bus, lowpass)
	for n in NAMES:
		var p := "res://assets/audio/%s.ogg" % n
		if ResourceLoader.exists(p):
			streams[n] = load(p)
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		voices.append(v)
	start_chapter(0)


# All four loops start in the same frame so they stay locked together.
func start_chapter(ch: int) -> void:
	chapter = ch
	music_t = 0.0
	key_ratio = ROOTS[mini(ch, ROOTS.size() - 1)] / 660.0
	for k in layers:
		layers[k].queue_free()
	layers.clear()
	for k in LAYERS:
		var p := "res://assets/audio/ch%d_%s.ogg" % [ch + 1, k]
		if not ResourceLoader.exists(p):
			continue
		var s: AudioStreamOggVorbis = load(p)
		s.loop = true
		var pl := AudioStreamPlayer.new()
		pl.bus = "Music"
		pl.stream = s
		pl.volume_db = -80.0
		add_child(pl)
		layers[k] = pl
		level[k] = 0.0
	for k in layers:
		layers[k].play()


func _bus(name: String, db: float) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, db)
	return i


func play(name: String, pitch: float = 1.0, db: float = 0.0) -> void:
	if not streams.has(name):
		return
	# the same sound twice within a frame or two only stacks noise
	var now := Time.get_ticks_msec()
	if last_play.get(name, -100) > now - 18 and name != "pierce" and name != "home":
		return
	last_play[name] = now
	var v := voices[next]
	next = (next + 1) % VOICES
	v.stream = streams[name]
	v.pitch_scale = pitch
	v.volume_db = db
	v.play()


# How loud each layer should be right now.
func _mood() -> Dictionary:
	var m := {"base": 1.0, "pulse": 0.0, "glass": 0.0, "boss": 0.0}
	if game == null:
		return m
	var w = game.wave_ctl
	if game.lost or w.phase == Waves.DONE:
		m.base = 0.6
		return m
	var boss_on: bool = game.boss.alive()
	if w.phase == Waves.FIGHT:
		m.pulse = 1.0
		var crowd := clampf(game.enemies.remaining() / 14.0, 0.0, 1.0)
		m.glass = clampf(0.25 + 0.6 * crowd + (0.5 if game.pass_active else 0.0), 0.0, 1.0)
	elif game.picking or not game.replacing.is_empty():
		m.glass = 0.4
	if boss_on:
		m.boss = 1.0
		m.glass = maxf(m.glass, 0.5)
	return m


func bpm() -> float:
	return BPMS[mini(chapter, BPMS.size() - 1)]


# Beats since the loops started; the loops began together, so this follows them.
func beat() -> float:
	return music_t * bpm() / 60.0


func beat_frac() -> float:
	return fmod(beat(), 1.0)


func step(dt: float, focus: float) -> void:
	music_t += dt
	muffle = Pal.damp(muffle, focus, 10.0, dt)
	lowpass.cutoff_hz = lerpf(20000.0, 380.0, Pal.ease_out(muffle))
	duck = maxf(0.0, duck - dt / 0.5)
	AudioServer.set_bus_volume_db(music_bus, -8.0 - 22.0 * Pal.ease_in(duck) - 4.0 * muffle)
	var m := _mood()
	for k in layers:
		var want: float = m.get(k, 0.0)
		# layers come in over a bar or so, and leave a little faster
		level[k] = Pal.damp(level[k], want, 1.2 if want > level[k] else 1.8, dt)
		layers[k].volume_db = linear_to_db(maxf(level[k], 0.0001)) + LAYER_DB[k]


func drop() -> void:
	duck = 1.0
