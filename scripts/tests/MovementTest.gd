extends Node


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2
    var board = BoardGenerator.generate_board(rng)
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var unit := Unit.new()
    unit.init_from_piece("pawn", pieces.get("pawn", {}))
    unit.position = Vector2i(4, 4)
    board.set_unit(unit.position, unit)
    var moves = MovementSystem.get_valid_moves(unit, board)
    print("MovementTest moves:", moves.size())

    var blocker := Tile.new()
    blocker.init_from_terrain("rock", {"blocks_movement": true})
    board.set_tile(Vector2i(4, 3), blocker)
    moves = MovementSystem.get_valid_moves(unit, board)
    if Vector2i(4, 3) in moves or Vector2i(4, 2) in moves:
        push_error("MovementTest failed: ray movement crossed blocked terrain")

    var knight := Unit.new()
    knight.init_from_piece("knight", pieces.get("knight", {}))
    knight.position = Vector2i(2, 2)
    board.set_unit(knight.position, knight)
    var blocked_landing := Tile.new()
    blocked_landing.init_from_terrain("house", {"blocks_movement": true})
    board.set_tile(Vector2i(4, 3), blocked_landing)
    moves = MovementSystem.get_valid_moves(knight, board)
    if Vector2i(4, 3) in moves:
        push_error("MovementTest failed: knight landed on blocked terrain")

    var spawn_positions := BoardGenerator.get_spawn_positions(board, "top_right", 8, rng)
    if Vector2i(4, 3) in spawn_positions:
        push_error("MovementTest failed: blocked terrain was offered as spawn")
