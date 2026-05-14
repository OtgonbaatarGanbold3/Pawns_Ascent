extends Control
class_name ChoiceOverlay

signal choice_selected(index: int)

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _buttons_scroll: ScrollContainer
var _buttons_grid: GridContainer
var _detail_label: Label
var _options: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.015, 0.017, 0.02, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(920, 520)
	_panel.add_theme_stylebox_override("panel", PawnUITheme.make_panel_style(Color(0.045, 0.052, 0.06, 0.98), Color(0.38, 0.44, 0.49, 1.0), 18, 10, 2))
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_body_label)

	_buttons_scroll = ScrollContainer.new()
	_buttons_scroll.name = "ChoicesScroll"
	_buttons_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_buttons_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_buttons_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_buttons_scroll)

	_buttons_grid = GridContainer.new()
	_buttons_grid.name = "ChoicesGrid"
	_buttons_grid.add_theme_constant_override("h_separation", 12)
	_buttons_grid.add_theme_constant_override("v_separation", 12)
	_buttons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_scroll.add_child(_buttons_grid)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_detail_label)

	resized.connect(_on_resized)

func show_choices(title: String, body: String, options: Array) -> void:
	_options = options
	_title_label.text = title
	_body_label.text = body
	_detail_label.text = ""
	visible = true
	_center_panel()
	_rebuild_buttons()

func hide_choices() -> void:
	visible = false

func _on_resized() -> void:
	if visible:
		_center_panel()
		_rebuild_buttons()

func _center_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var margin: float = clamp(viewport_size.x * 0.05, 20.0, 64.0)
	var target_height: float = 360.0 if _options.size() <= 3 else 560.0
	var panel_size := Vector2(
		min(_panel.custom_minimum_size.x, viewport_size.x - margin * 2.0),
		min(target_height, viewport_size.y - margin * 2.0)
	)
	panel_size.x = max(320.0, panel_size.x)
	panel_size.y = max(300.0, panel_size.y)
	_panel.size = panel_size
	_panel.position = (viewport_size - panel_size) * 0.5

func _rebuild_buttons() -> void:
	if _buttons_grid == null:
		return
	for child in _buttons_grid.get_children():
		child.queue_free()
	var columns := _choice_columns()
	_buttons_grid.columns = columns
	var gap: int = int(_buttons_grid.get_theme_constant("h_separation"))
	var usable_width: float = max(260.0, _panel.size.x - 56.0)
	var button_width: float = floor((usable_width - float(max(0, columns - 1) * gap)) / float(columns))
	var button_height: float = 116.0 if columns > 1 else 86.0
	for i in range(_options.size()):
		var option: Dictionary = _options[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(button_width, button_height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s" % [str(option.get("label", "Choose")), str(option.get("summary", ""))]
		button.disabled = bool(option.get("disabled", false))
		var disabled_reason: String = str(option.get("disabled_reason", ""))
		button.tooltip_text = disabled_reason if button.disabled and not disabled_reason.is_empty() else str(option.get("summary", ""))
		button.mouse_entered.connect(_show_detail.bind(option))
		button.pressed.connect(_on_button_pressed.bind(i))
		_style_button(button)
		_buttons_grid.add_child(button)

func _choice_columns() -> int:
	var width := get_viewport_rect().size.x
	if width < 720.0:
		return 1
	if _options.size() <= 2:
		return min(2, _options.size())
	if width < 1180.0:
		return 2
	return min(3, max(1, _options.size()))

func _show_detail(option: Dictionary) -> void:
	var reason: String = str(option.get("disabled_reason", ""))
	if bool(option.get("disabled", false)) and not reason.is_empty():
		_detail_label.text = "%s\n%s" % [str(option.get("summary", "")), reason]
		return
	_detail_label.text = str(option.get("summary", ""))

func _on_button_pressed(index: int) -> void:
	emit_signal("choice_selected", index)

func _style_button(button: Button) -> void:
	var normal := PawnUITheme.make_panel_style(Color(0.074, 0.083, 0.092, 1.0), Color(0.28, 0.34, 0.39, 1.0), 9, 7, 2)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.095, 0.108, 0.12, 1.0)
	hover.border_color = Color(0.56, 0.63, 0.68, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.13, 0.14, 1.0)
	pressed.border_color = Color(0.72, 0.76, 0.7, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.042, 0.047, 0.052, 1.0)
	disabled.border_color = Color(0.16, 0.18, 0.2, 1.0)
	button.add_theme_stylebox_override("disabled", disabled)
