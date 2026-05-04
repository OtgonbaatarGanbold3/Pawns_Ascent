extends Node


func _ready() -> void:
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var items: Dictionary = DataLoader.load_config("items")
    var unit := Unit.new()
    unit.init_from_piece("knight", pieces.get("knight", {}))
    unit.apply_items([items.get("shard_of_rank", {})])
    var priority = AISystem.calculate_priority(unit)
    print("AITest priority:", priority)
