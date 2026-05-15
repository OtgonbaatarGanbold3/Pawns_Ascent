extends Control
class_name BoardView

signal tile_clicked(pos: Vector2i)
signal tile_hovered(pos: Vector2i)

@onready var grid: GridContainer = $Grid
@onready var effects_layer: Control = $Effects

var board: BoardData = null
var buttons: Dictionary = {}
var move_highlights: Dictionary = {}
var attack_highlights: Dictionary = {}
var enemy_intent_highlights: Dictionary = {}
var enemy_danger_highlights: Dictionary = {}
var selected_key := ""
var preview_key := ""

var _tile_size := 84
var _font_size := 26
var _anim_time := 0.0
var _repaint_accum := 0.0
var _moving_piece_keys: Dictionary = {}
var _status_icon_nodes: Dictionary = {}
var _terrain_overlay_nodes: Dictionary = {}
var _unit_state_nodes: Dictionary = {}

func _ready() -> void:
	effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if board == null:
		return
	_anim_time += delta
	_repaint_accum += delta
	if _repaint_accum < 0.16:
		return
	_repaint_accum = 0.0
	_repaint_tiles()

func build_board(new_board: BoardData) -> void:
	board = new_board
	for child in grid.get_children():
		child.queue_free()
	buttons.clear()
	_clear_persistent_overlay_nodes()
	move_highlights.clear()
	attack_highlights.clear()
	enemy_intent_highlights.clear()
	enemy_danger_highlights.clear()
	preview_key = ""
	grid.columns = board.cols
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_apply_board_size()

	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			var button := Button.new()
			button.custom_minimum_size = Vector2(_tile_size, _tile_size)
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", _font_size)
			button.pressed.connect(_on_button_pressed.bind(pos))
			button.mouse_entered.connect(_on_button_hovered.bind(pos))
			grid.add_child(button)
			buttons[_key(pos)] = button

	update_board(board)

func update_board(new_board: BoardData) -> void:
	board = new_board
	_repaint_accum = 0.0
	_repaint_tiles()

func _repaint_tiles() -> void:
	if board == null:
		return
	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			var tile: Tile = board.get_tile(pos)
			var button: Button = buttons.get(_key(pos), null)
			if button == null:
				continue

			var terrain_color := _terrain_color(tile)
			var key := _key(pos)
			if tile == null:
				_apply_button_style(button, Color(0.025, 0.028, 0.032), Color(0.025, 0.028, 0.032))
				button.text = ""
				button.tooltip_text = ""
				continue
			if enemy_danger_highlights.has(key):
				terrain_color = terrain_color.lerp(Color(1.0, 0.34, 0.12), 0.62)
			elif attack_highlights.has(key):
				terrain_color = terrain_color.lerp(Color(0.95, 0.18, 0.16), 0.58)
			elif enemy_intent_highlights.has(key):
				terrain_color = terrain_color.lerp(Color(1.0, 0.62, 0.14), 0.46)
			elif move_highlights.has(key):
				terrain_color = terrain_color.lerp(Color(0.34, 0.64, 0.92), 0.42)
			var border_color := Color(0.09, 0.1, 0.11)
			if key == selected_key:
				border_color = Color(0.9, 0.82, 0.52)
			elif key == preview_key:
				border_color = Color(0.95, 0.95, 0.72)
			elif enemy_danger_highlights.has(key):
				border_color = Color(1.0, 0.42, 0.18)
			elif attack_highlights.has(key):
				border_color = Color(1.0, 0.38, 0.32)
			elif enemy_intent_highlights.has(key):
				border_color = Color(1.0, 0.7, 0.24)
			elif move_highlights.has(key):
				border_color = Color(0.48, 0.78, 1.0)
			_apply_button_style(button, terrain_color, border_color)
			button.tooltip_text = _tile_tooltip(tile)

			if tile.terrain_data.get("fog", false) and not tile.revealed:
				button.text = "?"
				_apply_button_style(button, Color(0.055, 0.065, 0.075), Color(0.12, 0.14, 0.16))
				continue

			if tile.piece == null:
				button.text = _terrain_marker(tile)
				if not tile.objective_type.is_empty():
					button.text = _objective_marker(tile)
					button.add_theme_color_override("font_color", _objective_color(tile))
				elif enemy_danger_highlights.has(key):
					button.text = "!"
					button.add_theme_color_override("font_color", Color(1.0, 0.76, 0.46))
				elif enemy_intent_highlights.has(key):
					button.text = ">"
					button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.46))
				elif not button.text.is_empty():
					button.add_theme_color_override("font_color", Color(0.82, 0.82, 0.78))
			elif _moving_piece_keys.has(key):
				button.text = ""
			else:
				button.text = _piece_label(tile.piece)
				var font_color := _piece_color(tile.piece)
				button.add_theme_color_override("font_color", font_color)
	_refresh_status_icons()
	_refresh_terrain_overlays()
	_refresh_unit_state_indicators()

func show_highlights(moves: Array, attacks: Array = [], selected_pos: Vector2i = Vector2i(-999, -999)) -> void:
	move_highlights.clear()
	attack_highlights.clear()
	enemy_intent_highlights.clear()
	enemy_danger_highlights.clear()
	selected_key = ""
	preview_key = ""
	for pos in moves:
		move_highlights[_key(pos)] = true
	for pos in attacks:
		attack_highlights[_key(pos)] = true
	if selected_pos != Vector2i(-999, -999):
		selected_key = _key(selected_pos)
	update_board(board)

func show_enemy_intents(intent_positions: Array, danger_positions: Array = []) -> void:
	enemy_intent_highlights.clear()
	enemy_danger_highlights.clear()
	for pos in intent_positions:
		enemy_intent_highlights[_key(pos)] = true
	for pos in danger_positions:
		enemy_danger_highlights[_key(pos)] = true
	update_board(board)

func clear_enemy_intents() -> void:
	enemy_intent_highlights.clear()
	enemy_danger_highlights.clear()
	update_board(board)

func set_preview_tile(pos: Vector2i) -> void:
	var key: String = _key(pos)
	if not move_highlights.has(key) and not attack_highlights.has(key):
		preview_key = ""
		update_board(board)
		return
	preview_key = key
	update_board(board)

func clear_highlights() -> void:
	move_highlights.clear()
	attack_highlights.clear()
	enemy_intent_highlights.clear()
	enemy_danger_highlights.clear()
	selected_key = ""
	preview_key = ""
	update_board(board)

func play_move_flash(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(0.6, 0.9, 1.0, 0.35), 0.35)

func animate_unit_move(from_pos: Vector2i, to_pos: Vector2i, unit: Unit) -> void:
	var from_rect := _get_tile_rect(from_pos)
	var to_rect := _get_tile_rect(to_pos)
	if from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO or unit == null:
		play_move_flash(to_pos)
		return

	_moving_piece_keys[_key(from_pos)] = true
	_moving_piece_keys[_key(to_pos)] = true
	update_board(board)

	var label := Label.new()
	label.text = _piece_label(unit)
	label.size = from_rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _font_size)
	label.add_theme_color_override("font_color", _piece_color(unit))
	label.position = from_rect.position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(label)

	var costs: Dictionary = DataLoader.load_config("action_costs")
	var duration: float = float(costs.get("move_animation_seconds", 0.18))
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", to_rect.position, max(0.05, duration))
	await tween.finished
	label.queue_free()
	_moving_piece_keys.erase(_key(from_pos))
	_moving_piece_keys.erase(_key(to_pos))
	play_move_flash(to_pos)
	update_board(board)

func play_attack_flash(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(1.0, 0.35, 0.35, 0.45), 0.25)
	_spawn_shape_burst(pos, "triangle", Color(0.95, 0.12, 0.1), 0.42, 1.0)

func play_mutation_flash(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(0.62, 0.44, 0.92, 0.42), 0.55)
	_spawn_shape_burst(pos, "hexagon", Color(0.62, 0.44, 0.92), 0.75, 1.15)

func show_status_effect(pos: Vector2i, status_id: String) -> void:
	var color := _status_color(status_id)
	_spawn_shape_burst(pos, _status_shape(status_id), color, 0.62, 1.05)
	show_float_text(pos, _status_label(status_id), color.lightened(0.16))

func show_trigger_effect(pos: Vector2i, trigger_id: String, school: String = "") -> void:
	var color := _school_color(school)
	var shape := _trigger_shape(trigger_id)
	_spawn_shape_burst(pos, shape, color, 0.58, 1.0)
	var text := _trigger_label(trigger_id)
	if not text.is_empty():
		show_float_text(pos, text, color.lightened(0.14))

func show_skill_effect(pos: Vector2i, skill_id: String) -> void:
	var color := _skill_color(skill_id)
	var shape := _skill_shape(skill_id)
	_spawn_shape_burst(pos, shape, color, 0.68, 1.12)
	var text := _skill_label(skill_id)
	if not text.is_empty():
		show_float_text(pos, text, color.lightened(0.12))

func show_evolution_effect(pos: Vector2i) -> void:
	_spawn_board_wash(Color(0.02, 0.018, 0.015, 0.42), 0.8)
	_spawn_tile_flash(pos, Color(0.95, 0.86, 0.42, 0.34), 0.95)
	_spawn_shape_burst(pos, "circle", Color(0.95, 0.86, 0.42), 0.95, 1.42)
	_spawn_shape_burst(pos, "diamond", Color(0.65, 0.88, 1.0), 0.8, 1.04)
	show_float_text(pos, "Rank shifts", Color(1.0, 0.9, 0.55))

func show_unit_state_effect(pos: Vector2i, state_id: String) -> void:
	var color := _unit_state_color(state_id)
	var shape := _unit_state_shape(state_id)
	_spawn_shape_burst(pos, shape, color, 0.7, 1.1)
	var text := _unit_state_label(state_id)
	if not text.is_empty():
		show_float_text(pos, text, color.lightened(0.16))

func show_aura(center: Vector2i, radius: int, aura_id: String = "aura", duration: float = 1.1) -> void:
	var color := _aura_color(aura_id)
	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			if abs(pos.x - center.x) + abs(pos.y - center.y) > radius:
				continue
			var rect := _get_tile_rect(pos)
			if rect.size == Vector2.ZERO:
				continue
			var panel := Panel.new()
			panel.position = rect.position + rect.size * 0.08
			panel.size = rect.size * 0.84
			panel.modulate = Color(1, 1, 1, 0.7 if pos == center else 0.34)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_theme_stylebox_override("panel", _shape_style("aura", color))
			effects_layer.add_child(panel)
			var tween := create_tween()
			tween.tween_property(panel, "modulate:a", 0.0, duration)
			tween.finished.connect(panel.queue_free)
	_spawn_shape_burst(center, "aura", color, duration, 1.35)

func show_threat_line(from_pos: Vector2i, to_pos: Vector2i, duration: float = 0.7) -> void:
	_spawn_line_between(from_pos, to_pos, Color(1.0, 0.16, 0.12, 0.86), max(3.0, _tile_size * 0.055), duration)
	show_unit_state_effect(to_pos, "threatening")

func show_skill_trail(from_pos: Vector2i, to_pos: Vector2i, skill_id: String = "mobility") -> void:
	var color := _skill_color(skill_id)
	_spawn_line_between(from_pos, to_pos, color, max(3.0, _tile_size * 0.045), 0.55)
	show_skill_effect(to_pos, skill_id)

func show_item_rarity_effect(pos: Vector2i, rarity: String, school: String = "") -> void:
	var color := _school_color(school)
	var shape := "diamond"
	var burst_scale := 1.0
	match rarity:
		"common":
			shape = _school_shape(school)
			burst_scale = 0.86
		"rare":
			shape = _school_shape(school)
			burst_scale = 1.02
		"epic":
			shape = "aura"
			burst_scale = 1.18
		"legendary":
			shape = "circle"
			burst_scale = 1.42
		_:
			shape = _school_shape(school)
	_spawn_shape_burst(pos, shape, color, 0.8, burst_scale)
	if rarity == "legendary":
		_spawn_shape_burst(pos, "square", Color(1.0, 0.86, 0.35), 0.9, 1.18)
	show_float_text(pos, rarity.capitalize(), color.lightened(0.14))

func play_critical_hit(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(1.0, 1.0, 1.0, 0.72), 0.18)
	_spawn_shape_burst(pos, "triangle", Color(1.0, 0.96, 0.9), 0.5, 1.25)
	_spawn_tile_shake(pos, Color(1.0, 0.25, 0.18, 0.26), 0.34)
	show_float_text(pos, "Critical", Color(1.0, 0.95, 0.86))

func play_kill_effect(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(0.02, 0.018, 0.02, 0.62), 0.5)
	_spawn_shape_burst(pos, "broken", Color(0.72, 0.18, 0.24), 0.72, 1.18)
	show_float_text(pos, "Fallen", Color(0.92, 0.58, 0.62))

func show_float_text(pos: Vector2i, text: String, color: Color = Color(0.9, 0.95, 1.0)) -> void:
	if text.is_empty():
		return
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", max(13, int(round(_font_size * 0.62))))
	label.add_theme_color_override("font_color", color)
	label.size = Vector2(rect.size.x * 1.8, rect.size.y)
	label.position = rect.position + Vector2(-rect.size.x * 0.4, rect.size.y * 0.12)
	label.modulate = Color(1, 1, 1, 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -_tile_size * 0.55), 0.65)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65)
	tween.finished.connect(label.queue_free)

func show_damage_number(pos: Vector2i, amount: int) -> void:
	if amount <= 0:
		return
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		return
	var label := Label.new()
	label.text = str(amount)
	var font_size: int = max(14, int(round(_font_size * 0.85)))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	var label_size := label.get_minimum_size()
	label.position = rect.position + (rect.size - label_size) * 0.5
	label.modulate = Color(1, 1, 1, 1)
	effects_layer.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -_tile_size * 0.35), 0.45)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45)
	tween.finished.connect(label.queue_free)

func set_tile_size(tile_size: int) -> void:
	var safe_size: int = max(24, tile_size)
	if safe_size == _tile_size:
		return
	_tile_size = safe_size
	_font_size = max(14, int(round(_tile_size * 0.32)))
	grid.add_theme_constant_override("h_separation", max(1, int(round(_tile_size * 0.04))))
	grid.add_theme_constant_override("v_separation", max(1, int(round(_tile_size * 0.04))))
	if board != null:
		_apply_board_size()
	for button in buttons.values():
		button.custom_minimum_size = Vector2(_tile_size, _tile_size)
		button.add_theme_font_size_override("font_size", _font_size)
	_refresh_status_icons()

func get_board_pixel_size() -> Vector2:
	if board == null:
		return Vector2.ZERO
	var separation: int = max(1, int(round(_tile_size * 0.04)))
	return Vector2(
		board.cols * _tile_size + max(0, board.cols - 1) * separation,
		board.rows * _tile_size + max(0, board.rows - 1) * separation
	)

func _apply_board_size() -> void:
	var board_size: Vector2 = get_board_pixel_size()
	custom_minimum_size = board_size
	size = board_size
	grid.custom_minimum_size = board_size
	grid.size = board_size

func get_board_dims() -> Vector2i:
	if board == null:
		return Vector2i.ZERO
	return Vector2i(board.cols, board.rows)

func _on_button_pressed(pos: Vector2i) -> void:
	emit_signal("tile_clicked", pos)

func _on_button_hovered(pos: Vector2i) -> void:
	emit_signal("tile_hovered", pos)

func _piece_label(unit: Unit) -> String:
	var friendly := unit.is_player or unit.is_ally
	var glyphs: Dictionary = {
		"pawn": "♙" if friendly else "♟",
		"knight": "♘" if friendly else "♞",
		"bishop": "♗" if friendly else "♝",
		"rook": "♖" if friendly else "♜",
		"queen": "♕" if friendly else "♛",
		"king": "♔" if friendly else "♚"
	}
	return str(glyphs.get(unit.piece_id, unit.display_name.substr(0, 1).to_upper()))

func _terrain_marker(tile: Tile) -> String:
	if tile == null:
		return ""
	match tile.terrain_id:
		"rock":
			return "▲"
		"house":
			return "⌂"
		_:
			return ""

func _objective_marker(tile: Tile) -> String:
	match tile.objective_type:
		"cache":
			return "$"
		"seal":
			return "O"
		"escape":
			return ">"
		_:
			return "?"

func _objective_color(tile: Tile) -> Color:
	match tile.objective_type:
		"cache":
			return Color(1.0, 0.86, 0.42)
		"seal":
			return Color(0.72, 0.9, 1.0)
		"escape":
			return Color(0.7, 1.0, 0.66)
		_:
			return Color(0.9, 0.9, 0.9)

func _terrain_color(tile: Tile) -> Color:
	if tile == null:
		return Color(0.16, 0.17, 0.18)
	var pulse: float = (sin(_anim_time * 3.0 + float(tile.position.x + tile.position.y)) + 1.0) * 0.5
	match tile.terrain_id:
		"normal":
			return Color(0.23, 0.25, 0.27)
		"cursed":
			return Color(0.28, 0.18, 0.34).lerp(Color(0.48, 0.26, 0.58), pulse * 0.35)
		"fire":
			return Color(0.44, 0.16, 0.09).lerp(Color(0.9, 0.35, 0.12), pulse * 0.38)
		"blessed":
			return Color(0.19, 0.33, 0.25).lerp(Color(0.36, 0.54, 0.35), pulse * 0.18)
		"elevated":
			return Color(0.27, 0.3, 0.42)
		"fog":
			return Color(0.11, 0.14, 0.17).lerp(Color(0.2, 0.24, 0.29), pulse * 0.35)
		"rock":
			return Color(0.18, 0.19, 0.2).lerp(Color(0.34, 0.35, 0.35), pulse * 0.12)
		"house":
			return Color(0.21, 0.17, 0.14).lerp(Color(0.34, 0.28, 0.21), pulse * 0.12)
		_:
			return Color(0.23, 0.25, 0.27)

func _apply_button_style(button: Button, fill_color: Color, border_color: Color) -> void:
	button.modulate = Color.WHITE
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill_color
	normal.border_color = border_color
	normal.set_border_width_all(max(1, int(round(_tile_size * 0.035))))
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = fill_color.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = fill_color.darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)

func _refresh_status_icons() -> void:
	if board == null:
		return
	var needed: Dictionary = {}
	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			var tile: Tile = board.get_tile(pos)
			if tile == null or tile.piece == null or tile.piece.status_effects.is_empty():
				continue
			var key := _key(pos)
			needed[key] = true
			var row_node: HBoxContainer = _status_icon_nodes.get(key, null)
			if row_node == null:
				row_node = HBoxContainer.new()
				row_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row_node.add_theme_constant_override("separation", max(1, int(round(_tile_size * 0.03))))
				effects_layer.add_child(row_node)
				_status_icon_nodes[key] = row_node
			_update_status_icon_row(row_node, pos, tile.piece.status_effects)
	var existing_keys: Array = _status_icon_nodes.keys()
	for key in existing_keys:
		if needed.has(key):
			continue
		var node: Node = _status_icon_nodes.get(key, null)
		if node != null:
			node.queue_free()
		_status_icon_nodes.erase(key)

func _refresh_terrain_overlays() -> void:
	if board == null:
		return
	var needed: Dictionary = {}
	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			var tile: Tile = board.get_tile(pos)
			if tile == null:
				continue
			var marker := _terrain_overlay_marker(tile)
			if marker.is_empty():
				continue
			var key := _key(pos)
			needed[key] = true
			var label: Label = _terrain_overlay_nodes.get(key, null)
			if label == null:
				label = Label.new()
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				effects_layer.add_child(label)
				_terrain_overlay_nodes[key] = label
			_update_terrain_overlay(label, pos, tile, marker)
	var existing_keys: Array = _terrain_overlay_nodes.keys()
	for key in existing_keys:
		if needed.has(key):
			continue
		var node: Node = _terrain_overlay_nodes.get(key, null)
		if node != null:
			node.queue_free()
		_terrain_overlay_nodes.erase(key)

func _update_terrain_overlay(label: Label, pos: Vector2i, tile: Tile, marker: String) -> void:
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		label.visible = false
		return
	label.visible = true
	label.text = marker
	label.position = rect.position
	label.size = rect.size
	label.modulate = Color(1, 1, 1, 0.34)
	label.add_theme_font_size_override("font_size", max(12, int(round(_font_size * 0.68))))
	label.add_theme_color_override("font_color", _terrain_overlay_color(tile.terrain_id))

func _refresh_unit_state_indicators() -> void:
	if board == null:
		return
	var needed: Dictionary = {}
	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			var tile: Tile = board.get_tile(pos)
			if tile == null or tile.piece == null:
				continue
			var states := _unit_states(tile.piece)
			if states.is_empty():
				continue
			var key := _key(pos)
			needed[key] = true
			var row_node: HBoxContainer = _unit_state_nodes.get(key, null)
			if row_node == null:
				row_node = HBoxContainer.new()
				row_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row_node.add_theme_constant_override("separation", max(1, int(round(_tile_size * 0.025))))
				effects_layer.add_child(row_node)
				_unit_state_nodes[key] = row_node
			_update_unit_state_row(row_node, pos, states)
	var existing_keys: Array = _unit_state_nodes.keys()
	for key in existing_keys:
		if needed.has(key):
			continue
		var node: Node = _unit_state_nodes.get(key, null)
		if node != null:
			node.queue_free()
		_unit_state_nodes.erase(key)

func _update_unit_state_row(row_node: HBoxContainer, pos: Vector2i, states: Array[String]) -> void:
	for child in row_node.get_children():
		child.queue_free()
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		row_node.visible = false
		return
	row_node.visible = true
	var icon_size: int = max(12, int(round(_tile_size * 0.2)))
	row_node.position = rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.72)
	row_node.size = Vector2(rect.size.x * 0.88, icon_size + 2)
	for state_id in states:
		var label := Label.new()
		label.text = _unit_state_icon_text(state_id)
		label.tooltip_text = _unit_state_label(state_id)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(icon_size, icon_size)
		label.add_theme_font_size_override("font_size", max(9, int(round(icon_size * 0.72))))
		label.add_theme_color_override("font_color", _unit_state_color(state_id).lightened(0.28))
		label.add_theme_stylebox_override("normal", _unit_state_icon_style(state_id))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_node.add_child(label)

func _unit_state_icon_style(state_id: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var color := _unit_state_color(state_id)
	style.bg_color = Color(color.r, color.g, color.b, 0.16)
	style.border_color = Color(color.r, color.g, color.b, 0.82)
	style.set_border_width_all(max(1, int(round(_tile_size * 0.016))))
	var radius: int = max(2, int(round(_tile_size * 0.05)))
	if state_id == "ready" or state_id == "boss":
		radius = max(8, int(round(_tile_size * 0.12)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _clear_persistent_overlay_nodes() -> void:
	for dict in [_status_icon_nodes, _terrain_overlay_nodes, _unit_state_nodes]:
		for node in dict.values():
			if node != null:
				node.queue_free()
		dict.clear()

func _update_status_icon_row(row_node: HBoxContainer, pos: Vector2i, statuses: Dictionary) -> void:
	for child in row_node.get_children():
		child.queue_free()
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		row_node.visible = false
		return
	row_node.visible = true
	var icon_size: int = max(14, int(round(_tile_size * 0.24)))
	row_node.position = rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.06)
	row_node.size = Vector2(rect.size.x * 0.88, icon_size + 2)
	for status_id in statuses.keys():
		var label := Label.new()
		label.text = _status_icon_text(str(status_id))
		label.tooltip_text = _status_tooltip(str(status_id), statuses.get(status_id, {}))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(icon_size, icon_size)
		label.add_theme_font_size_override("font_size", max(10, int(round(icon_size * 0.72))))
		label.add_theme_color_override("font_color", _status_color(str(status_id)).lightened(0.32))
		label.add_theme_stylebox_override("normal", _status_icon_style(str(status_id)))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_node.add_child(label)

func _status_icon_style(status_id: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var color := _status_color(status_id)
	style.bg_color = color.darkened(0.55)
	style.border_color = color.lightened(0.22)
	style.set_border_width_all(max(1, int(round(_tile_size * 0.018))))
	var radius: int = max(2, int(round(_tile_size * 0.04)))
	if _status_shape(status_id) == "circle":
		radius = max(8, int(round(_tile_size * 0.12)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _spawn_shape_burst(pos: Vector2i, shape: String, color: Color, duration: float, burst_scale: float) -> void:
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		return
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start_size := rect.size * 0.48 * burst_scale
	panel.size = start_size
	panel.position = rect.position + (rect.size - panel.size) * 0.5
	panel.modulate = Color(1, 1, 1, 0.9)
	panel.add_theme_stylebox_override("panel", _shape_style(shape, color))
	effects_layer.add_child(panel)

	var label := Label.new()
	label.text = _shape_text(shape)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = panel.size
	label.add_theme_font_size_override("font_size", max(16, int(round(_font_size * 0.82))))
	label.add_theme_color_override("font_color", color.lightened(0.28))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	var end_size := rect.size * 1.05 * burst_scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "size", end_size, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position", rect.position + (rect.size - end_size) * 0.5, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(panel.queue_free)

func _shape_style(shape: String, color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.08)
	style.border_color = Color(color.r, color.g, color.b, 0.85)
	style.set_border_width_all(max(2, int(round(_tile_size * 0.035))))
	var radius: int = 4
	if shape == "circle" or shape == "aura":
		radius = max(12, int(round(_tile_size * 0.18)))
	elif shape == "diamond":
		radius = 2
	elif shape == "broken":
		radius = 0
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _shape_text(shape: String) -> String:
	match shape:
		"circle":
			return "o"
		"triangle":
			return "^"
		"square":
			return "#"
		"diamond":
			return "<>"
		"hexagon":
			return "H"
		"broken":
			return "//"
		"aura":
			return "()"
		_:
			return "*"

func _spawn_tile_flash(pos: Vector2i, color: Color, duration: float) -> void:
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		return
	var flash := ColorRect.new()
	flash.color = color
	flash.position = rect.position
	flash.size = rect.size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.finished.connect(flash.queue_free)

func _spawn_board_wash(color: Color, duration: float) -> void:
	var wash := ColorRect.new()
	wash.color = color
	wash.size = get_board_pixel_size()
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(wash)
	var tween := create_tween()
	tween.tween_property(wash, "modulate:a", 0.0, duration)
	tween.finished.connect(wash.queue_free)

func _spawn_tile_shake(pos: Vector2i, color: Color, duration: float) -> void:
	var rect := _get_tile_rect(pos)
	if rect.size == Vector2.ZERO:
		return
	var panel := ColorRect.new()
	panel.color = color
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(panel)
	var tween := create_tween()
	tween.tween_property(panel, "position", rect.position + Vector2(_tile_size * 0.04, 0), duration * 0.22)
	tween.tween_property(panel, "position", rect.position + Vector2(-_tile_size * 0.04, 0), duration * 0.22)
	tween.tween_property(panel, "position", rect.position, duration * 0.18)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, duration)
	tween.finished.connect(panel.queue_free)

func _spawn_line_between(from_pos: Vector2i, to_pos: Vector2i, color: Color, thickness: float, duration: float) -> void:
	var from_rect := _get_tile_rect(from_pos)
	var to_rect := _get_tile_rect(to_pos)
	if from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO:
		return
	var start := from_rect.position + from_rect.size * 0.5
	var end := to_rect.position + to_rect.size * 0.5
	var delta := end - start
	if delta.length() <= 1.0:
		return
	var line := ColorRect.new()
	line.color = color
	line.position = start
	line.size = Vector2(delta.length(), thickness)
	line.pivot_offset = Vector2(0, thickness * 0.5)
	line.rotation = delta.angle()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, duration)
	tween.finished.connect(line.queue_free)

func _get_tile_rect(pos: Vector2i) -> Rect2:
	var button: Button = buttons.get(_key(pos), null)
	if button == null:
		return Rect2()
	var rect: Rect2 = button.get_global_rect()
	var layer_rect: Rect2 = effects_layer.get_global_rect()
	var local_pos: Vector2 = rect.position - layer_rect.position
	return Rect2(local_pos, rect.size)

func _piece_color(unit: Unit) -> Color:
	if unit.is_player:
		return Color(0.4, 0.9, 1.0)
	if unit.is_ally:
		return Color(0.58, 1.0, 0.64)
	if unit.is_boss:
		return Color(1.0, 0.8, 0.35)
	return Color(1.0, 0.45, 0.4)

func _tile_tooltip(tile: Tile) -> String:
	if tile == null:
		return ""
	if tile.terrain_data.get("fog", false) and not tile.revealed:
		return "Fog (unrevealed)"
	var text: String = "Terrain: %s" % _terrain_label(tile.terrain_id)
	if tile.terrain_data.get("blocks_movement", false):
		text += "\nBlocks movement"
	if tile.piece != null:
		text += "\nUnit: %s" % tile.piece.display_name
		text += "\nHP: %d/%d" % [tile.piece.hp, tile.piece.max_hp]
		if not tile.piece.status_effects.is_empty():
			text += "\nStatuses: %s" % _status_list_text(tile.piece.status_effects)
		var states := _unit_states(tile.piece)
		if not states.is_empty():
			var state_labels: Array[String] = []
			for state_id in states:
				state_labels.append(_unit_state_label(state_id))
			text += "\nState: %s" % ", ".join(state_labels)
	return text

func _terrain_overlay_marker(tile: Tile) -> String:
	if tile == null:
		return ""
	match tile.terrain_id:
		"elevated":
			return "="
		"blessed":
			return "o"
		"fire":
			return "^"
		"cursed":
			return "?"
		"void":
			return "//"
		"fog":
			return "~"
		_:
			return ""

func _terrain_overlay_color(terrain_id: String) -> Color:
	match terrain_id:
		"elevated":
			return Color(0.76, 0.82, 1.0)
		"blessed":
			return Color(0.76, 1.0, 0.76)
		"fire":
			return Color(1.0, 0.55, 0.22)
		"cursed":
			return Color(0.58, 0.34, 0.76)
		"void":
			return Color(0.7, 0.45, 1.0)
		"fog":
			return Color(0.68, 0.78, 0.86)
		_:
			return Color(0.8, 0.84, 0.86)

func _unit_states(unit: Unit) -> Array[String]:
	var states: Array[String] = []
	if unit == null:
		return states
	if unit.ap > 0:
		states.append("ready")
	if unit.max_hp > 0 and float(unit.hp) / float(unit.max_hp) <= 0.3:
		states.append("low_hp")
	if unit.is_boss:
		states.append("boss")
	if unit.is_boss and unit.items.size() > 0:
		states.append("legacy")
	return states

func _unit_state_icon_text(state_id: String) -> String:
	match state_id:
		"ready":
			return "o"
		"low_hp":
			return "!"
		"threatening":
			return ">"
		"boss":
			return "^"
		"legacy":
			return "E"
		_:
			return "*"

func _unit_state_label(state_id: String) -> String:
	match state_id:
		"ready":
			return "Ready"
		"low_hp":
			return "Low HP"
		"threatening":
			return "Threat"
		"boss":
			return "Boss"
		"legacy":
			return "Legacy"
		_:
			return state_id.capitalize()

func _unit_state_shape(state_id: String) -> String:
	match state_id:
		"ready":
			return "circle"
		"low_hp", "threatening":
			return "triangle"
		"boss", "legacy":
			return "aura"
		_:
			return "diamond"

func _unit_state_color(state_id: String) -> Color:
	match state_id:
		"ready":
			return Color(0.72, 0.94, 1.0)
		"low_hp":
			return Color(1.0, 0.22, 0.18)
		"threatening":
			return Color(1.0, 0.16, 0.12)
		"boss":
			return Color(1.0, 0.78, 0.28)
		"legacy":
			return Color(0.72, 0.62, 1.0)
		_:
			return Color(0.86, 0.88, 0.9)

func _aura_color(aura_id: String) -> Color:
	match aura_id:
		"fear":
			return Color(0.7, 0.18, 0.24)
		"heal":
			return Color(0.78, 0.95, 0.62)
		"corruption":
			return Color(0.62, 0.34, 0.86)
		_:
			return Color(0.82, 0.72, 1.0)

func _status_list_text(statuses: Dictionary) -> String:
	var parts: Array[String] = []
	for status_id in statuses.keys():
		var data: Dictionary = statuses.get(status_id, {})
		parts.append("%s %d" % [_status_label(str(status_id)), int(data.get("remaining", 0))])
	return ", ".join(parts)

func _status_tooltip(status_id: String, data: Dictionary) -> String:
	var remaining: int = int(data.get("remaining", 0))
	var damage: int = int(data.get("damage_per_tick", 0))
	var text := "%s: %d turns" % [_status_label(status_id), remaining]
	if damage > 0:
		text += "\n%d damage per tick" % damage
	var reduce: int = int(data.get("damage_reduce", 0))
	if reduce > 0:
		text += "\nReduces next hit by %d" % reduce
	return text

func _status_icon_text(status_id: String) -> String:
	match status_id:
		"bleed":
			return "/"
		"burn":
			return "^"
		"shielded":
			return "#"
		"empowered":
			return "+"
		"frozen":
			return "*"
		"shocked":
			return "Z"
		"cursed":
			return "?"
		"weakened":
			return "v"
		_:
			return "!"

func _status_label(status_id: String) -> String:
	match status_id:
		"bleed":
			return "Bleed"
		"burn":
			return "Burn"
		"shielded":
			return "Shield"
		"empowered":
			return "Empower"
		"frozen":
			return "Frozen"
		"shocked":
			return "Shock"
		"cursed":
			return "Curse"
		"weakened":
			return "Weak"
		_:
			return status_id.capitalize()

func _status_shape(status_id: String) -> String:
	match status_id:
		"shielded":
			return "square"
		"empowered":
			return "circle"
		"frozen", "shocked", "weakened":
			return "diamond"
		"cursed":
			return "broken"
		"burn", "bleed":
			return "triangle"
		_:
			return "circle"

func _status_color(status_id: String) -> Color:
	match status_id:
		"bleed":
			return Color(0.92, 0.08, 0.08)
		"burn":
			return Color(1.0, 0.42, 0.08)
		"shielded":
			return Color(0.76, 0.86, 0.94)
		"empowered":
			return Color(0.95, 0.82, 0.34)
		"frozen":
			return Color(0.56, 0.84, 1.0)
		"shocked":
			return Color(0.34, 0.68, 1.0)
		"cursed":
			return Color(0.54, 0.3, 0.72)
		"weakened":
			return Color(0.5, 0.54, 0.58)
		_:
			return Color(0.86, 0.88, 0.9)

func _school_color(school: String) -> Color:
	match school:
		"shadow":
			return Color(0.75, 0.08, 0.12)
		"holy":
			return Color(0.95, 0.78, 0.34)
		"siege":
			return Color(0.64, 0.68, 0.66)
		"void":
			return Color(0.62, 0.34, 0.86)
		_:
			return Color(0.78, 0.86, 0.94)

func _school_shape(school: String) -> String:
	match school:
		"shadow":
			return "triangle"
		"holy":
			return "circle"
		"siege":
			return "square"
		"void":
			return "broken"
		_:
			return "diamond"

func _trigger_shape(trigger_id: String) -> String:
	match trigger_id:
		"on_hit_bleed", "on_hit_knockback", "on_low_hp_buff":
			return "triangle"
		"on_kill_heal", "on_turn_ap":
			return "circle"
		"on_adj_defend":
			return "square"
		"on_move_extra":
			return "diamond"
		_:
			return "diamond"

func _trigger_label(trigger_id: String) -> String:
	match trigger_id:
		"on_hit_bleed":
			return "Bleed"
		"on_hit_knockback":
			return "Impact"
		"on_kill_heal":
			return "Return"
		"on_move_extra":
			return "Move"
		"on_turn_ap":
			return "+AP"
		"on_adj_defend":
			return "Guard"
		"on_low_hp_buff":
			return "+ATK"
		_:
			return ""

func _skill_shape(skill_id: String) -> String:
	match skill_id:
		"mobility":
			return "diamond"
		"impact":
			return "triangle"
		"summon":
			return "circle"
		"aura":
			return "aura"
		"mutation":
			return "hexagon"
		_:
			return "diamond"

func _skill_color(skill_id: String) -> Color:
	match skill_id:
		"mobility":
			return Color(0.42, 0.74, 1.0)
		"impact":
			return Color(1.0, 0.32, 0.16)
		"summon":
			return Color(0.55, 0.42, 0.82)
		"aura":
			return Color(0.82, 0.72, 1.0)
		"mutation":
			return Color(0.62, 0.44, 0.92)
		_:
			return Color(0.78, 0.86, 0.94)

func _skill_label(skill_id: String) -> String:
	match skill_id:
		"mobility":
			return "Dash"
		"impact":
			return "Impact"
		"summon":
			return "Rune"
		"aura":
			return "Aura"
		"mutation":
			return "Shift"
		_:
			return ""

func _terrain_label(terrain_id: String) -> String:
	match terrain_id:
		"normal":
			return "Normal"
		"cursed":
			return "Cursed"
		"fire":
			return "Fire"
		"blessed":
			return "Blessed"
		"elevated":
			return "Elevated"
		"fog":
			return "Fog"
		"rock":
			return "Rock"
		"house":
			return "House"
		_:
			return terrain_id

func _key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
