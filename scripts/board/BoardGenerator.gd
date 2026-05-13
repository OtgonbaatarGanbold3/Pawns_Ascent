extends Node
class_name BoardGenerator


static func generate_board(rng: RandomNumberGenerator, board_override: Dictionary = {}) -> BoardData:
    var config: Dictionary = DataLoader.load_config("encounters")
    var board_cfg: Dictionary = config.get("board", {})
    if not board_override.is_empty():
        board_cfg = board_override
    var floor_index: int = int(board_cfg.get("floor", DataLoader.load_config("map_generation").get("default_floor", 1)))
    var layout_cfg := _layout_cfg_for_floor(floor_index)
    var rows: int = int(board_cfg.get("rows", layout_cfg.get("rows", 8)))
    var cols: int = int(board_cfg.get("cols", layout_cfg.get("cols", 9)))

    var board := BoardData.new()
    board.init_board(rows, cols)

    var terrain_cfg: Dictionary = DataLoader.load_config("terrain")
    for row in range(rows):
        for col in range(cols):
            var terrain_id := _pick_weighted_terrain(terrain_cfg, rng, false)
            var tile := Tile.new()
            var data: Dictionary = terrain_cfg.get(terrain_id, {})
            tile.init_from_terrain(terrain_id, data)
            tile.revealed = not bool(data.get("fog", false))
            board.set_tile(Vector2i(col, row), tile)

    _apply_footprint(board, layout_cfg, rng)
    _apply_layout(board, terrain_cfg, layout_cfg, rng)
    _place_terrain_group(board, terrain_cfg, DataLoader.load_config("map_generation").get("hazard_terrain", []), _roll_range(layout_cfg.get("hazards", [0, 0]), rng), rng)
    _place_terrain_group(board, terrain_cfg, DataLoader.load_config("map_generation").get("boon_terrain", []), _roll_range(layout_cfg.get("boons", [0, 0]), rng), rng)
    _clear_spawn_safety(board, terrain_cfg)
    _ensure_spawn_path(board, terrain_cfg)
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
            if candidate_tile != null and candidate_tile.piece == null and candidate_tile.objective_type.is_empty():
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

static func _layout_cfg_for_floor(floor_index: int) -> Dictionary:
    var cfg: Dictionary = DataLoader.load_config("map_generation")
    var bands: Array = cfg.get("floor_bands", [])
    for band_value in bands:
        if typeof(band_value) != TYPE_DICTIONARY:
            continue
        var band: Dictionary = band_value
        if floor_index >= int(band.get("min_floor", 1)) and floor_index <= int(band.get("max_floor", 999)):
            return band
    return {"rows": 8, "cols": 9, "blockers": [4, 6], "hazards": [3, 5], "boons": [2, 3], "footprints": ["rectangle"], "layouts": ["pillars"]}

static func _apply_footprint(board: BoardData, layout_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var footprints: Array = layout_cfg.get("footprints", ["rectangle"])
    var footprint_id := "rectangle"
    if not footprints.is_empty():
        footprint_id = str(footprints[rng.randi_range(0, footprints.size() - 1)])
    match footprint_id:
        "notched":
            _carve_notches(board, rng)
        "l_shape":
            _carve_l_shape(board, rng)
        "cross":
            _carve_cross(board)
        "offset_chambers":
            _carve_offset_chambers(board, rng)
        "split_corners":
            _carve_split_corners(board, rng)
        "ragged":
            _carve_ragged_edges(board, rng)
        _:
            pass
    _restore_spawn_safety_cells(board)

static func _carve_notches(board: BoardData, rng: RandomNumberGenerator) -> void:
    var notch_w: int = max(2, int(board.cols / 4.0))
    var notch_h: int = max(2, int(board.rows / 4.0))
    var corners: Array[Vector2i] = [Vector2i.ZERO, Vector2i(board.cols - notch_w, 0), Vector2i(0, board.rows - notch_h), Vector2i(board.cols - notch_w, board.rows - notch_h)]
    corners.shuffle()
    var carve_count := rng.randi_range(1, 2)
    for i in range(carve_count):
        var corner: Vector2i = corners[i]
        for y in range(corner.y, corner.y + notch_h):
            for x in range(corner.x, corner.x + notch_w):
                _carve_cell(board, Vector2i(x, y))

static func _carve_l_shape(board: BoardData, rng: RandomNumberGenerator) -> void:
    var cut_w: int = max(2, int(board.cols / 3.0))
    var cut_h: int = max(2, int(board.rows / 3.0))
    var top_side := rng.randi_range(0, 1) == 0
    var right_side := rng.randi_range(0, 1) == 0
    var start_x := board.cols - cut_w if right_side else 0
    var start_y := 0 if top_side else board.rows - cut_h
    for y in range(start_y, start_y + cut_h):
        for x in range(start_x, start_x + cut_w):
            _carve_cell(board, Vector2i(x, y))

static func _carve_cross(board: BoardData) -> void:
    var mid_col := int(board.cols / 2.0)
    var mid_row := int(board.rows / 2.0)
    for row in range(board.rows):
        for col in range(board.cols):
            var near_vertical: bool = abs(col - mid_col) <= 2
            var near_horizontal: bool = abs(row - mid_row) <= 2
            if not near_vertical and not near_horizontal:
                _carve_cell(board, Vector2i(col, row))

static func _carve_offset_chambers(board: BoardData, rng: RandomNumberGenerator) -> void:
    var split_col := int(board.cols / 2.0)
    var split_row := int(board.rows / 2.0)
    for row in range(board.rows):
        for col in range(board.cols):
            var keep_left_room: bool = col < split_col and row >= split_row - 1
            var keep_right_room: bool = col >= split_col - 1 and row <= split_row + 1
            var keep_bridge: bool = abs(col - split_col) <= 1 or abs(row - split_row) <= 1
            if not keep_left_room and not keep_right_room and not keep_bridge:
                _carve_cell(board, Vector2i(col, row))
    if rng.randi_range(0, 1) == 0:
        _mirror_footprint_horizontally(board)

static func _carve_split_corners(board: BoardData, rng: RandomNumberGenerator) -> void:
    var keep_radius: int = max(3, int(min(board.cols, board.rows) / 2.0))
    var a := Vector2i(1, board.rows - 2)
    var b := Vector2i(board.cols - 2, 1)
    for row in range(board.rows):
        for col in range(board.cols):
            var pos := Vector2i(col, row)
            var near_a: bool = abs(pos.x - a.x) + abs(pos.y - a.y) <= keep_radius
            var near_b: bool = abs(pos.x - b.x) + abs(pos.y - b.y) <= keep_radius
            var bridge: bool = abs((pos.x + pos.y) - (board.rows - 1)) <= 2
            if not near_a and not near_b and not bridge:
                _carve_cell(board, pos)
    if rng.randi_range(0, 1) == 0:
        _mirror_footprint_horizontally(board)

static func _carve_ragged_edges(board: BoardData, rng: RandomNumberGenerator) -> void:
    for row in range(board.rows):
        for col in range(board.cols):
            var edge_distance: int = min(min(col, board.cols - 1 - col), min(row, board.rows - 1 - row))
            if edge_distance <= 1 and rng.randi_range(0, 99) < 35:
                _carve_cell(board, Vector2i(col, row))

static func _mirror_footprint_horizontally(board: BoardData) -> void:
    var copies: Dictionary = {}
    for row in range(board.rows):
        for col in range(board.cols):
            copies[_key(Vector2i(col, row))] = board.get_tile(Vector2i(col, row))
    for row in range(board.rows):
        for col in range(board.cols):
            board.set_tile(Vector2i(col, row), copies.get(_key(Vector2i(board.cols - 1 - col, row)), null))

static func _carve_cell(board: BoardData, pos: Vector2i) -> void:
    if not board.is_in_bounds(pos) or _is_spawn_safety_pos(board, pos):
        return
    board.set_tile(pos, null)

static func _restore_spawn_safety_cells(board: BoardData) -> void:
    var terrain_cfg: Dictionary = DataLoader.load_config("terrain")
    for pos in _spawn_safety_positions(board):
        if board.get_tile(pos) == null:
            _set_tile_terrain(board, terrain_cfg, pos, "normal")

static func _apply_layout(board: BoardData, terrain_cfg: Dictionary, layout_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var layouts: Array = layout_cfg.get("layouts", ["pillars"])
    var layout_id := "pillars"
    if not layouts.is_empty():
        layout_id = str(layouts[rng.randi_range(0, layouts.size() - 1)])
    match layout_id:
        "broken_lane":
            _apply_broken_lane(board, terrain_cfg, rng)
        "two_rooms":
            _apply_two_rooms(board, terrain_cfg, rng)
        "ruins":
            _apply_ruins(board, terrain_cfg, layout_cfg, rng)
        "choke":
            _apply_choke(board, terrain_cfg, rng)
        _:
            _apply_pillars(board, terrain_cfg, layout_cfg, rng)
    var remaining_blockers: int = _roll_range(layout_cfg.get("blockers", [0, 0]), rng)
    _place_terrain_group(board, terrain_cfg, DataLoader.load_config("map_generation").get("blocked_terrain", []), remaining_blockers, rng)

static func _apply_broken_lane(board: BoardData, terrain_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var vertical := rng.randi_range(0, 1) == 0
    var axis_len: int = board.rows
    var cross_len: int = board.cols
    if not vertical:
        axis_len = board.cols
        cross_len = board.rows
    var line: int = int(cross_len / 2.0)
    var gap_a: int = rng.randi_range(1, max(1, axis_len - 2))
    var gap_b: int = int(clamp(gap_a + rng.randi_range(2, 3), 1, axis_len - 2))
    var max_len: int = axis_len
    for i in range(max_len):
        if i == gap_a or i == gap_b:
            continue
        var pos: Vector2i = Vector2i(line, i) if vertical else Vector2i(i, line)
        _set_layout_blocker(board, terrain_cfg, pos, rng)

static func _apply_two_rooms(board: BoardData, terrain_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var mid_col := int(board.cols / 2.0)
    for row in range(1, board.rows - 1):
        if row in [2, board.rows - 3]:
            continue
        _set_layout_blocker(board, terrain_cfg, Vector2i(mid_col, row), rng)
    var mid_row := int(board.rows / 2.0)
    for col in range(2, board.cols - 2):
        if col == mid_col or rng.randi_range(0, 3) == 0:
            continue
        _set_layout_blocker(board, terrain_cfg, Vector2i(col, mid_row), rng)

static func _apply_pillars(board: BoardData, terrain_cfg: Dictionary, layout_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var count: int = max(2, int(_roll_range(layout_cfg.get("blockers", [4, 6]), rng) / 2.0))
    var positions := _candidate_positions(board)
    positions.shuffle()
    var placed := 0
    for pos in positions:
        if placed >= count:
            break
        if pos.x % 2 == 0 and pos.y % 2 == 0:
            _set_layout_blocker(board, terrain_cfg, pos, rng)
            placed += 1

static func _apply_ruins(board: BoardData, terrain_cfg: Dictionary, layout_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var count: int = max(4, _roll_range(layout_cfg.get("blockers", [7, 10]), rng))
    var center := Vector2i(int(board.cols / 2.0), int(board.rows / 2.0))
    for i in range(count):
        var pos := center + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
        _set_layout_blocker(board, terrain_cfg, pos, rng)

static func _apply_choke(board: BoardData, terrain_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var left: int = int(max(2, int(board.cols / 3.0)))
    var right: int = int(min(board.cols - 3, int(board.cols * 2.0 / 3.0)))
    for row in range(1, board.rows - 1):
        if row == int(board.rows / 2.0) or row == int(board.rows / 2.0) - 1:
            continue
        _set_layout_blocker(board, terrain_cfg, Vector2i(left, row), rng)
        _set_layout_blocker(board, terrain_cfg, Vector2i(right, row), rng)

static func _place_terrain_group(board: BoardData, terrain_cfg: Dictionary, terrain_ids: Array, count: int, rng: RandomNumberGenerator) -> void:
    if terrain_ids.is_empty() or count <= 0:
        return
    var positions := _candidate_positions(board)
    positions.shuffle()
    var placed := 0
    for pos in positions:
        if placed >= count:
            break
        var tile: Tile = board.get_tile(pos)
        if tile == null or bool(tile.terrain_data.get("blocks_movement", false)):
            continue
        var terrain_id := str(terrain_ids[rng.randi_range(0, terrain_ids.size() - 1)])
        _set_tile_terrain(board, terrain_cfg, pos, terrain_id)
        placed += 1

static func _set_layout_blocker(board: BoardData, terrain_cfg: Dictionary, pos: Vector2i, rng: RandomNumberGenerator) -> void:
    if not board.is_in_bounds(pos) or _is_spawn_safety_pos(board, pos):
        return
    if board.get_tile(pos) == null:
        return
    var blocked_ids: Array = DataLoader.load_config("map_generation").get("blocked_terrain", ["rock"])
    var terrain_id := str(blocked_ids[rng.randi_range(0, blocked_ids.size() - 1)])
    _set_tile_terrain(board, terrain_cfg, pos, terrain_id)

static func _set_tile_terrain(board: BoardData, terrain_cfg: Dictionary, pos: Vector2i, terrain_id: String) -> void:
    if not board.is_in_bounds(pos) or not terrain_cfg.has(terrain_id):
        return
    var tile := Tile.new()
    var data: Dictionary = terrain_cfg.get(terrain_id, {})
    tile.init_from_terrain(terrain_id, data)
    tile.revealed = not bool(data.get("fog", false))
    board.set_tile(pos, tile)

static func _clear_spawn_safety(board: BoardData, terrain_cfg: Dictionary) -> void:
    for pos in _spawn_safety_positions(board):
        _set_tile_terrain(board, terrain_cfg, pos, "normal")

static func _ensure_spawn_path(board: BoardData, terrain_cfg: Dictionary) -> void:
    var start := Vector2i(1, board.rows - 2)
    var goal := Vector2i(board.cols - 2, 1)
    if _has_walkable_path(board, start, goal):
        return
    var cursor := start
    while cursor.x != goal.x:
        cursor.x += 1 if goal.x > cursor.x else -1
        _set_tile_terrain(board, terrain_cfg, cursor, "normal")
    while cursor.y != goal.y:
        cursor.y += 1 if goal.y > cursor.y else -1
        _set_tile_terrain(board, terrain_cfg, cursor, "normal")

static func _has_walkable_path(board: BoardData, start: Vector2i, goal: Vector2i) -> bool:
    if not board.is_in_bounds(start) or not board.is_in_bounds(goal):
        return false
    var frontier: Array[Vector2i] = [start]
    var visited := {_key(start): true}
    var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        if current == goal:
            return true
        for direction in directions:
            var next_pos: Vector2i = current + direction
            if visited.has(_key(next_pos)) or not board.is_in_bounds(next_pos):
                continue
            var tile: Tile = board.get_tile(next_pos)
            if tile == null or MovementSystem.is_blocked(tile):
                continue
            visited[_key(next_pos)] = true
            frontier.append(next_pos)
    return false

static func _is_spawn_safety_pos(board: BoardData, pos: Vector2i) -> bool:
    return pos in _spawn_safety_positions(board)

static func _spawn_safety_positions(board: BoardData) -> Array[Vector2i]:
    var cfg: Dictionary = DataLoader.load_config("map_generation")
    var radius: int = int(cfg.get("spawn_clear_radius", 1))
    var anchors := [Vector2i(1, board.rows - 2), Vector2i(board.cols - 2, 1)]
    var result: Array[Vector2i] = []
    for anchor in anchors:
        for y in range(anchor.y - radius, anchor.y + radius + 1):
            for x in range(anchor.x - radius, anchor.x + radius + 1):
                var pos := Vector2i(x, y)
                if board.is_in_bounds(pos) and not pos in result:
                    result.append(pos)
    return result

static func _candidate_positions(board: BoardData) -> Array[Vector2i]:
    var positions: Array[Vector2i] = []
    for row in range(1, board.rows - 1):
        for col in range(1, board.cols - 1):
            var pos := Vector2i(col, row)
            if board.get_tile(pos) != null and not _is_spawn_safety_pos(board, pos):
                positions.append(pos)
    return positions

static func _pick_weighted_terrain(terrain_cfg: Dictionary, rng: RandomNumberGenerator, allow_blocked: bool) -> String:
    var terrain_ids: Array = []
    var weights: Array = []
    var total_weight := 0
    for terrain_id in terrain_cfg.keys():
        var data: Dictionary = terrain_cfg[terrain_id]
        if not allow_blocked and bool(data.get("blocks_movement", false)):
            continue
        var weight: int = int(data.get("base_weight", 0))
        if weight <= 0:
            continue
        terrain_ids.append(terrain_id)
        weights.append(weight)
        total_weight += weight
    return _pick_weighted(terrain_ids, weights, total_weight, rng)

static func _key(pos: Vector2i) -> String:
    return "%d,%d" % [pos.x, pos.y]

static func _roll_range(value: Variant, rng: RandomNumberGenerator) -> int:
    if typeof(value) != TYPE_ARRAY:
        return int(value)
    var values: Array = value
    if values.size() < 2:
        return 0
    var low: int = int(values[0])
    var high: int = int(values[1])
    if high < low:
        var swap := low
        low = high
        high = swap
    return rng.randi_range(low, high)
