extends Node


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var board = BoardGenerator.generate_board(rng)
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var attacker := Unit.new()
    var defender := Unit.new()
    attacker.init_from_piece("pawn", pieces.get("pawn", {}))
    attacker.is_player = true
    defender.init_from_piece("pawn", pieces.get("pawn", {}))
    attacker.position = Vector2i(3, 3)
    defender.position = Vector2i(5, 3)
    var path_tile := Tile.new()
    path_tile.init_from_terrain("normal", {})
    board.set_tile(Vector2i(4, 3), path_tile)
    var target_tile := Tile.new()
    target_tile.init_from_terrain("normal", {})
    board.set_tile(defender.position, target_tile)
    board.set_unit(attacker.position, attacker)
    board.set_unit(defender.position, defender)
    if not MovementSystem.can_attack(attacker, defender, board):
        push_error("CombatTest failed: attacker should threaten two tiles in an omni direction")
    var result = CombatSystem.apply_attack(attacker, defender, board, rng)
    print("CombatTest damage:", result.get("final", 0))
