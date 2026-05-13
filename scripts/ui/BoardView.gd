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

func play_mutation_flash(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(0.62, 0.44, 0.92, 0.42), 0.55)

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
	var glyphs: Dictionary = {
		"pawn": "♙" if unit.is_player else "♟",
		"knight": "♘" if unit.is_player else "♞",
		"bishop": "♗" if unit.is_player else "♝",
		"rook": "♖" if unit.is_player else "♜",
		"queen": "♕" if unit.is_player else "♛",
		"king": "♔" if unit.is_player else "♚"
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
	return text

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
