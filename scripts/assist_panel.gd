class_name AssistPanel
extends CanvasLayer

signal closed
var game
var old_mouse := Input.MOUSE_MODE_HIDDEN

func _ready() -> void:
	layer = 110
	old_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.025, 0.03, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	shade.add_child(margin)
	var theme := Theme.new()
	theme.default_font = Fonts.get_font("Regular")
	theme.default_font_size = 24
	for kind in ["Button", "OptionButton", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.075, 0.075, 0.085)
			style.border_color = Color(0.85, 0.14, 0.17) if state == "focus" else Color(0.22, 0.22, 0.24)
			style.set_border_width_all(2 if state == "focus" else 1)
			style.content_margin_left = 18
			style.content_margin_right = 18
			style.content_margin_top = 12
			style.content_margin_bottom = 12
			theme.set_stylebox(state, kind, style)
	margin.theme = theme
	var center := CenterContainer.new()
	margin.add_child(center)
	var scroll := ScrollContainer.new()
	var vp := get_viewport().get_visible_rect().size
	scroll.custom_minimum_size = Vector2(minf(1040, vp.x - 80), minf(780, vp.y - 80))
	center.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 22)
	col.add_theme_font_override("font", Fonts.get_font("Regular"))
	col.add_theme_font_size_override("font_size", 24)
	scroll.add_child(col)
	_label(col, Txt.t("a_title"), 36)
	_label(col, Txt.t("a_intro"))
	var enabled := CheckButton.new()
	enabled.custom_minimum_size.y = 58
	enabled.text = Txt.t("a_enable")
	enabled.button_pressed = Settings.assist
	col.add_child(enabled)
	var damage := OptionButton.new()
	damage.custom_minimum_size.y = 58
	for n in range(0, 81, 20):
		damage.add_item(Txt.t("a_damage") % n, n)
	damage.select(int(Settings.damage_reduction / 20.0))
	col.add_child(damage)
	var retries := OptionButton.new()
	retries.custom_minimum_size.y = 58
	for n in [0, 1, 3, 5]:
		retries.add_item(Txt.t("a_retries") % n, n)
	retries.select(maxi(0, [0, 1, 3, 5].find(Settings.retry_limit)))
	col.add_child(retries)
	var status := _label(col, "")
	var refresh := func():
		damage.disabled = not Settings.assist
		retries.disabled = not Settings.assist
		status.text = Txt.t("a_remaining") % maxi(0, Settings.retry_limit - game.assist_retries_used) if game != null else Txt.t("a_new_run")
	refresh.call()
	enabled.toggled.connect(func(value):
		Settings.assist = value
		Settings.save()
		refresh.call())
	damage.item_selected.connect(func(i):
		Settings.damage_reduction = damage.get_item_id(i)
		Settings.save())
	retries.item_selected.connect(func(i):
		Settings.retry_limit = retries.get_item_id(i)
		Settings.save()
		refresh.call())
	_label(col, Txt.t("a_checkpoint"))
	_label(col, Txt.t("a_fraction"))
	var back := Button.new()
	back.text = Txt.t("t_back_short")
	back.custom_minimum_size.y = 54
	col.add_child(back)
	back.pressed.connect(close)
	enabled.grab_focus()

func _label(col: VBoxContainer, text: String, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	col.add_child(label)
	return label

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	Input.mouse_mode = old_mouse
	closed.emit()
	queue_free()
