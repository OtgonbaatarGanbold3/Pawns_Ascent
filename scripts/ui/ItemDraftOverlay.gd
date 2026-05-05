extends Control
class_name ItemDraftOverlay

signal item_selected(item_id: String)
signal draft_skipped

@onready var item_button_1: Button = $Panel/VBox/Buttons/ItemButton1
@onready var item_button_2: Button = $Panel/VBox/Buttons/ItemButton2
@onready var item_button_3: Button = $Panel/VBox/Buttons/ItemButton3
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var desc_label: Label = $Panel/VBox/DescLabel
@onready var skip_button: Button = $Panel/VBox/SkipButton
@onready var panel: PanelContainer = $Panel
@onready var buttons_row: HBoxContainer = $Panel/VBox/Buttons
@onready var backdrop: ColorRect = $Backdrop
@onready var vbox: VBoxContainer = $Panel/VBox

var items: Array = []
var _card_buttons: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_buttons = [item_button_1, item_button_2, item_button_3]
	item_button_1.pressed.connect(_on_item_pressed.bind(0))
	item_button_2.pressed.connect(_on_item_pressed.bind(1))
	item_button_3.pressed.connect(_on_item_pressed.bind(2))
	skip_button.pressed.connect(_on_skip_pressed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.custom_minimum_size = Vector2(980, 360)
	_apply_styles()
	resized.connect(_on_resized)

func show_draft(options: Array) -> void:
	items = options
	visible = true
	_center_panel()
	_apply_button(item_button_1, 0)
	_apply_button(item_button_2, 1)
	_apply_button(item_button_3, 2)
	desc_label.text = "Choose one relic to carry into the next level."

func hide_draft() -> void:
	visible = false

func _on_resized() -> void:
	if visible:
		_center_panel()

func _center_panel() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var margin: float = clamp(viewport_size.x * 0.04, 20.0, 56.0)
	var target_width: float = min(panel.custom_minimum_size.x, viewport_size.x - margin * 2.0)
	var target_height: float = min(panel.custom_minimum_size.y, viewport_size.y - margin * 2.0)
	if viewport_size.x < 820.0:
		target_width = viewport_size.x - margin * 2.0
		target_height = min(viewport_size.y - margin * 2.0, 620.0)
	var panel_size: Vector2 = Vector2(
		max(320.0, target_width),
		max(260.0, target_height)
	)
	panel.size = panel_size
	panel.position = (viewport_size - panel_size) * 0.5
	_resize_cards(panel_size)

func _apply_button(button: Button, index: int) -> void:
	if index >= items.size():
		button.text = "-"
		button.disabled = true
		return
	if typeof(items[index]) != TYPE_DICTIONARY:
		button.text = "-"
		button.disabled = true
		return
	var item: Dictionary = items[index]
	button.text = _format_card_text(item)
	button.disabled = false

func _on_item_pressed(index: int) -> void:
	if index >= items.size():
		return
	if typeof(items[index]) != TYPE_DICTIONARY:
		return
	var item: Dictionary = items[index]
	var item_id: String = str(item.get("id", ""))
	emit_signal("item_selected", item_id)

func _on_skip_pressed() -> void:
	emit_signal("draft_skipped")

func _apply_styles() -> void:
	title_label.add_theme_font_size_override("font_size", 28)
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buttons_row.add_theme_constant_override("separation", 14)
	vbox.add_theme_constant_override("separation", 12)

	var panel_style: StyleBoxFlat = PawnUITheme.make_panel_style(Color(0.055, 0.065, 0.075, 0.98), Color(0.36, 0.42, 0.48, 1.0), 18)
	panel.add_theme_stylebox_override("panel", panel_style)

	for button in _card_buttons:
		button.add_theme_font_size_override("font_size", 15)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(button, Color(0.085, 0.095, 0.105), Color(0.22, 0.27, 0.31))

	skip_button.custom_minimum_size = Vector2(180, 46)
	skip_button.add_theme_font_size_override("font_size", 18)
	_style_button(skip_button, Color(0.12, 0.105, 0.095), Color(0.32, 0.26, 0.22))

func _style_button(button: Button, fill: Color, border: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_content_margin_all(12)
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = border.lightened(0.18)
	button.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)

func _format_card_text(item: Dictionary) -> String:
	var lines: Array = [
		str(item.get("display_name", "Relic")),
		str(item.get("school", "-")).capitalize(),
		"",
		_format_item_details(item)
	]
	var flavor: String = str(item.get("flavor", ""))
	if not flavor.is_empty():
		lines.append("")
		lines.append(flavor)
	return _join_strings(lines, "\n")

func _format_item_details(item: Dictionary) -> String:
	var parts: Array = []
	var stats: Dictionary = {}
	if typeof(item.get("stats", {})) == TYPE_DICTIONARY:
		stats = item.get("stats", {})
	for stat_name in ["hp", "atk", "def", "spd", "ap"]:
		var value: int = int(stats.get(stat_name, 0))
		if value == 0:
			continue
		var value_prefix: String = "+" if value > 0 else ""
		parts.append("%s%d %s" % [value_prefix, value, stat_name.to_upper()])
	var trigger_text: String = _trigger_summary(item)
	if not trigger_text.is_empty():
		parts.append(trigger_text)
	if parts.is_empty():
		return "No stat marks."
	return _join_strings(parts, "  |  ")

func _trigger_summary(item: Dictionary) -> String:
	var trigger_id: String = str(item.get("trigger_id", ""))
	match trigger_id:
		"on_hit_bleed":
			return "On hit: Bleed"
		"on_kill_heal":
			return "On kill: Heal %d" % int(item.get("trigger_value", 0))
		"on_hit_knockback":
			return "On hit: Push"
		"on_move_extra":
			return "Active: Extend move"
		"on_turn_ap":
			return "Turn start: +AP"
		"on_adj_defend":
			return "Adjacent threat: Shield"
		"on_low_hp_buff":
			return "Low HP: +ATK"
		_:
			return ""

func _join_strings(values: Array, separator: String) -> String:
	var text: String = ""
	var first: bool = true
	for value in values:
		if first:
			first = false
		else:
			text += separator
		text += str(value)
	return text

func _resize_cards(panel_size: Vector2) -> void:
	var available_width: float = max(280.0, panel_size.x - 72.0)
	var card_width: float = floor((available_width - 28.0) / 3.0)
	card_width = clamp(card_width, 150.0, 304.0)
	var card_height: float = clamp(panel_size.y * 0.52, 132.0, 196.0)
	for button in _card_buttons:
		button.custom_minimum_size = Vector2(card_width, card_height)
