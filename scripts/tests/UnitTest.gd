extends Node

func _ready() -> void:
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var items: Dictionary = DataLoader.load_config("items")
    var unit := Unit.new()
    unit.init_from_piece("pawn", pieces.get("pawn", {}))
    unit.apply_items([items.get("shard_of_rank", {})])
    print("UnitTest atk:", unit.atk, "max_hp:", unit.max_hp)
