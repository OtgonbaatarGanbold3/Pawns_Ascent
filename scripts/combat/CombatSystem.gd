extends Node
class_name CombatSystem


static func resolve_attack(attacker: Unit, defender: Unit, board: BoardData, rng: RandomNumberGenerator) -> Dictionary:
    var rules: Dictionary = DataLoader.load_config("combat_rules")
    var rand_min: int = int(rules.get("damage_random_min", -1))
    var rand_max: int = int(rules.get("damage_random_max", 2))
    var min_damage: int = int(rules.get("min_damage", 1))

    var roll: int = rng.randi_range(rand_min, rand_max)
    var raw_damage: int = attacker.atk - defender.def + roll

    var terrain_bonus := 0
    var terrain_reduce := 0

    var attacker_tile = board.get_tile(attacker.position)
    if attacker_tile != null:
        var mod: Dictionary = attacker_tile.terrain_data.get("combat_mod", {})
        terrain_bonus = int(mod.get("atk_bonus", 0))

    var defender_tile = board.get_tile(defender.position)
    if defender_tile != null:
        var mod: Dictionary = defender_tile.terrain_data.get("combat_mod", {})
        terrain_reduce = int(mod.get("damage_reduce", 0))

    var final_damage: int = max(min_damage, raw_damage + terrain_bonus - terrain_reduce)
    return {
        "raw": raw_damage,
        "roll": roll,
        "terrain_bonus": terrain_bonus,
        "terrain_reduce": terrain_reduce,
        "final": final_damage
    }

static func apply_attack(attacker: Unit, defender: Unit, board: BoardData, rng: RandomNumberGenerator) -> Dictionary:
    var result := resolve_attack(attacker, defender, board, rng)
    _event_bus().emit_event(_event_bus().EVENT_ATTACK_HIT, {
        "attacker": attacker,
        "defender": defender,
        "result": result
    })

    var killed := defender.apply_damage(int(result.get("final", 0)))
    _event_bus().emit_event(_event_bus().EVENT_UNIT_DAMAGED, {
        "attacker": attacker,
        "defender": defender,
        "result": result
    })

    if killed:
        _event_bus().emit_event(_event_bus().EVENT_UNIT_KILLED, {
            "killer": attacker,
            "victim": defender
        })

    result["killed"] = killed
    return result

static func _event_bus() -> Node:
    return Engine.get_main_loop().root.get_node("EventBus")
