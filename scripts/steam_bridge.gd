class_name SteamBridge
# Thin seam for Steam. Without the GodotSteam extension (the web build, tests,
# a copy run outside Steam) every call is a no-op and the game keeps its own
# achievements and save. With it, achievements are mirrored: on start every
# one already earned in the meta save is set again, so one earned while Steam
# was away still reaches it. The save itself goes to Steam Cloud by Auto-Cloud
# (recall_meta.json + .bak under the user folder); nothing here touches files.

const APP_ID := 4953700

static var _ready := false
static var _steam = null


static func init() -> void:
	if _ready:
		return
	_ready = true
	if OS.has_feature("web") or DisplayServer.get_name() == "headless" or Meta.under_test():
		return
	if "--no-steam" in OS.get_cmdline_user_args() or not Engine.has_singleton("Steam"):
		return
	var s = Engine.get_singleton("Steam")
	# (callbacks embedded: GodotSteam runs them each frame itself)
	var res: Dictionary = s.steamInitEx(APP_ID, true)
	if int(res.get("status", -1)) != 0:
		print("Steam not available: ", res.get("verbal", ""))
		return
	_steam = s
	_sync_all()


static func available() -> bool:
	init()
	return _steam != null


# Everything the meta save holds, set on Steam too.
static func _sync_all() -> void:
	var got: Dictionary = Meta.load_data().get("ach", {})
	var changed := false
	for id in got:
		if not Ach.LIST.has(id):
			continue
		var st: Dictionary = _steam.getAchievement(id)
		if st.get("ret", false) and not st.get("achieved", false):
			_steam.setAchievement(id)
			changed = true
	if changed:
		_steam.storeStats()


static func unlock(id: String) -> void:
	if not available():
		return
	_steam.setAchievement(id)
	_steam.storeStats()


static func tick() -> void:
	pass
