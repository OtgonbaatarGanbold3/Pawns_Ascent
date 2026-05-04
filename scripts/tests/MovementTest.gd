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
