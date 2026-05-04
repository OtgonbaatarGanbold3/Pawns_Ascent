extends Control
class_name BoardView

signal tile_clicked(pos: Vector2i)

@onready var grid: GridContainer = $Grid
@onready var effects_layer: Control = $Effects

var board: BoardData = null
var buttons: Dictionary = {}
var move_highlights: Dictionary = {}
var attack_highlights: Dictionary = {}

var _tile_size := 84
var _font_size := 26

func _ready() -> void:
	effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func build_board(new_board: BoardData) -> void:
	board = new_board
	for child in grid.get_children():
		child.queue_free()
	buttons.clear()
	move_highlights.clear()
	attack_highlights.clear()
	grid.columns = board.cols
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	custom_minimum_size = Vector2(board.cols * _tile_size, board.rows * _tile_size)

	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			var button := Button.new()
			button.custom_minimum_size = Vector2(_tile_size, _tile_size)
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", _font_size)
			button.pressed.connect(_on_button_pressed.bind(pos))
			grid.add_child(button)
			buttons[_key(pos)] = button

	update_board(board)

func update_board(new_board: BoardData) -> void:
	board = new_board
	for row in range(board.rows):
		for col in range(board.cols):
			var pos := Vector2i(col, row)
			var tile = board.get_tile(pos)
			var button: Button = buttons.get(_key(pos), null)
			if button == null:
				continue

			var terrain_color := _terrain_color(tile)
			var key := _key(pos)
			if attack_highlights.has(key):
				terrain_color = terrain_color.lerp(Color(0.95, 0.35, 0.35), 0.55)
			elif move_highlights.has(key):
				terrain_color = terrain_color.lightened(0.3)
			button.modulate = terrain_color
			button.tooltip_text = _tile_tooltip(tile)

			if tile == null:
				button.text = ""
				continue

			if tile.terrain_data.get("fog", false) and not tile.revealed:
				button.text = "?"
				button.modulate = Color(0.08, 0.08, 0.1)
				continue

			if tile.piece == null:
				button.text = ""
			else:
				button.text = _piece_label(tile.piece)
				var font_color := _piece_color(tile.piece)
				button.add_theme_color_override("font_color", font_color)

func show_highlights(moves: Array, attacks: Array = []) -> void:
	move_highlights.clear()
	attack_highlights.clear()
	for pos in moves:
		move_highlights[_key(pos)] = true
	for pos in attacks:
		attack_highlights[_key(pos)] = true
	update_board(board)

func clear_highlights() -> void:
	move_highlights.clear()
	attack_highlights.clear()
	update_board(board)

func play_move_flash(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(0.6, 0.9, 1.0, 0.35), 0.35)

func play_attack_flash(pos: Vector2i) -> void:
	_spawn_tile_flash(pos, Color(1.0, 0.35, 0.35, 0.45), 0.25)

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
		custom_minimum_size = Vector2(board.cols * _tile_size, board.rows * _tile_size)
	for button in buttons.values():
		button.custom_minimum_size = Vector2(_tile_size, _tile_size)
		button.add_theme_font_size_override("font_size", _font_size)

func get_board_pixel_size() -> Vector2:
	if board == null:
		return Vector2.ZERO
	return Vector2(board.cols * _tile_size, board.rows * _tile_size)

func get_board_dims() -> Vector2i:
	if board == null:
		return Vector2i.ZERO
	return Vector2i(board.cols, board.rows)

func _on_button_pressed(pos: Vector2i) -> void:
	emit_signal("tile_clicked", pos)

func _piece_label(unit: Unit) -> String:
	if unit.is_player:
		return "O"
	return "[]"

func _terrain_color(tile: Tile) -> Color:
	if tile == null:
		return Color(0.2, 0.2, 0.22)
	match tile.terrain_id:
		"normal":
			return Color(0.4, 0.4, 0.42)
		"cursed":
			return Color(0.55, 0.35, 0.55)
		"fire":
			return Color(0.7, 0.35, 0.25)
		"blessed":
			return Color(0.35, 0.55, 0.35)
		"elevated":
			return Color(0.45, 0.45, 0.65)
		"fog":
			return Color(0.22, 0.22, 0.28)
		_:
			return Color(0.4, 0.4, 0.42)

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
	var text := "Terrain: %s" % _terrain_label(tile.terrain_id)
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
		_:
			return terrain_id

func _key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
