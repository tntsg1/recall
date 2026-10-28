class_name SteamBridge
# Thin seam for Steam. Without the GodotSteam module every call is a no-op and
# the game keeps its own achievements and save; with it, achievements and
# stats are mirrored. Nothing else in the game talks to Steam directly.

static var _ready := false
static var _steam = null


static func init() -> void:
	if _ready:
		return
	_ready = true
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		if _steam.has_method("steamInit"):
			_steam.steamInit()


static func available() -> bool:
	init()
	return _steam != null


static func unlock(id: String) -> void:
	if not available():
		return
	if _steam.has_method("setAchievement"):
		_steam.setAchievement(id)
	if _steam.has_method("storeStats"):
		_steam.storeStats()


static func tick() -> void:
	if available() and _steam.has_method("run_callbacks"):
		_steam.run_callbacks()
