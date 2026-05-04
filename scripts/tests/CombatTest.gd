extends Node


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var board = BoardGenerator.generate_board(rng)
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var attacker := Unit.new()
    var defender := Unit.new()
    attacker.init_from_piece("pawn", pieces.get("pawn", {}))
    defender.init_from_piece("pawn", pieces.get("pawn", {}))
    attacker.position = Vector2i(3, 3)
    defender.position = Vector2i(3, 4)
    board.set_unit(attacker.position, attacker)
    board.set_unit(defender.position, defender)
    var result = CombatSystem.apply_attack(attacker, defender, board, rng)
    print("CombatTest damage:", result.get("final", 0))
