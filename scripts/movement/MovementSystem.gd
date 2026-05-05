extends Node
class_name MovementSystem

static func get_valid_moves(unit: Unit, board: BoardData) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	match unit.move_type:
		"cardinal":
			moves = _ray_moves(unit, board, [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT], unit.move_range)
		"diagonal":
			moves = _ray_moves(unit, board, [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)], unit.move_range)
		"line":
			moves = _ray_moves(unit, board, [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT], unit.move_range)
		"omni":
			moves = _ray_moves(unit, board, [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)], unit.move_range)
		"knight":
			moves = _knight_moves(unit, board)
		_:
			moves = []
	return moves

static func get_adjacent_positions(pos: Vector2i) -> Array[Vector2i]:
	return [pos + Vector2i.UP, pos + Vector2i.DOWN, pos + Vector2i.LEFT, pos + Vector2i.RIGHT]

static func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

static func is_blocked(tile: Tile) -> bool:
	return tile != null and bool(tile.terrain_data.get("blocks_movement", false))

static func get_adjacent_enemies(unit: Unit, board: BoardData) -> Array[Unit]:
	var enemies: Array[Unit] = []
	for pos in get_adjacent_positions(unit.position):
		var tile = board.get_tile(pos)
		if tile == null or tile.piece == null:
			continue
		if not _is_friendly(unit, tile.piece):
			enemies.append(tile.piece)
	return enemies

static func _ray_moves(unit: Unit, board: BoardData, directions: Array, max_range: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for direction in directions:
		for step in range(1, max_range + 1):
			var pos: Vector2i = unit.position + direction * step
			if not board.is_in_bounds(pos):
				break
			var tile = board.get_tile(pos)
			if tile == null:
				break
			if is_blocked(tile):
				break
			if tile.piece != null:
				break
			moves.append(pos)
	return moves

static func _knight_moves(unit: Unit, board: BoardData) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var offsets = [
		Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
	]
	for offset in offsets:
		var pos: Vector2i = unit.position + offset
		if not board.is_in_bounds(pos):
			continue
		var tile = board.get_tile(pos)
		if tile == null or is_blocked(tile) or tile.piece != null:
			continue
		moves.append(pos)
	return moves

static func _is_friendly(a: Unit, b: Unit) -> bool:
	if a.is_player and b.is_player:
		return true
	if a.is_ally and (b.is_player or b.is_ally):
		return true
	if not a.is_player and not a.is_ally and not b.is_player and not b.is_ally:
		return true
	return false
