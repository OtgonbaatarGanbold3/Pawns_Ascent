extends Node


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    var board = BoardGenerator.generate_board(rng)
    print("BoardTest size:", board.rows, "x", board.cols)
    if board.rows != 8 or board.cols != 9:
        push_error("BoardTest failed: floor 1 board should be 8x9")
    _assert_spawn_clear(board, Vector2i(1, board.rows - 2), "player")
    _assert_spawn_clear(board, Vector2i(board.cols - 2, 1), "enemy")
    if _count_blockers(board) <= 0:
        push_error("BoardTest failed: generated board should include layout blockers")

    var late_board = BoardGenerator.generate_board(rng, {"floor": 6})
    print("BoardTest late size:", late_board.rows, "x", late_board.cols)
    if late_board.rows <= board.rows or late_board.cols <= board.cols:
        push_error("BoardTest failed: later floor board should be larger")
    if _count_empty_cells(late_board) <= 0:
        push_error("BoardTest failed: later floor board should have a non-rectangular footprint")

func _assert_spawn_clear(board: BoardData, anchor: Vector2i, label: String) -> void:
    for y in range(anchor.y - 1, anchor.y + 2):
        for x in range(anchor.x - 1, anchor.x + 2):
            var pos := Vector2i(x, y)
            if not board.is_in_bounds(pos):
                continue
            var tile: Tile = board.get_tile(pos)
            if tile == null or MovementSystem.is_blocked(tile):
                push_error("BoardTest failed: %s spawn safety tile blocked at %s" % [label, pos])

func _count_blockers(board: BoardData) -> int:
    var count := 0
    for row in range(board.rows):
        for col in range(board.cols):
            var tile: Tile = board.get_tile(Vector2i(col, row))
            if tile != null and MovementSystem.is_blocked(tile):
                count += 1
    return count

func _count_empty_cells(board: BoardData) -> int:
    var count := 0
    for row in range(board.rows):
        for col in range(board.cols):
            if board.get_tile(Vector2i(col, row)) == null:
                count += 1
    return count
