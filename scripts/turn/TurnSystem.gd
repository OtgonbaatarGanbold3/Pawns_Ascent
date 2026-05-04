extends Node
class_name TurnSystem


enum Phase { PLAYER, ALLY, ENEMY, TICK }

var phase: Phase = Phase.PLAYER

func start_player_phase(player: Unit) -> void:
    phase = Phase.PLAYER
    player.ap = player.max_ap
    _event_bus().emit_event(_event_bus().EVENT_TURN_START, {"unit": player})

func start_ally_phase() -> void:
    phase = Phase.ALLY

func start_enemy_phase(enemies: Array) -> Array:
    phase = Phase.ENEMY
    var sorted := enemies.duplicate()
    sorted.sort_custom(func(a, b): return a.spd > b.spd)
    for enemy in sorted:
        enemy.ap = enemy.max_ap
        _event_bus().emit_event(_event_bus().EVENT_TURN_START, {"unit": enemy})
    return sorted

func start_tick_phase(units: Array, board: BoardData) -> void:
    phase = Phase.TICK
    for unit in units:
        var tile = board.get_tile(unit.position)
        if tile == null:
            continue
        var effect: Dictionary = tile.terrain_data.get("standing_effect", {})
        var effect_type: String = effect.get("type", "")
        if effect_type == "burn":
            StatusSystem.apply_status(unit, "burn")
    _event_bus().emit_event(_event_bus().EVENT_TICK, {})
    StatusSystem.tick_all(units)

func spend_ap(unit: Unit, amount: int) -> bool:
    if amount <= 0:
        return false
    if unit.ap < amount:
        return false
    unit.ap -= amount
    return true

func _event_bus() -> Node:
    return Engine.get_main_loop().root.get_node("EventBus")
