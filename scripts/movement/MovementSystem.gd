extends Node
class_name MovementSystem

static func get_valid_moves(unit: Unit, board: BoardData) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var move_range: int = _move_range_for(unit)
	moves = _ray_moves(unit, board, _omni_directions(), move_range)
	return moves

static func get_attack_positions(unit: Unit, board: BoardData, attack_range: int = -1) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var max_range: int = attack_range
	if max_range < 0:
		max_range = int(DataLoader.load_config("combat_rules").get("attack_range", 2))
	for direction in _omni_directions():
		for step in range(1, max_range + 1):
			var pos: Vector2i = unit.position + direction * step
			if not board.is_in_bounds(pos):
				break
			var tile = board.get_tile(pos)
			if tile == null or is_blocked(tile):
				break
			if tile.piece != null:
				if not _is_friendly(unit, tile.piece):
					positions.append(pos)
				break
	return positions

static func can_attack(unit: Unit, target: Unit, board: BoardData, attack_range: int = -1) -> bool:
	if unit == null or target == null or board == null:
		return false
	return target.position in get_attack_positions(unit, board, attack_range)

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

static func _move_range_for(unit: Unit) -> int:
	return max(1, unit.spd + int(unit.trigger_flags.get("move_range_bonus", 0)))

static func _omni_directions() -> Array[Vector2i]:
	return [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]

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
