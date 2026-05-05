extends Node


func _ready() -> void:
    var pieces: Dictionary = DataLoader.load_config("pieces")
    var items: Dictionary = DataLoader.load_config("items")
    var attacker := Unit.new()
    var defender := Unit.new()
    attacker.init_from_piece("pawn", pieces.get("pawn", {}))
    defender.init_from_piece("pawn", pieces.get("pawn", {}))

    ItemSystem.apply_items(attacker, [items.get("shard_of_rank", {}), items.get("bleeders_mark", {}), items.get("mending_word", {})])
    print("ItemTest synergies:", attacker.active_synergies)

    var event_bus: Node = Engine.get_main_loop().root.get_node("EventBus")
    event_bus.emit_event(event_bus.EVENT_ATTACK_HIT, {
        "attacker": attacker,
        "defender": defender,
        "result": {"final": 1}
    })
    print("ItemTest bleed:", defender.status_effects.has("bleed"))

    event_bus.emit_event(event_bus.EVENT_UNIT_KILLED, {"killer": attacker, "victim": defender})
    print("ItemTest heal hp:", attacker.hp)
