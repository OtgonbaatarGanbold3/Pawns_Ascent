extends Node


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2
    var board = BoardGenerator.generate_board(rng)
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var unit := Unit.new()
    unit.init_from_piece("pawn", pieces.get("pawn", {}))
    unit.is_player = true
    unit.position = Vector2i(4, 4)
    var diagonal_step := Tile.new()
    diagonal_step.init_from_terrain("normal", {})
    board.set_tile(Vector2i(5, 5), diagonal_step)
    var diagonal_target := Tile.new()
    diagonal_target.init_from_terrain("normal", {})
    board.set_tile(Vector2i(6, 6), diagonal_target)
    board.set_unit(unit.position, unit)
    var moves = MovementSystem.get_valid_moves(unit, board)
    print("MovementTest moves:", moves.size())
    if not Vector2i(6, 6) in moves:
        push_error("MovementTest failed: omni movement did not include diagonal speed-range move")

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
        push_error("MovementTest failed: unit landed on blocked terrain")

    var enemy := Unit.new()
    enemy.init_from_piece("pawn", pieces.get("pawn", {}))
    enemy.position = Vector2i(6, 4)
    var attack_path_tile := Tile.new()
    attack_path_tile.init_from_terrain("normal", {})
    board.set_tile(Vector2i(5, 4), attack_path_tile)
    var attack_tile := Tile.new()
    attack_tile.init_from_terrain("normal", {})
    board.set_tile(enemy.position, attack_tile)
    board.set_unit(enemy.position, enemy)
    var attacks := MovementSystem.get_attack_positions(unit, board)
    if not enemy.position in attacks:
        push_error("MovementTest failed: omni attack range did not include a target two tiles away")

    var spawn_positions := BoardGenerator.get_spawn_positions(board, "top_right", 8, rng)
    if Vector2i(4, 3) in spawn_positions:
        push_error("MovementTest failed: blocked terrain was offered as spawn")
