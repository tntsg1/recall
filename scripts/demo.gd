class_name Demo
# The Steam demo (export feature "demo", or --demo on the command line): the
# tutorial and the first three chapters, a save of its own that the full game
# never reads, no achievements, and an end page that points at the full game's
# store page.

const CHAPTERS := 3
const STORE_URL := "https://store.steampowered.com/app/4953700/"

static var forced := false   # tests


static func on() -> bool:
	return forced or OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args()


# What came after the demo was cut: the pixel effects and the new title motion
# (the user, 2026-11-04: the full game only, the demo stays as it shipped).
static func extras() -> bool:
	return not on()


# The full game's store page: in the Steam overlay when Steam is there, else the browser.
static func open_store() -> void:
	if not SteamBridge.open_store():
		OS.shell_open(STORE_URL)
