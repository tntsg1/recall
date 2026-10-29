extends SceneTree
# Records 30 s of the bot playing chapter 1 room to room (the first room
# offers two ways on, so the choice and the slide are in it).
# -> proofs/rooms/rooms_play.mp4 (no sound: frames only)
# Usage: tools/run_test.sh tests/rooms_movie.gd --fixed-fps 60 -- [seconds]

const Rec = preload("res://tests/rec.gd")

var game
var rec
var brain
var frame := 0
var seconds := 30.0
var bot := {"move": Vector2.ZERO, "aim": Vector2(960, 300), "fire": false, "focus": false, "dash": false}


func _initialize() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seconds = float(args[0])
	Meta.test_mode = true
	Meta.next_seed = 424242
	seed(11)
	game = load("res://scenes/main.tscn").instantiate()
	game.bot = bot
	root.add_child(game)
	brain = preload("res://tests/brain.gd").new(bot)
	rec = Rec.new()
	root.add_child(rec)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		# the first room has two ways on
		if not game.rooms.forks.has(0):
			game.rooms.forks.append(0)
			game.rooms.build(0, "L", false)
			game.player.pos = game.rooms.start_pos()
		game.lore.worker_t = 0.0
	if frame == 3:
		rec.start("res://proofs/rooms/rooms_play.mp4", 60)
	brain.think(game)
	if frame > 3:
		rec.grab()
	if frame > 3 + int(seconds * 60.0) or game.lost:
		rec.finish()
		print("room ", game.rooms.room_index, " wave ", game.wave_ctl.index)
		return true
	return false
