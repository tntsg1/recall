class_name Fonts
# Chakra Petch for numerals and Latin, Noto Sans SC (subset) behind it for Chinese.

static var _cache := {}


static func get_font(weight: String = "Regular") -> Font:
	if _cache.has(weight):
		return _cache[weight]
	var f: FontFile = load("res://assets/fonts/ChakraPetch-%s.ttf" % weight)
	var sc_name := "Regular"
	if weight == "Light":
		sc_name = "Light"
	elif weight == "SemiBold" or weight == "Medium":
		sc_name = "Semibold"
	var path := "res://assets/fonts/RecallSC-%s.ttf" % sc_name
	if ResourceLoader.exists(path):
		f.fallbacks = [load(path)]
	_cache[weight] = f
	return f
