extends Node

func _ready() -> void:
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var unit := Unit.new()
    unit.init_from_piece("pawn", pieces.get("pawn", {}))
    unit.kills = unit.evolve_kills
    var evolved := EvolutionSystem.check_and_evolve(unit)
    print("EvolutionTest evolved:", evolved, "piece:", unit.piece_id)
