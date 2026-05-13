extends Control
class_name ChoiceOverlay

signal choice_selected(index: int)

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _buttons_row: HBoxContainer
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
	_panel.custom_minimum_size = Vector2(880, 340)
	_panel.add_theme_stylebox_override("panel", PawnUITheme.make_panel_style(Color(0.052, 0.059, 0.067, 0.98), Color(0.34, 0.39, 0.44, 1.0), 14))
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_body_label)

	_buttons_row = HBoxContainer.new()
	_buttons_row.add_theme_constant_override("separation", 14)
	vbox.add_child(_buttons_row)

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

func _center_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var margin: float = clamp(viewport_size.x * 0.05, 20.0, 64.0)
	var panel_size := Vector2(
		min(_panel.custom_minimum_size.x, viewport_size.x - margin * 2.0),
		min(_panel.custom_minimum_size.y, viewport_size.y - margin * 2.0)
	)
	panel_size.x = max(320.0, panel_size.x)
	panel_size.y = max(260.0, panel_size.y)
	_panel.size = panel_size
	_panel.position = (viewport_size - panel_size) * 0.5

func _rebuild_buttons() -> void:
	for child in _buttons_row.get_children():
		child.queue_free()
	for i in range(_options.size()):
		var option: Dictionary = _options[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 132)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\n\n%s" % [str(option.get("label", "Choose")), str(option.get("summary", ""))]
		button.tooltip_text = str(option.get("summary", ""))
		button.mouse_entered.connect(_show_detail.bind(option))
		button.pressed.connect(_on_button_pressed.bind(i))
		_style_button(button)
		_buttons_row.add_child(button)

func _show_detail(option: Dictionary) -> void:
	_detail_label.text = str(option.get("summary", ""))

func _on_button_pressed(index: int) -> void:
	emit_signal("choice_selected", index)

func _style_button(button: Button) -> void:
	var normal := PawnUITheme.make_panel_style(Color(0.083, 0.09, 0.098, 1.0), Color(0.26, 0.31, 0.35, 1.0), 6, 8, 2)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.105, 0.112, 0.12, 1.0)
	hover.border_color = Color(0.46, 0.52, 0.58, 1.0)
	button.add_theme_stylebox_override("hover", hover)
