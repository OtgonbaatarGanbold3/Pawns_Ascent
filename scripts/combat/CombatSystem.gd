extends Node
class_name CombatSystem


static func resolve_attack(attacker: Unit, defender: Unit, board: BoardData, rng: RandomNumberGenerator) -> Dictionary:
    var rules: Dictionary = DataLoader.load_config("combat_rules")
    var rand_min: int = int(rules.get("damage_random_min", -1))
    var rand_max: int = int(rules.get("damage_random_max", 2))
    return _resolve_attack_with_roll(attacker, defender, board, rng.randi_range(rand_min, rand_max))

static func preview_attack(attacker: Unit, defender: Unit, board: BoardData) -> Dictionary:
    var rules: Dictionary = DataLoader.load_config("combat_rules")
    var rand_min: int = int(rules.get("damage_random_min", -1))
    var rand_max: int = int(rules.get("damage_random_max", 2))
    var low: Dictionary = _resolve_attack_with_roll(attacker, defender, board, rand_min)
    var high: Dictionary = _resolve_attack_with_roll(attacker, defender, board, rand_max)
    return {
        "min": int(low.get("final", 0)),
        "max": int(high.get("final", 0)),
        "ignored_def": int(high.get("ignored_def", 0)),
        "terrain_bonus": int(high.get("terrain_bonus", 0)),
        "terrain_reduce": int(high.get("terrain_reduce", 0))
    }

static func _resolve_attack_with_roll(attacker: Unit, defender: Unit, board: BoardData, roll: int) -> Dictionary:
    var rules: Dictionary = DataLoader.load_config("combat_rules")
    var min_damage: int = int(rules.get("min_damage", 1))

    var ignored_def: int = int(attacker.synergy_effects.get("ignore_def", 0))
    var effective_def: int = max(0, defender.def - ignored_def)
    var raw_damage: int = attacker.atk - effective_def + roll

    var terrain_bonus: int = 0
    var terrain_reduce: int = 0

    var attacker_tile: Tile = board.get_tile(attacker.position)
    if attacker_tile != null:
        var attacker_mod: Dictionary = attacker_tile.terrain_data.get("combat_mod", {})
        terrain_bonus = int(attacker_mod.get("atk_bonus", 0))

    var defender_tile: Tile = board.get_tile(defender.position)
    if defender_tile != null:
        var defender_mod: Dictionary = defender_tile.terrain_data.get("combat_mod", {})
        terrain_reduce = int(defender_mod.get("damage_reduce", 0))

    var final_damage: int = max(min_damage, raw_damage + terrain_bonus - terrain_reduce)
    return {
        "raw": raw_damage,
        "roll": roll,
        "ignored_def": ignored_def,
        "terrain_bonus": terrain_bonus,
        "terrain_reduce": terrain_reduce,
        "final": final_damage
    }

static func apply_attack(attacker: Unit, defender: Unit, board: BoardData, rng: RandomNumberGenerator) -> Dictionary:
    var result: Dictionary = resolve_attack(attacker, defender, board, rng)
    _event_bus().emit_event(_event_bus().EVENT_ATTACK_HIT, {
        "attacker": attacker,
        "defender": defender,
        "result": result
    })

    var killed: bool = defender.apply_damage(int(result.get("final", 0)))
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
