extends Node


func _ready() -> void:
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var unit := Unit.new()
    unit.init_from_piece("pawn", pieces.get("pawn", {}))
    var turn = TurnSystem.new()
    turn.start_player_phase(unit)
    print("TurnTest ap:", unit.ap)
