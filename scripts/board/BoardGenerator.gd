extends Node
class_name BoardGenerator


static func generate_board(rng: RandomNumberGenerator, board_override: Dictionary = {}) -> BoardData:
    var config: Dictionary = DataLoader.load_config("encounters")
    var board_cfg: Dictionary = config.get("board", {})
    if not board_override.is_empty():
        board_cfg = board_override
    var rows: int = int(board_cfg.get("rows", 8))
    var cols: int = int(board_cfg.get("cols", 9))

    var board := BoardData.new()
    board.init_board(rows, cols)

    var terrain_cfg: Dictionary = DataLoader.load_config("terrain")
    var terrain_ids: Array = terrain_cfg.keys()
    var weights: Array = []
    var total_weight := 0
    for terrain_id in terrain_ids:
        var weight: int = int(terrain_cfg[terrain_id].get("base_weight", 0))
        weights.append(weight)
        total_weight += weight

    for row in range(rows):
        for col in range(cols):
            var terrain_id := _pick_weighted(terrain_ids, weights, total_weight, rng)
            var tile := Tile.new()
            var data: Dictionary = terrain_cfg.get(terrain_id, {})
            tile.init_from_terrain(terrain_id, data)
            tile.revealed = not bool(data.get("fog", false))
            board.set_tile(Vector2i(col, row), tile)

    return board

static func get_spawn_positions(board: BoardData, quadrant: String, count: int, _rng: RandomNumberGenerator) -> Array:
    var positions := _positions_for_quadrant(board, quadrant)
    var result: Array = []
    if positions.is_empty():
        return result
    positions.shuffle()
    var attempts := 0
    while result.size() < count and attempts < positions.size():
        var pos: Vector2i = positions[attempts]
        var tile = board.get_tile(pos)
        if tile != null and tile.piece == null and not bool(tile.terrain_data.get("blocks_movement", false)):
            result.append(pos)
        attempts += 1
    return result

static func mutate_empty_tile(board: BoardData, rng: RandomNumberGenerator) -> Vector2i:
    if board == null:
        return Vector2i(-1, -1)
    var candidates: Array[Vector2i] = []
    for row in range(board.rows):
        for col in range(board.cols):
            var pos := Vector2i(col, row)
            var candidate_tile: Tile = board.get_tile(pos) as Tile
            if candidate_tile != null and candidate_tile.piece == null:
                candidates.append(pos)
    if candidates.is_empty():
        return Vector2i(-1, -1)
    candidates.shuffle()
    var target: Vector2i = candidates[0]
    var terrain_cfg: Dictionary = DataLoader.load_config("terrain")
    var terrain_ids: Array = terrain_cfg.keys()
    var weights: Array = []
    var total_weight := 0
    for terrain_id in terrain_ids:
        var weight: int = int(terrain_cfg[terrain_id].get("base_weight", 0))
        weights.append(weight)
        total_weight += weight
    var terrain_id := _pick_weighted(terrain_ids, weights, total_weight, rng)
    var tile := Tile.new()
    tile.init_from_terrain(terrain_id, terrain_cfg.get(terrain_id, {}))
    tile.revealed = not bool(tile.terrain_data.get("fog", false))
    board.set_tile(target, tile)
    return target

static func _positions_for_quadrant(board: BoardData, quadrant: String) -> Array:
    var positions: Array = []
    var mid_row := int(board.rows / 2.0)
    var mid_col := int(board.cols / 2.0)

    var row_start := 0
    var row_end := board.rows
    var col_start := 0
    var col_end := board.cols

    match quadrant:
        "bottom_left":
            row_start = mid_row
            col_end = mid_col
        "top_right":
            row_end = mid_row
            col_start = mid_col
        _:
            pass

    for row in range(row_start, row_end):
        for col in range(col_start, col_end):
            positions.append(Vector2i(col, row))
    return positions

static func _pick_weighted(ids: Array, weights: Array, total: int, rng: RandomNumberGenerator) -> String:
    if total <= 0:
        return "normal"
    var roll := rng.randi_range(1, total)
    var running := 0
    for i in range(ids.size()):
        running += int(weights[i])
        if roll <= running:
            return str(ids[i])
    return "normal"
